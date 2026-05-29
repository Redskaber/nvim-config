-- lua/core/compiler/cache/policy.lua
-- Layer 1 compiler: tier invalidation policy + serializability check.
--
-- REFACTOR (TODO-2.3): extracted from cache.lua.
-- Tier order: ast < ir < spec  (lower invalidates higher).

local store = require("core.compiler.cache.store")
local key_mod = require("core.compiler.cache.key")
local version = require("core.compiler.cache.version")

local M = {}
local TIER_ORDER = { "ast", "ir", "spec" }

-- ── Serializability ───────────────────────────────────────────────────────────
-- REFACTOR (TODO-2.4): metatable-based cacheable marker replaces _no_cache field.

local UNCACHEABLE_MT = { __ltos_cacheable = false }

--- Mark a table as non-cacheable via metatable (non-invasive).
---@param t table
---@return table  same table, now marked
function M.mark_uncacheable(t)
  return setmetatable(t, UNCACHEABLE_MT)
end

---@param v any
---@return boolean
local function is_cacheable(v)
  local t = type(v)
  if t == "function" then
    return false
  end
  if t == "table" then
    local mt = getmetatable(v)
    if mt and mt.__ltos_cacheable == false then
      return false
    end
    -- Legacy support: _no_cache field
    if v._no_cache then
      return false
    end
    for _, child in pairs(v) do
      if not is_cacheable(child) then
        return false
      end
    end
  end
  return true
end

M.is_cacheable = is_cacheable

-- ── Tier API ─────────────────────────────────────────────────────────────────

---@param tier "ast"|"ir"|"spec"
---@param key  string
---@return table|nil
function M.load(tier, key)
  if key == "" then
    return nil
  end
  local path = store.TIER_FILES[tier]
  if not path then
    return nil
  end

  local data, err = store.read(path)
  if not data then
    if vim.g.ltos_debug or vim.g.ltos_debug_cache then
      vim.notify(("[cache:%s] miss (%s)"):format(tier, err or "read error"), vim.log.levels.DEBUG)
    end
    -- Miss statistics
    M._stats = M._stats or {}
    M._stats[tier] = (M._stats[tier] or { hits = 0, misses = 0 })
    M._stats[tier].misses = M._stats[tier].misses + 1
    return nil
  end

  if data.version ~= version.CACHE_VERSION or data.key ~= key then
    if vim.g.ltos_debug or vim.g.ltos_debug_cache then
      vim.notify(("[cache:%s] miss (version/key mismatch)"):format(tier), vim.log.levels.DEBUG)
    end
    -- Miss statistics
    M._stats = M._stats or {}
    M._stats[tier] = (M._stats[tier] or { hits = 0, misses = 0 })
    M._stats[tier].misses = M._stats[tier].misses + 1
    return nil
  end

  -- Hit statistics
  M._stats = M._stats or {}
  M._stats[tier] = (M._stats[tier] or { hits = 0, misses = 0 })
  M._stats[tier].hits = M._stats[tier].hits + 1

  if vim.g.ltos_debug or vim.g.ltos_debug_cache then
    vim.notify(("[cache:%s] HIT"):format(tier), vim.log.levels.DEBUG)
  end
  return data.payload
end

---@param tier    "ast"|"ir"|"spec"
---@param key     string
---@param payload table
---@return boolean
function M.save(tier, key, payload)
  if key == "" then
    return false
  end
  if not is_cacheable(payload) then
    vim.notify(("[cache:%s] skipped — non-serialisable payload"):format(tier), vim.log.levels.WARN)
    return false
  end

  local ok, err = store.write(store.TIER_FILES[tier], {
    version = version.CACHE_VERSION,
    key = key,
    payload = payload,
  })

  if not ok then
    vim.notify(("[cache:%s] write failed: %s"):format(tier, err or "?"), vim.log.levels.WARN)
  elseif vim.g.ltos_debug or vim.g.ltos_debug_cache then
    vim.notify(("[cache:%s] saved key=%s"):format(tier, key), vim.log.levels.DEBUG)
  end
  return ok
end

--- Invalidate `tier` and all downstream (higher) tiers.
---@param tier "ast"|"ir"|"spec"
function M.invalidate(tier)
  local found = false
  for _, t in ipairs(TIER_ORDER) do
    if t == tier then
      found = true
    end
    if found then
      store.remove(store.TIER_FILES[t])
    end
  end
end

function M.invalidate_all()
  for _, t in ipairs(TIER_ORDER) do
    store.remove(store.TIER_FILES[t])
  end
end

--- Hit ratio stats for :LtosInfo
---@return table
function M.stats()
  return M._stats or {}
end

-- Re-export key computation for convenience
M.compute_key = key_mod.compute

return M
