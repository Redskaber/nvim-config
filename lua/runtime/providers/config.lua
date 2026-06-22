-- lua/runtime/providers/config.lua
-- ConfigProvider: data-driven lazy.nvim setup composition.

local M = {}

local DEFAULT_DISABLED_PLUGINS = {
  "gzip",
  "matchit",
  "matchparen",
  "netrwPlugin",
  "tarPlugin",
  "tohtml",
  "tutor",
  "zipPlugin",
}

local _spec_providers = {}

--- Register a spec provider: fn() → lazy spec table[]
---@param fn fun(): table[]
function M.register_spec(fn)
  _spec_providers[#_spec_providers + 1] = fn
end

M.register_spec(function()
  return {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    { import = "plugins" },
  }
end)

---@param lang_specs table[]  capability-derived specs from runtime.build()
---@return table  lazy.setup() options table
function M.build_setup_opts(lang_specs)
  local spec = {}
  for _, provider in ipairs(_spec_providers) do
    vim.list_extend(spec, provider())
  end
  vim.list_extend(spec, lang_specs or {})

  local disabled = vim.g.ltos_disabled_plugins or DEFAULT_DISABLED_PLUGINS

  return {
    spec = spec,
    defaults = { lazy = true, version = false },
    install = { colorscheme = { "catppuccin", "tokyonight", "habamax" } },
    checker = { enabled = true, notify = true },
    performance = {
      rtp = { disabled_plugins = disabled },
    },
    rocks = { enabled = false },
    lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
  }
end

return M