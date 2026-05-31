-- lua/core/domain/keybind_presets_data.lua
-- Layer 2 domain: Known keybind presets (pure data, no vim API).
--
-- Single source of truth for keybind preset names.
-- Used by:
-- - core/domain/ext_schema.lua (validation)
-- - modules/capability/defaults/keybind_presets.lua (preset implementations)
--
-- Adding a new preset requires only extending this list.

local M = {}

--- Known keybind preset names.
M.HELIX = "helix"
M.VIM = "vim"
M.EMACS = "emacs"

--- All known presets in canonical order.
M.ALL = {
  M.HELIX,
  M.VIM,
  M.EMACS,
}

--- Check if a string is a known preset.
---@param preset string
---@return boolean
function M.is_known(preset)
  for _, known in ipairs(M.ALL) do
    if known == preset then
      return true
    end
  end
  return false
end

--- Get all presets as a set table for fast lookup.
---@return table<string, boolean>
function M.as_set()
  local set = {}
  for _, preset in ipairs(M.ALL) do
    set[preset] = true
  end
  return set
end

return M
