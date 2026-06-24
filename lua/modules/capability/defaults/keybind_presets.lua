-- lua/modules/capability/defaults/keybind_presets.lua
-- Pure preset binding tables (data-driven, no vim API).

return {
  vim = {
    { lhs = "<C-h>", rhs = "<C-w>h", mode = "n", desc = "Window left" },
    { lhs = "<C-j>", rhs = "<C-w>j", mode = "n", desc = "Window down" },
    { lhs = "<C-k>", rhs = "<C-w>k", mode = "n", desc = "Window up" },
    { lhs = "<C-l>", rhs = "<C-w>l", mode = "n", desc = "Window right" },
  },
  helix = {
    { lhs = "<C-w>h", rhs = "<C-w>h", mode = "n", desc = "Window left" },
    { lhs = "<C-w>j", rhs = "<C-w>j", mode = "n", desc = "Window down" },
    { lhs = "<C-w>k", rhs = "<C-w>k", mode = "n", desc = "Window up" },
    { lhs = "<C-w>l", rhs = "<C-w>l", mode = "n", desc = "Window right" },
    { lhs = "gd", rhs = "gd", mode = "n", desc = "Go to definition" },
  },
  emacs = {
    { lhs = "<C-x>o", rhs = "<C-w>w", mode = "n", desc = "Other window" },
    { lhs = "<C-x>0", rhs = "<C-w>c", mode = "n", desc = "Close window" },
    { lhs = "<C-x>1", rhs = "<C-w>o", mode = "n", desc = "Close other windows" },
  },
}
