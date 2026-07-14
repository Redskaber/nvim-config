-- ~/.config/nvim/lua/plugins/toolchain/formatting.lua
-- Engine declaration only. formatters_by_ft built by runtime/adapters/conform.lua.

return {
  { "mason-org/mason.nvim" },
  {
    "stevearc/conform.nvim",
    dependencies = { "mason-org/mason.nvim" },
    cmd = "ConformInfo",
    keys = {
      {
        "<leader>cF",
        function() require("conform").format({ formatters = { "injected" }, timeout_ms = 3000 }) end,
        mode = { "n", "x" },
        desc = "Format Injected Langs",
      },
    },
    -- No opts here: all opts injected by runtime adapter spec
  },
}