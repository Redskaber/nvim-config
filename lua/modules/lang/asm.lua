-- ~/.config/nvim/lua/modules/lang/asm.lua

return {
  version = 1,
  treesitter = { "asm" },
  lsp = {
    asm_lsp = {},
  },
  formatters = {
    asm = {},
  },
  linters = {
    asm = {
      "asm-lint",
    },
  },
  mason = {
    "asm-lsp",
  },
}
