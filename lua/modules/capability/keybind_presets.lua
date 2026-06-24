-- lua/modules/capability/keybind_presets.lua
-- Pure preset resolver for keybind capability DSL.

local defaults = require("modules.capability.defaults.keybind_presets")

local M = {}

---@param preset string|nil
---@return table[]
function M.resolve(preset)
  if not preset or type(preset) ~= "string" then
    return {}
  end
  return defaults[preset] or {}
end

---@return string[]
function M.known_presets()
  local names = {}
  for name in pairs(defaults) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

---@param preset string
---@return boolean
function M.is_known(preset) return defaults[preset] ~= nil end

return M
