-- lua/runtime/adapters/keybind.lua
-- P3: Capability adapter for 'keybind' cap_type.
-- Keybindings are applied as side-effects, so this adapter returns an empty list of LazySpecs.

local M = {}

local util = require("core.kernel.util")

--- Builds LazySpecs for keybind capabilities.
--- Keybindings are handled as side-effects and do not produce LazySpecs.
---@param ir IR The current Intermediate Representation.
---@param caps_by_name table<string, table>  Map of module_name to keybind capability tables.
---@return LazySpec[]  An array of LazySpecs (always empty).
function M.build(ir, caps_by_name)
  if not caps_by_name or util.tbl_isempty(caps_by_name) then
    return {}
  end

  -- Keybindings are applied as side-effects (e.g., via vim.keymap.set in the emitter).
  -- This adapter does not produce LazySpecs.
  -- The `ir` and `caps_by_name` can be used to prepare data for the emitter if needed.

  return {}
end

return M

