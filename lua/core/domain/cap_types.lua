-- lua/core/domain/cap_types.lua
-- Layer 2 domain: Capability type constants (pure data, no vim API).
--
-- Centralized cap_type strings to avoid duplication across:
-- - core/compiler/ir.lua (ext_caps initialization)
-- - core/domain/ext_schema.lua (validation)
-- - runtime/defaults/cap_adapters.lua (routing)
--
-- Adding a new cap_type requires only extending this list.

local M = {}

--- Capability type enum constants.
M.IMAGE = "image"
M.MEDIA = "media"
M.AI = "ai"
M.KEYBIND = "keybind"

--- All known cap_types in canonical order.
-- FIX-P3 (2026-07-15): EDITOR removed — no adapter registered (half-implementation).
M.ALL = {
  M.IMAGE,
  M.MEDIA,
  M.AI,
  M.KEYBIND,
}

--- Check if a string is a known cap_type.
---@param t string
---@return boolean
function M.is_known(t)
  for _, known in ipairs(M.ALL) do
    if known == t then
      return true
    end
  end
  return false
end

--- Get all cap_types as a set table for fast lookup.
---@return table<string, boolean>
function M.as_set()
  local set = {}
  for _, t in ipairs(M.ALL) do
    set[t] = true
  end
  return set
end

return M