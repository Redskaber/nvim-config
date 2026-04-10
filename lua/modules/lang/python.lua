-- ~/.config/nvim/lua/modules/lang/python.lua
-- "__ruff_or_black__" sentinel is resolved to a dynamic function in the
-- conform adapter; it must never appear in any other adapter's output.
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
  formatters = { python = { "__ruff_or_black__" } },
  linters = { python = { "ruff" } },
  mason = { "pyright", "ruff", "black" },
}
