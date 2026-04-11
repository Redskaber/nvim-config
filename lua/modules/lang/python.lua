-- ~/.config/nvim/lua/modules/lang/python.lua
-- DSL: Python toolchain declaration.

return {
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
    python = { { kind = "formatter", strategy = "ruff_or_black" } },
  },
  linters = {
    python = { "ruff" },
  },
  mason = { "ruff", "pyright", "black", "isort" },
}
