-- ~/.config/nvim/lua/modules/lang/go.lua
-- DSL: Go toolchain declaration.
-- gofmt is system-managed via the Go toolchain.

return {
  version = 1,
  treesitter = { "go", "gomod", "gowork", "gosum" },
  lsp = {
    gopls = {
      settings = {
        gopls = {
          gofumpt = true,
          codelenses = {
            gc_details = false,
            generate = true,
            regenerate_cgo = true,
            run_govulncheck = true,
            test = true,
            tidy = true,
            upgrade_dependency = true,
            vendor = true,
          },
          hints = {
            assignVariableTypes = true,
            compositeLiteralFields = true,
            compositeLiteralTypes = true,
            constantValues = true,
            functionTypeParameters = true,
            parameterNames = true,
            rangeVariableTypes = true,
          },
          analyses = {
            fieldalignment = true,
            nilness = true,
            unusedparams = true,
            unusedwrite = true,
            useany = true,
          },
          usePlaceholders = true,
          completeUnimported = true,
          staticcheck = true,
          directoryFilters = { "-.git", "-.vscode", "-.idea", "-.venv", "-node_modules" },
          semanticTokens = true,
        },
      },
    },
  },
  formatters = {
    go = { "gofmt", "goimports" },
  },
  mason = { "goimports" },
}
