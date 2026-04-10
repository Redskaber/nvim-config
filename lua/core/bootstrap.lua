-- ~/.config/nvim/lua/core/bootstrap.lua
-- Runs before lazy.nvim; only the absolute minimum that must happen first.

-- Disable netrw BEFORE anything else loads it
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Leader keys (must be set before lazy/plugins)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
