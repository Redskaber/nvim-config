-- ~/.config/nvim/lua/modules/lang/python.lua
local cap = require("core.capability")

cap.register("python", {
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
  -- formatter is dynamic; stored as a sentinel, adapter handles fn wrapping
  formatters = { python = { "__ruff_or_black__" } },
  linters = { python = { "ruff" } },
  mason = { "pyright", "ruff", "black" },
})
