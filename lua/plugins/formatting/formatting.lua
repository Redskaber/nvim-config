-- ~/.config/nvim/lua/plugins/formatting/formatting.lua
-- Engine declaration only. formatters_by_ft built by runtime/adapters/conform.lua.

return {
  { "mason-org/mason.nvim" },
  {
    "stevearc/conform.nvim",
    dependencies = { "mason-org/mason.nvim" },
    -- No opts here: all opts injected by runtime adapter spec
  },
}
