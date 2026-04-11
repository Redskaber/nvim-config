-- ~/.config/nvim/lua/config/lazy.lua
-- Bootstrap lazy.nvim, then assemble the full spec via runtime.build().

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    repo,
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Run the five-stage pipeline; returns flat list of lazy plugin specs.
local runtime = require("runtime")
local lang_specs = runtime.build()
runtime.setup_commands()

require("lazy").setup({
  spec = vim.list_extend(
    {
      -- LazyVim core
      { "LazyVim/LazyVim", import = "lazyvim.plugins" },
      -- Plugin layer (UI/editor/ai/git — no lang logic here)
      { import = "plugins" },
    },
    -- Capability-derived specs (lsp, mason, treesitter, conform, lint)
    lang_specs
  ),

  defaults = { lazy = true, version = false },
  install = { colorscheme = { "catppuccin", "tokyonight", "habamax" } },
  checker = { enabled = true, notify = true },

  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },

  rocks = {
    enabled = false,
    -- 或者仅禁用 hererocks:
    -- hererocks = false,
  },

  lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
})
