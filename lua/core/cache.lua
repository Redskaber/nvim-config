-- ~/.config/nvim/lua/core/cache.lua
-- Pipeline incremental cache: skip unchanged lang module builds.
-- All file IO is wrapped in pcall; failures silently return nil.

local M = {}

local CACHE_PATH = vim.fn.stdpath("cache") .. "/ltos/pipeline_cache.json"
local CACHE_VERSION = 1

-- ── Key ──────────────────────────────────────────────────────────────────────

--- Compute a cache key from the contents of all lang module files.
--- Resolves each module name (e.g. "modules.lang.python") to a file path via
--- `package.searchpath`, reads the contents, concatenates them, and hashes
--- with `vim.fn.sha256`.
---@param lang_modules string[]
---@return string  hex sha256 digest, or "" on failure
function M.key(lang_modules)
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
  return vim.fn.sha256(table.concat(parts, "\0"))
end

-- ── Load ─────────────────────────────────────────────────────────────────────

--- Load cached specs if the key and profile match.
---@param key     string
---@param profile string
---@return table[]|nil  specs list, or nil on miss / mismatch / error
function M.load(key, profile)
  if key == "" then
    return nil
  end

  local ok, raw = pcall(vim.fn.readfile, CACHE_PATH)
  if not ok or not raw then
    return nil
  end

  local json_str = table.concat(raw, "\n")
  local decode_ok, data = pcall(vim.fn.json_decode, json_str)
  if not decode_ok or type(data) ~= "table" then
    if vim.g.ltos_debug then
      vim.notify("[cache.load] decode failed: " .. tostring(data), vim.log.levels.DEBUG)
    end
    return nil
  end

  if data.version ~= CACHE_VERSION or data.cache_key ~= key or data.profile ~= profile then
    if vim.g.ltos_debug then
      vim.notify("[cache.load] cache miss (key or profile mismatch)", vim.log.levels.DEBUG)
    end
    return nil
  end

  if type(data.specs) ~= "table" then
    return nil
  end

  if vim.g.ltos_debug then
    vim.notify("[cache.load] cache hit", vim.log.levels.DEBUG)
  end
  return data.specs
end

-- ── Save ─────────────────────────────────────────────────────────────────────

--- Persist specs to the cache file.
---@param key     string
---@param profile string
---@param specs   table[]
function M.save(key, profile, specs)
  if key == "" then
    return
  end

  local encode_ok, json_str = pcall(vim.fn.json_encode, {
    version = CACHE_VERSION,
    cache_key = key,
    profile = profile,
    specs = specs,
  })
  if not encode_ok then
    if vim.g.ltos_debug then
      vim.notify("[cache.save] encode failed: " .. tostring(json_str), vim.log.levels.DEBUG)
    end
    return
  end

  -- Ensure the cache directory exists
  local dir = vim.fn.fnamemodify(CACHE_PATH, ":h")
  local mkdir_ok = pcall(vim.fn.mkdir, dir, "p")
  if not mkdir_ok then
    return
  end

  local write_ok = pcall(vim.fn.writefile, { json_str }, CACHE_PATH)
  if not write_ok and vim.g.ltos_debug then
    vim.notify("[cache.save] write failed", vim.log.levels.DEBUG)
  end
end

return M
