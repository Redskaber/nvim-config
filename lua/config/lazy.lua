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

local runtime = require("runtime")
-- FIX-P1 (2026-07-15): top-level pcall around runtime.build().
-- If the LTOS compiler pipeline crashes (syntax error in a module, broken
-- adapter, cache corruption), nvim still starts with LazyVim defaults
-- instead of showing a raw Lua stack trace. The error is surfaced via
-- vim.notify so the user can diagnose.
local lang_specs
local ok, build_err = pcall(function() lang_specs = runtime.build() end)
if not ok then
  vim.notify(
    "[LTOS] runtime.build() failed — starting with LazyVim defaults only:\n"
      .. tostring(build_err),
    vim.log.levels.ERROR
  )
  lang_specs = {}
end

vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function() runtime.setup_commands() end,
})

local config_provider = require("runtime.providers.config")
require("lazy").setup(config_provider.build_setup_opts(lang_specs))