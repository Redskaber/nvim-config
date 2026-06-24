-- lua/modules/capability/registry.lua
-- P3: Registry for capability modules.

local M = {}

-- Stores { cap_type = { mod_path1, mod_path2 }, ... }
local _registry = {}

-- Stores { mod_path = true, ... } for quick lookup
local _all_modules = {}

--- Resets the registry (for testing only).
function M._reset()
  _registry = {}
  _all_modules = {}
end

--- Register a capability module.
---@param cap_type string
---@param mod_path string
function M.register(cap_type, mod_path)
  assert(type(cap_type) == "string" and cap_type ~= "", "cap_type must be a non-empty string")
  assert(type(mod_path) == "string" and mod_path ~= "", "mod_path must be a non-empty string")

  if not _registry[cap_type] then
    _registry[cap_type] = {}
  end

  -- Ensure idempotency
  local found = false
  for _, registered_path in ipairs(_registry[cap_type]) do
    if registered_path == mod_path then
      found = true
      break
    end
  end

  if not found then
    _registry[cap_type][#_registry[cap_type] + 1] = mod_path
    table.sort(_registry[cap_type]) -- Keep sorted for consistency
  end
  _all_modules[mod_path] = true
end

--- Check if a module path is registered.
---@param mod_path string
---@return boolean
function M.is_registered(mod_path) return _all_modules[mod_path] == true end

--- Get all registered module paths for a given capability type.
---@param cap_type string
---@return string[]
function M.get_by_type(cap_type) return _registry[cap_type] or {} end

--- Get all registered module paths across all capability types.
---@return string[]
function M.get_all()
  local all = {}
  for mod_path in pairs(_all_modules) do
    all[#all + 1] = mod_path
  end
  table.sort(all)
  return all
end

--- Get all known capability categories (types).
---@return string[]
function M.categories()
  local categories = {}
  for cap_type in pairs(_registry) do
    categories[#categories + 1] = cap_type
  end
  table.sort(categories)
  return categories
end

--- Register multiple capability entries at once.
---@param entries table<number, {cap_type: string, mod_path: string}>
function M.register_all(entries)
  for _, entry in ipairs(entries) do
    M.register(entry.cap_type, entry.mod_path)
  end
end

return M

