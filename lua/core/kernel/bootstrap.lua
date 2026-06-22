-- lua/core/kernel/bootstrap.lua
-- Layer 0 kernel: runs before lazy.nvim.
-- Only the absolute minimum that must happen first — no plugin deps here.

-- FIX-DEPLOY-EXPLORER (2026-06-23): set vim.g.lazyvim_file_explorer BEFORE
-- lazy.setup() so LazyVim reads the correct value when building specs.
-- If this is set in config/globals.lua (loaded inside lazy.setup()), it's
-- too late — LazyVim has already loaded the neo-tree spec with its own
-- <leader>e keymap, which overrides our Snacks.explorer binding.
-- Setting it here (earliest possible point) ensures LazyVim uses "snacks"
-- and does NOT load neo-tree, so our <leader>e → Snacks.explorer works.
vim.g.lazyvim_file_explorer = "snacks"

-- Disable netrw BEFORE anything else can load it
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Leader keys (must be set before lazy + plugins parse keymaps)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
