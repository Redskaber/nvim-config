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
    -- use strategy FormatterNode form to match
    -- spec/modules/lang_spec.lua expectation (strategy field required).
    -- Pattern consistent with typescript.lua using prettierd_or_prettier.
    python = { { kind = "formatter", strategy = "ruff_or_black" } },
  },
  linters = {
    python = { "ruff" },
  },
  mason = { "ruff", "black", "isort" },
}