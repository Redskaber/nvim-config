-- ~/.config/nvim/init.lua
-- nvim-config v4 · LTOS compiler kernel
-- Layer 0: bootstrap (netrw off, leader keys, LazyVim globals)
-- Layer 1: lazy.nvim + LTOS compiler pipeline

require("core.kernel.bootstrap")
require("config.lazy")
