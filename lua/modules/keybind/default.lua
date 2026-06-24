-- lua/modules/keybind/default.lua
-- P3: Default keybind capability DSL module.
-- Adheres to DSL purity constraints (Invariant 8 extended).

return {
  cap_type = "keybind",
  version = 1,
  -- Placeholder fields based on AUDIT.md
  provides = { "default_keymaps" },
  bindings = {
    { lhs = "<leader>pv", rhs = ":Ex<CR>", mode = "n", desc = "Open netrw" },
    { lhs = "<leader>ph", rhs = ":nohlsearch<CR>", mode = "n", desc = "Clear highlight" },
  },
}

