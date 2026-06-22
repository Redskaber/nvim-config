-- lua/runtime/providers/registry.lua
-- ProviderRegistry: profile-aware module list composition.
-- P2: Uses module metadata (core=true) instead of hard-coded CORE_MODULES

local module_provider = require("runtime.providers.interface")

local M = {}

local _filters = {}
local _extra = {}

--- Check if a module is a core module by loading and inspecting metadata.
---@param mod_path string
---@return boolean
local function is_core_module(mod_path)
  local ok, mod = pcall(require, mod_path)
  if not ok then
    return false
  end
  return type(mod) == "table" and mod.core == true
end

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

--- nix profile: same module set as full; tool strategy differs via BuildRequest.prefer_system.
M.register_filter("nix", function(modules, _)
  return modules
end)

--- Built-in minimal profile filter: keep core modules only (modules with core=true).
M.register_filter("minimal", function(modules, _)
  local out = {}
  for _, m in ipairs(modules) do
    if is_core_module(m) then
      out[#out + 1] = m
    end
  end
  return out
end)

---@return string[]
function M.list_profiles()
  local names = { "full" }
  for name in pairs(_filters) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

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