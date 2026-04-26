-- ~/.config/nvim/lua/config/globals.lua
-- All vim.g.* runtime globals. Loaded by options.lua so the order is clear.
-- Keep this file ONLY for globals; vim.opt.* lives in config/options.lua.

-- Disable netrw BEFORE anything else can load it
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Leader keys (must be set before lazy + plugins parse keymaps)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- ── LazyVim feature flags ─────────────────────────────────────────────────
vim.g.autoformat = true
vim.g.snacks_animate = true
vim.g.lazyvim_picker = "auto" -- "telescope" | "fzf" | "auto"
vim.g.lazyvim_cmp = "auto" -- "nvim-cmp"  | "blink.cmp" | "auto"
vim.g.ai_cmp = true
vim.g.deprecation_warnings = false
vim.g.trouble_lualine = true

-- Root detection order: LSP → common project markers → cwd
vim.g.root_spec = { "lsp", { ".git", "lua", "Cargo.toml", "pyproject.toml" }, "cwd" }
vim.g.root_lsp_ignore = { "copilot" }

-- Markdown: don't let LazyVim fight our custom indent
vim.g.markdown_recommended_style = 0
