-- lua/core/compiler/cache/key.lua
-- Layer 1 compiler: cache key computation (pure via ports for path resolution).

local util = require("core.kernel.util")
local version = require("core.compiler.cache.version")
local ports = require("core.compiler.ports")

local M = {}

-- This maintains INV-10 (compiler IO via ports) and allows mocking
-- in tests without filesystem access.
local function read_file(path)
  local content = ports.read_file(path)
  return content or ""
end

---@param mod string
---@return string|nil
local function resolve_path(mod)
  return ports.resolve_runtime_file(mod:gsub("%.", "/") .. ".lua")
end

---@param modules string[]
local function append_module_hashes(modules, parts)
  for _, mod in ipairs(modules or {}) do
    local path = resolve_path(mod)
    if path then
      local content = read_file(path)
      parts[#parts + 1] = path .. "=" .. util.hash(content)
    else
      parts[#parts + 1] = mod .. "=missing"
    end
  end
end

---@param lang_modules string[]
---@param profile      string
---@param cap_modules? string[]
---@return string
function M.compute(lang_modules, profile, cap_modules)
  profile = profile or "full"
  local parts = {}

  append_module_hashes(lang_modules, parts)
  append_module_hashes(cap_modules, parts)

  if #parts == 0 then
    return ""
  end

  table.sort(parts)
  local composite = table.concat(parts, "|")
  return string.format("%s:%s:v%d", util.hash(composite), profile, version.SCHEMA_VERSION)
end

return M
