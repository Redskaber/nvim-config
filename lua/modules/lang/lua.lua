-- ~/.config/nvim/lua/modules/lang/lua.lua
-- DSL: Lua language toolchain declaration.
-- P2: core module for minimal profile

return {
  core = true,
  version = 1,
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
  linters = {
    -- that may not be installed, causing ENOENT errors. Users who want luacheck
    -- can install it (luarocks install luacheck) and add it back here.
    lua = { "luacheck" },
  },
  mason = { "stylua" },
}