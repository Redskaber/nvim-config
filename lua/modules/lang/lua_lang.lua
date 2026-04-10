-- ~/.config/nvim/lua/modules/lang/lua_lang.lua
local cap = require("core.capability")

cap.register("lua_lang", {
  treesitter = { "lua", "luadoc" },
  lsp = {
    lua_ls = {
      settings = {
        Lua = {
          workspace = { checkThirdParty = false },
          codeLens = { enable = true },
          completion = { callSnippet = "Replace" },
          doc = { privateName = { "^_" } },
          hint = {
            enable = true,
            setType = false,
            paramType = true,
            paramName = "Disable",
            semicolon = "Disable",
            arrayIndex = "Disable",
          },
        },
      },
    },
  },
  formatters = { lua = { "stylua" } },
  mason = { "stylua", "lua-language-server" },
})
