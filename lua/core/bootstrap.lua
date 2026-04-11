-- ~/.config/nvim/lua/core/bootstrap.lua
-- Kernel layer: runs before lazy.nvim.
-- Only the absolute minimum that must happen first — no plugin deps here.

-- Disable netrw BEFORE anything else can load it
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Leader keys (must be set before lazy + plugins parse keymaps)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
