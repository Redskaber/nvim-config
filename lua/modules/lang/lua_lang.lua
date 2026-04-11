-- ~/.config/nvim/lua/modules/lang/lua_lang.lua
-- DSL: Lua language toolchain declaration.

return {
  treesitter = { "lua", "luadoc", "luap" },
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
  formatters = {
    lua = { "stylua" },
  },
  mason = { "stylua" },
}
