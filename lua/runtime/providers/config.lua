-- lua/runtime/providers/config.lua
-- ConfigProvider: data-driven lazy.nvim setup composition.
--
-- FIX-AUTO-UPDATE (2026-07-15): plugin auto-update is now opt-in via
-- vim.g.ltos_auto_update = true. Previously checker = { enabled = true }
-- ran a background git-fetch on EVERY nvim startup, which:
--   • slows down startup (network round-trip per plugin)
--   • can hang on slow/flaky connections
--   • updates plugins without user consent (surprise breakage)
-- Now default is disabled; users opt in via:
--   vim.g.ltos_auto_update = true  (set in bootstrap.lua or init.lua)
-- Or manually run :Lazy update / :Lazy check when ready.

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
function M.register_spec(fn) _spec_providers[#_spec_providers + 1] = fn end

M.register_spec(
  function()
    return {
      { "LazyVim/LazyVim", import = "lazyvim.plugins" },
      { import = "plugins" },
    }
  end
)

---@param lang_specs table[]  capability-derived specs from runtime.build()
---@return table  lazy.setup() options table
function M.build_setup_opts(lang_specs)
  local spec = {}
  for _, provider in ipairs(_spec_providers) do
    vim.list_extend(spec, provider())
  end
  vim.list_extend(spec, lang_specs or {})

  local disabled = vim.g.ltos_disabled_plugins or DEFAULT_DISABLED_PLUGINS

  -- FIX-AUTO-UPDATE (2026-07-15): checker is opt-in.
  --   vim.g.ltos_auto_update = true  → enable background update check on startup
  --   vim.g.ltos_auto_update = false (default) → no auto-update; use :Lazy update
  -- When enabled, `notify = true` shows a notification when updates are found.
  local auto_update = vim.g.ltos_auto_update == true
  local checker_opts = auto_update
    and { enabled = true, notify = true }
    or { enabled = false }

  return {
    spec = spec,
    defaults = { lazy = true, version = false },
    install = { colorscheme = { "catppuccin", "tokyonight", "habamax" } },
    checker = checker_opts,
    performance = {
      rtp = { disabled_plugins = disabled },
    },
    rocks = { enabled = false },
    lockfile = vim.fn.stdpath("state") .. "/lazy-lock.json",
  }
end

return M