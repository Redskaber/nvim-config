-- ~/.config/nvim/lua/core/cache.lua
-- Three-tier pipeline cache: AST / IR / Spec (P1-1).
--
-- Tiers
--   "ast"   – post-collect validated capability snapshot
--   "ir"    – post-optimize intermediate representation
--   "spec"  – final LazySpec[] list (legacy tier, still used for full skip)
--
-- Cache key = sha256( concat(module_file_contents) ) + ":" + profile
-- Each tier is stored in a separate JSON file under stdpath("cache")/ltos/.
-- Function values (FormatterNode.fn) set _no_cache = true; those specs are
-- never persisted.  Partial rebuild: modifying one lang module only invalidates
-- tiers whose key changes.

local M = {}

local CACHE_DIR = vim.fn.stdpath("cache") .. "/ltos"
local CACHE_VERSION = 2 -- bump when serialisation format changes

local TIER_FILES = {
  ast = CACHE_DIR .. "/ast_cache.json",
  ir = CACHE_DIR .. "/ir_cache.json",
  spec = CACHE_DIR .. "/spec_cache.json",
}

-- ── Key ──────────────────────────────────────────────────────────────────────

--- Compute a composite cache key for a set of lang modules.
---@param lang_modules string[]
---@param profile      string
---@return string  "<sha256>:<profile>", or "" on failure
function M.key(lang_modules, profile)
  local parts = {}
  for _, mod in ipairs(lang_modules) do
    local path = package.searchpath(mod, package.path)
    if path then
      local ok, data = pcall(vim.fn.readfile, path)
      if ok and data then
        parts[#parts + 1] = table.concat(data, "\n")
      end
    end
  end
  if #parts == 0 then
    return ""
  end
  return vim.fn.sha256(table.concat(parts, "\0")) .. ":" .. (profile or "full")
end

-- ── Internal helpers ─────────────────────────────────────────────────────────

local function read_json(path)
  local ok, raw = pcall(vim.fn.readfile, path)
  if not ok or not raw then
    return nil
  end
  local dec_ok, data = pcall(vim.fn.json_decode, table.concat(raw, "\n"))
  if not dec_ok or type(data) ~= "table" then
    return nil
  end
  return data
end

local function write_json(path, payload)
  local enc_ok, json_str = pcall(vim.fn.json_encode, payload)
  if not enc_ok then
    if vim.g.ltos_debug then
      vim.notify("[cache] encode failed: " .. tostring(json_str), vim.log.levels.DEBUG)
    end
    return false
  end
  local dir = vim.fn.fnamemodify(path, ":h")
  pcall(vim.fn.mkdir, dir, "p")
  local w_ok = pcall(vim.fn.writefile, { json_str }, path)
  return w_ok
end

local function has_function_values(t)
  if type(t) ~= "table" then
    return false
  end
  for _, v in pairs(t) do
    if type(v) == "function" then
      return true
    end
    if type(v) == "table" and has_function_values(v) then
      return true
    end
  end
  return false
end

local function is_cacheable(item)
  if type(item) ~= "table" then
    return true
  end
  if item._no_cache then
    return false
  end
  return not has_function_values(item)
end

-- ── Load / Save ──────────────────────────────────────────────────────────────

--- Load a tier from disk.
---@param tier  "ast"|"ir"|"spec"
---@param key   string
---@return table|nil
function M.load(tier, key)
  if key == "" then
    return nil
  end
  local data = read_json(TIER_FILES[tier] or "")
  if not data then
    return nil
  end
  if data.version ~= CACHE_VERSION or data.key ~= key then
    if vim.g.ltos_debug then
      vim.notify(("[cache.load] %s: miss (key or version mismatch)"):format(tier), vim.log.levels.DEBUG)
    end
    return nil
  end
  if vim.g.ltos_debug then
    vim.notify(("[cache.load] %s: hit"):format(tier), vim.log.levels.DEBUG)
  end
  return data.payload
end

--- Persist a tier to disk.
---@param tier    "ast"|"ir"|"spec"
---@param key     string
---@param payload table
function M.save(tier, key, payload)
  if key == "" then
    return
  end
  -- Safety: reject non-serialisable payloads
  if type(payload) == "table" then
    for _, item in ipairs(payload) do
      if not is_cacheable(item) then
        vim.notify(
          ("[cache.save] %s: skipped — payload contains non-serialisable value"):format(tier),
          vim.log.levels.WARN
        )
        return
      end
    end
  end
  write_json(TIER_FILES[tier], {
    version = CACHE_VERSION,
    key = key,
    payload = payload,
  })
end

-- ── Convenience: spec-tier (backward-compatible entry point) ─────────────────

--- Load cached specs if key matches (spec tier shorthand).
---@param key string
---@return table[]|nil
function M.load_specs(key)
  return M.load("spec", key)
end

--- Save specs to the spec tier.
---@param key   string
---@param specs table[]
function M.save_specs(key, specs)
  M.save("spec", key, specs)
end

return M
