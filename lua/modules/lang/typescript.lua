-- ~/.config/nvim/lua/modules/lang/typescript.lua
-- DSL: TypeScript / JavaScript toolchain declaration.

return {
  treesitter = { "javascript", "typescript", "tsx", "jsdoc" },
  lsp = {
    vtsls = {
      settings = {
        complete_function_calls = true,
        vtsls = {
          enableMoveToFileCodeAction = true,
          autoUseWorkspaceTsdk = true,
          experimental = {
            maxInlayHintLength = 30,
            completion = {
              enableServerSideFuzzyMatch = true,
            },
          },
        },
        typescript = {
          updateImportsOnFileMove = { enabled = "always" },
          suggest = { completeFunctionCalls = true },
          inlayHints = {
            enumMemberValues = { enabled = true },
            functionLikeReturnTypes = { enabled = true },
            parameterNames = { enabled = "literals" },
            parameterTypes = { enabled = true },
            propertyDeclarationTypes = { enabled = true },
            variableTypes = { enabled = false },
          },
        },
        javascript = {
          updateImportsOnFileMove = { enabled = "always" },
          suggest = { completeFunctionCalls = true },
          inlayHints = {
            enumMemberValues = { enabled = true },
            functionLikeReturnTypes = { enabled = true },
            parameterNames = { enabled = "literals" },
            parameterTypes = { enabled = true },
            propertyDeclarationTypes = { enabled = true },
            variableTypes = { enabled = false },
          },
        },
      },
    },
  },
  formatters = {
    javascript = { { kind = "formatter", strategy = "prettierd_or_prettier" } },
    javascriptreact = { { kind = "formatter", strategy = "prettierd_or_prettier" } },
    typescript = { { kind = "formatter", strategy = "prettierd_or_prettier" } },
    typescriptreact = { { kind = "formatter", strategy = "prettierd_or_prettier" } },
  },
  linters = {
    javascript = { "eslint" },
    javascriptreact = { "eslint" },
    typescript = { "eslint" },
    typescriptreact = { "eslint" },
  },
  mason = { "vtsls", "prettierd", "eslint_d" },
}
