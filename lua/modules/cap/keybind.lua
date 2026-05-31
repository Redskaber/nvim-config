-- lua/modules/cap/keybind.lua
-- P3: Keybind capability DSL module.
-- Adheres to DSL purity constraints (Invariant 8 extended).

return {
  cap_type = "keybind",
  version = 1,
  -- Placeholder fields based on AUDIT.md
  preset = "vim", -- e.g., "helix", "vim", "emacs"
  groups = {
    {
      prefix = "<leader>",
      name = "General",
      icon = "",
    },
  },
}
