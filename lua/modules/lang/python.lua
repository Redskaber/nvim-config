-- ~/.config/nvim/lua/modules/lang/python.lua
-- DSL: Python toolchain declaration.

return {
  version = 1,
  treesitter = { "python" },
  lsp = {
    pyright = {
      settings = {
        pyright = { disableOrganizeImports = true },
        python = {
          analysis = {
            autoSearchPaths = true,
            diagnosticMode = "workspace",
            useLibraryCodeForTypes = true,
          },
        },
      },
    },
  },
  formatters = {
    python = { "ruff" },
  },
  linters = {
    python = { "ruff" },
  },
  mason = { "ruff", "black", "isort" },
}
