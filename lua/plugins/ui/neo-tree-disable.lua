-- ~/.config/nvim/lua/plugins/ui/neo-tree-disable.lua
-- Explicitly disable neo-tree.
-- vim.g.lazyvim_file_explorer = "snacks" is set in core/kernel/bootstrap.lua
-- (Layer 0, before lazy.setup()). This should prevent LazyVim from loading
-- neo-tree, but we add enabled = false as a belt-and-suspenders safeguard
-- — if any LazyVim version still loads neo-tree, this ensures it stays off
-- and our Snacks.explorer keymaps (<leader>e, <leader>E) are never overridden.
-- Layer: ui (interface — explorer selection).
return {
  { "nvim-neo-tree/neo-tree.nvim", enabled = false },
}
