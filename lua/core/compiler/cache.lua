-- lua/core/compiler/cache.lua
-- Layer 1 compiler: three-tier pipeline cache.
--
-- Tiers:
--   "ast"   – post-collect validated capability snapshot
--   "ir"    – post-optimize intermediate representation (LIR)
--   "spec"  – final LazySpec[] list (SPEC tier)
--
-- Cache key = mtime_hash(sorted module-file-contents) + ":" + profile
-- Each tier lives in a separate JSON file under stdpath("cache")/ltos/.
--
-- Function values (FormatterNode.fn) set _no_cache = true; those payloads
-- are never persisted. A module-file change invalidates only the affected tier
-- and all downstream tiers (partial invalidation).

local M = {}

local CACHE_DIR = vim.fn.stdpath("cache") .. "/ltos"
local CACHE_VERSION = 3

local TIER_FILES = {
  ast = CACHE_DIR .. "/ast_cache.json",
  ir = CACHE_DIR .. "/ir_cache.json",
  spec = CACHE_DIR .. "/spec_cache.json",
}

-- Tier invalidation order: changing a lower tier invalidates all higher ones.
local TIER_ORDER = { "ast", "ir", "spec" }

-- ── I/O helpers ───────────────────────────────────────────────────────────────

local function ensure_dir()
  if vim.fn.isdirectory(CACHE_DIR) == 0 then
    vim.fn.mkdir(CACHE_DIR, "p")
  end
end

local function read_json(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local raw = f:read("*a")
  f:close()
  if not raw or raw == "" then
    return nil
  end
  local ok, data = pcall(vim.json.decode, raw)
  return ok and data or nil
end

local function write_json(path, data)
  ensure_dir()
  local ok, encoded = pcall(vim.json.encode, data)
  if not ok then
    vim.notify("[cache] JSON encode failed: " .. tostring(encoded), vim.log.levels.WARN)
    return false
  end
  local f = io.open(path, "w")
  if not f then
    vim.notify("[cache] cannot open for write: " .. path, vim.log.levels.WARN)
    return false
  end
  f:write(encoded)
  f:close()
  return true
end

-- ── Cache key ─────────────────────────────────────────────────────────────────

--- Compute a composite cache key for a set of lang modules.
---@param lang_modules string[]
---@param profile      string
---@return string  "<mtime-hash>:<profile>" or "" on failure
function M.key(lang_modules, profile)
  profile = profile or "full"
  local parts = {}
  for _, mod in ipairs(lang_modules) do
    local path = vim.api.nvim_get_runtime_file(mod:gsub("%.", "/") .. ".lua", false)[1]
    if path then
      local stat = vim.uv and vim.uv.fs_stat(path) or vim.loop.fs_stat(path)
      if stat then
        parts[#parts + 1] = path .. "=" .. stat.mtime.sec
      end
    end
  end
  if #parts == 0 then
    return ""
  end
  table.sort(parts)
  local concat = table.concat(parts, "|")
  local hash = 0
  for i = 1, #concat do
    hash = (hash * 31 + string.byte(concat, i)) % (2 ^ 32)
  end
  return string.format("%08x:%s", hash, profile)
end

-- ── Serializability check ─────────────────────────────────────────────────────

local function is_cacheable(v)
  local t = type(v)
  if t == "function" then
    return false
  end
  if t == "table" then
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

-- ── Tier API ─────────────────────────────────────────────────────────────────

--- Load a tier from disk. Returns nil on miss, version mismatch, or key mismatch.
---@param tier "ast"|"ir"|"spec"
---@param key  string
---@return table|nil
function M.load(tier, key)
  if key == "" then
    return nil
  end
  local path = TIER_FILES[tier]
  if not path then
    return nil
  end
  local data = read_json(path)
  if not data then
    return nil
  end
  if data.version ~= CACHE_VERSION or data.key ~= key then
    if vim.g.ltos_debug then
      vim.notify(("[cache:%s] miss (key/version mismatch)"):format(tier), vim.log.levels.DEBUG)
    end
    return nil
  end
  if vim.g.ltos_debug then
    vim.notify(("[cache:%s] hit"):format(tier), vim.log.levels.DEBUG)
  end
  return data.payload
end

--- Persist a tier to disk. Skips non-serialisable payloads.
---@param tier    "ast"|"ir"|"spec"
---@param key     string
---@param payload table
---@return boolean  true if written
function M.save(tier, key, payload)
  if key == "" then
    return false
  end
  if not is_cacheable(payload) then
    vim.notify(("[cache:%s] skipped — payload contains non-serialisable value"):format(tier), vim.log.levels.WARN)
    return false
  end
  return write_json(TIER_FILES[tier], {
    version = CACHE_VERSION,
    key = key,
    payload = payload,
  })
end

--- Invalidate a tier and all downstream tiers.
---@param tier "ast"|"ir"|"spec"
function M.invalidate(tier)
  local found = false
  for _, t in ipairs(TIER_ORDER) do
    if t == tier then
      found = true
    end
    if found then
      os.remove(TIER_FILES[t])
    end
  end
end

--- Invalidate all tiers.
function M.invalidate_all()
  for _, t in ipairs(TIER_ORDER) do
    os.remove(TIER_FILES[t])
  end
end

-- ── Spec-tier shorthands (backward-compat) ────────────────────────────────────

---@param key string
---@return table[]|nil
function M.load_specs(key)
  return M.load("spec", key)
end

---@param key   string
---@param specs table[]
function M.save_specs(key, specs)
  M.save("spec", key, specs)
end

return M
