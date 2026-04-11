-- ~/.config/nvim/lua/modules/lang/lua_lang.lua
return {
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
  mason = { "stylua" },
}
