-- ~/.config/nvim/lua/modules/lang/python.lua
return {
  treesitter = { "python" },
  lsp = {
    pyright = {
      settings = {
        python = {
          analysis = {
            typeCheckingMode = "strict",
            autoSearchPaths = true,
            useLibraryCodeForTypes = true,
          },
        },
      },
    },
  },
  formatters = { python = { { kind = "formatter", strategy = "ruff_or_black" } } },
  linters = { python = { "ruff" } },
  mason = { "ruff", "pyright", "black" },
}
