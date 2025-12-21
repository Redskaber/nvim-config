-- ~/.config/nvim/lua/config/lazy.lua
-- author: redskaber
-- datetime: 2025-12-12

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
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

require("lazy").setup({
  spec = {
    -- @import: lazyvim and lazyvim.plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- @import: custom plugins
    { import = "plugins" },
  },
  defaults = {
    -- @enabled: lazy load
    lazy = true,
    -- @update: always
    version = false,
  },
  install = {
    colorscheme = { "tokyonight", "habamax" },
  },
  checker = {
    -- @update: periodically
    enabled = true,
    -- @update: notify
    notify = true,
  }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
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
})
