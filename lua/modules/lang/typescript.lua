-- ~/.config/nvim/lua/modules/lang/typescript.lua
-- markup.lua is the single source of truth for: css, scss, html, yaml,
-- markdown, json, jsonc.  typescript.lua only owns js/ts filetypes.

return {
  treesitter = { "javascript", "jsdoc", "typescript", "tsx" },
  lsp = {
    vtsls = {
      settings = {
        typescript = {
          inlayHints = {
            parameterNames = { enabled = "literals" },
            parameterTypes = { enabled = true },
            variableTypes = { enabled = true },
            propertyDeclarationTypes = { enabled = true },
            functionLikeReturnTypes = { enabled = true },
            enumMemberValues = { enabled = true },
          },
        },
        javascript = {
          inlayHints = {
            parameterNames = { enabled = "literals" },
            parameterTypes = { enabled = true },
            variableTypes = { enabled = true },
            propertyDeclarationTypes = { enabled = true },
            functionLikeReturnTypeHints = { enabled = true },
          },
        },
      },
    },
  },
  -- Owns only JS/TS/JSX/TSX filetypes; markup filetypes live in markup.lua.
  formatters = {
    javascript = { "prettierd" },
    javascriptreact = { "prettierd" },
    typescript = { "prettierd" },
    typescriptreact = { "prettierd" },
  },
  linters = {
    javascript = { "eslint" },
    javascriptreact = { "eslint" },
    typescript = { "eslint" },
    typescriptreact = { "eslint" },
  },
  mason = { "vtsls", "prettierd" },
}
