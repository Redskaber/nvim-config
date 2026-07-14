-- ~/.config/nvim/lua/plugins/completion/cmp.lua
-- Completion engines: nvim-cmp + blink.cmp + emoji source.
-- Layer: completion (input: text/snippet/AI completion).
return {
  -- nvim-cmp: emoji source add-on
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-emoji" },
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