-- lua/core/compiler/cache/policy.lua
-- Layer 1 compiler: tier invalidation policy + serializability check.
-- Tier order: ast < spec. Notifications via ports (no direct vim API).

local key_mod = require("core.compiler.cache.key")
local ports = require("core.compiler.ports")
local store = require("core.compiler.cache.store")
local version = require("core.compiler.cache.version")

local M = {}
local TIER_ORDER = { "ast", "spec" }

local UNCACHEABLE_MT = { __ltos_cacheable = false }

function M.mark_uncacheable(t) return setmetatable(t, UNCACHEABLE_MT) end

-- Old code recursed without tracking visited tables — infinite loop on
-- self-referential tables (e.g., metatable with __index = self, or cyclic
-- data structures). New version passes a visited set as 2nd arg (internal).
-- Public API M.is_cacheable(v) wraps with a fresh visited set per call.
local function is_cacheable_inner(v, visited)
  local t = type(v)
  if t == "function" then
    return false
  end
  if t == "table" then
    -- Cycle detection: if we've seen this table before, treat as cacheable
    -- (we're in a cycle; if any member were uncacheable we'd have returned false already)
    if visited[v] then
      return true
    end
    visited[v] = true

    local mt = getmetatable(v)
    if mt and mt.__ltos_cacheable == false then
      return false
    end
    if v._no_cache then
      return false
    end
    for _, child in pairs(v) do
      if not is_cacheable_inner(child, visited) then
        return false
      end
    end
  end
  return true
end

---@param v any
---@return boolean
local function is_cacheable(v) return is_cacheable_inner(v, {}) end

M.is_cacheable = is_cacheable

local LEVEL_WARN = 2
local LEVEL_DEBUG = 0

local function debug_log(msg)
  if ports.debug_cache() then
    ports.notify(LEVEL_DEBUG, msg)
  end
end

---@param tier "ast"|"spec"
---@param key  string
---@return table|nil
function M.load(tier, key)
  if key == "" then
    return nil
  end
  local files = store.tier_files()
  local path = files[tier]
  if not path then
    return nil
  end

  local data, err = store.read(path)
  if not data then
    debug_log(("[cache:%s] miss (%s)"):format(tier, err or "read error"))
    M._stats = M._stats or {}
    M._stats[tier] = (M._stats[tier] or { hits = 0, misses = 0 })
    M._stats[tier].misses = M._stats[tier].misses + 1
    return nil
  end

  -- P6-C4: validate cache version
  if data.version ~= version.CACHE_VERSION then
    debug_log(
      ("[cache:%s] miss (cache version mismatch: got %s, want %s)"):format(
        tier,
        tostring(data.version),
        tostring(version.CACHE_VERSION)
      )
    )
    M._stats = M._stats or {}
    M._stats[tier] = (M._stats[tier] or { hits = 0, misses = 0 })
    M._stats[tier].misses = M._stats[tier].misses + 1
    return nil
  end

  if data.key ~= key then
    debug_log(("[cache:%s] miss (key mismatch)"):format(tier))
    M._stats = M._stats or {}
    M._stats[tier] = (M._stats[tier] or { hits = 0, misses = 0 })
    M._stats[tier].misses = M._stats[tier].misses + 1
    return nil
  end

  -- P6-C4: check IR schema version consistency (if embedded in payload)
  local payload = data.payload
  if payload and payload.meta and payload.meta.ir_version then
    if payload.meta.ir_version ~= version.SCHEMA_VERSION then
      debug_log(
        ("[cache:%s] miss (IR schema version mismatch: got %s, want %s)"):format(
          tier,
          tostring(payload.meta.ir_version),
          tostring(version.SCHEMA_VERSION)
        )
      )
      M._stats = M._stats or {}
      M._stats[tier] = (M._stats[tier] or { hits = 0, misses = 0 })
      M._stats[tier].misses = M._stats[tier].misses + 1
      return nil
    end
  end

  M._stats = M._stats or {}
  M._stats[tier] = (M._stats[tier] or { hits = 0, misses = 0 })
  M._stats[tier].hits = M._stats[tier].hits + 1

  debug_log(("[cache:%s] HIT"):format(tier))
  return data.payload
end

---@param tier    "ast"|"spec"
---@param key     string
---@param payload table
---@return boolean
function M.save(tier, key, payload)
  if key == "" then
    return false
  end
  if not is_cacheable(payload) then
    ports.notify(LEVEL_WARN, ("[cache:%s] skipped — non-serialisable payload"):format(tier))
    return false
  end

  local files = store.tier_files()
  local ok, err = store.write(files[tier], {
    version = version.CACHE_VERSION,
    key = key,
    payload = payload,
  })

  if not ok then
    ports.notify(LEVEL_WARN, ("[cache:%s] write failed: %s"):format(tier, err or "?"))
  else
    debug_log(("[cache:%s] saved key=%s"):format(tier, key))
  end
  return ok
end

---@param tier "ast"|"spec"
function M.invalidate(tier)
  local files = store.tier_files()
  local found = false
  for _, t in ipairs(TIER_ORDER) do
    if t == tier then
      found = true
    end
    if found and files[t] then
      store.remove(files[t])
    end
  end
end

function M.invalidate_all()
  local files = store.tier_files()
  for _, t in ipairs(TIER_ORDER) do
    if files[t] then
      store.remove(files[t])
    end
  end
end

function M.stats() return M._stats or {} end

M.compute_key = key_mod.compute

return M