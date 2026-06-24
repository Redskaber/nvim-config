-- lua/modules/lang/asm.lua
-- DSL: Assembly toolchain declaration.
-- asm-lsp is resolved via lsp_to_mason mapping; no formatter/linter available via mason.

return {
  version = 1,
  treesitter = { "asm" },
  lsp = {
    asm_lsp = {},
  },
  formatters = {
    asm = { "nasmfmt" },
  },
  linters = {},
  -- No formatters or linters: no widely-available mason-installable tools for asm.
  -- asm-lsp is installed via the LSP adapter (lsp_to_mason["asm_lsp"] = "asm-lsp").
  mason = {},
}
