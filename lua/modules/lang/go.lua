-- ~/.config/nvim/lua/modules/lang/go.lua
local cap = require("core.capability")

cap.register("go", {
  treesitter = { "go", "gomod", "gowork", "gosum" },
  lsp = {
    gopls = {
      settings = {
        gopls = {
          hints = {
            assignVariableTypes = true,
            compositeLiteralFields = true,
            compositeLiteralTypes = true,
            constantValues = true,
            functionTypeParameters = true,
            parameterNames = true,
            rangeVariableTypes = true,
          },
        },
      },
    },
  },
  formatters = { go = { "gofmt" } },
  mason = { "gopls" },
})
