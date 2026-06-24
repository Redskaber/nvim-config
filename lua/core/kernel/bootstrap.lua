-- lua/core/kernel/bootstrap.lua
-- Layer 0 kernel: runs before lazy.nvim.
-- Only the absolute minimum that must happen first — no plugin deps here.
--
-- Responsibilities (all are "must set before lazy.setup()" globals):
--   1. Disable netrw (so neo-tree/snacks can manage directories)
--   2. Leader keys (must be set before lazy + plugins parse keymaps)
--   3. LazyVim file explorer selection (must be set before LazyVim reads it
--      during lazy.setup() spec construction — if set later, LazyVim has
--      already loaded the default neo-tree spec and our Snacks keymaps
--      get overridden)

-- Disable netrw BEFORE anything else can load it
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Leader keys (must be set before lazy + plugins parse keymaps)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- File explorer: use Snacks explorer (not neo-tree).
-- this MUST be set here in bootstrap,
-- before lazy.setup() reads it. Previously this was in config/globals.lua
-- which loads inside lazy.setup() — too late, LazyVim had already built
-- the neo-tree spec. Moving to bootstrap ensures LazyVim sees "snacks"
-- at spec-construction time and skips neo-tree entirely.
-- Keymaps: <leader>e (root dir) and <leader>E (cwd) in plugins/ui/ui.lua.
vim.g.lazyvim_file_explorer = "snacks"
