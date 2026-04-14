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
    asm = {}, -- no widely-available mason linter for asm
  },
  mason = {
    "asm-lsp",
  },
}
