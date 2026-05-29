-- lua/runtime/providers/registry.lua
-- ProviderRegistry: profile-aware module list composition.

local module_provider = require("runtime.providers.interface")

local M = {}

local _filters = {}
local _extra = {}

-- Core modules always included in minimal profile
local CORE_MODULES = {
  "modules.lang.lua_lang",
}

--- Register an additional lang module path (extension point).
---@param mod string
function M.register(mod)
  assert(type(mod) == "string" and mod ~= "", "module path must be non-empty string")
  _extra[#_extra + 1] = mod
end

--- Register a profile filter: fn(modules, profile) → modules
---@param name string
---@param fn fun(modules: string[], profile: string): string[]
function M.register_filter(name, fn)
  assert(type(fn) == "function", "filter must be a function")
  _filters[name] = fn
end

local function dedup_sorted(modules)
  local seen = {}
  local out = {}
  for _, m in ipairs(modules) do
    if not seen[m] then
      seen[m] = true
      out[#out + 1] = m
    end
  end
  table.sort(out)
  return out
end

--- Built-in minimal profile filter: keep CORE_MODULES only.
M.register_filter("minimal", function(modules, _)
  local core_set = {}
  for _, m in ipairs(CORE_MODULES) do
    core_set[m] = true
  end
  local out = {}
  for _, m in ipairs(modules) do
    if core_set[m] then
      out[#out + 1] = m
    end
  end
  return out
end)

--- Resolve the final module list for a profile.
---@param profile string
---@return string[]
function M.resolve(profile)
  profile = profile or "full"
  local modules = dedup_sorted(vim.list_extend(module_provider.discover(), _extra))

  local filter = _filters[profile]
  if filter then
    return filter(modules, profile)
  end
  return modules
end

return M
