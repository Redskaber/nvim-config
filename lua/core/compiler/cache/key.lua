-- lua/core/compiler/cache/key.lua
-- Layer 1 compiler: cache key computation (pure, no IO, no vim side-effects).
--
-- REFACTOR (TODO-2.3): extracted from cache.lua.
-- Key = content_hash(sorted file contents) + ":" + profile + ":" + schema_version
-- Content hash is more reliable than mtime (survives touch, rsync, git checkout).

local util = require("core.kernel.util")
local version = require("core.compiler.cache.version")

local M = {}

--- Read file contents (returns "" on failure — pure for caching purposes).
---@param path string
---@return string
local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return ""
  end
  local s = f:read("*a") or ""
  f:close()
  return s
end

--- Resolve module path → filesystem path.
---@param mod string  e.g. "modules.lang.python"
---@return string|nil
local function resolve_path(mod)
  local results = vim.api.nvim_get_runtime_file(mod:gsub("%.", "/") .. ".lua", false)
  return results and results[1]
end

--- Compute a composite cache key for a set of lang modules.
--- Key = FNV-hash(sorted "path=content_hash" pairs) + ":" + profile + ":" + schema_version
---@param lang_modules string[]
---@param profile      string
---@return string  non-empty on success, "" on failure
function M.compute(lang_modules, profile)
  profile = profile or "full"
  local parts = {}

  for _, mod in ipairs(lang_modules) do
    local path = resolve_path(mod)
    if path then
      local content = read_file(path)
      parts[#parts + 1] = path .. "=" .. util.hash(content)
    end
  end

  if #parts == 0 then
    return ""
  end

  table.sort(parts)
  local composite = table.concat(parts, "|")
  return string.format("%s:%s:v%d", util.hash(composite), profile, version.SCHEMA_VERSION)
end

return M
