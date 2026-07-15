-- ~/.config/nvim/lua/plugins/completion/cmp.lua
-- Completion engines: nvim-cmp + blink.cmp + emoji source.
-- Layer: completion (input: text/snippet/AI completion).
return {
  -- nvim-cmp: emoji source add-on.
  -- P1-5: only loaded when the user explicitly selects nvim-cmp via
  -- `vim.g.lazyvim_cmp = "nvim-cmp"`. Default ("auto") picks blink.cmp,
  -- in which case this spec (and its cmp-emoji dep) is disabled so it
  -- is not dead code cluttering the lazy tree — it is a conditional fallback.
  {
    "hrsh7th/nvim-cmp",
    enabled = function() return vim.g.lazyvim_cmp == "nvim-cmp" end,
    dependencies = {
      { "hrsh7th/cmp-emoji", enabled = function() return vim.g.lazyvim_cmp == "nvim-cmp" end },
    },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts) table.insert(opts.sources, { name = "emoji" }) end,
  },

  { "Kaiser-Yang/blink-cmp-avante" },

  -- blink.cmp: modern completion engine with Avante integration
  {
    "saghen/blink.cmp",
    optional = true,
    specs = { "Kaiser-Yang/blink-cmp-avante" },
    opts = {
      sources = {
        default = { "avante" },
        providers = { avante = { module = "blink-cmp-avante", name = "Avante" } },
      },
    },
  },
}