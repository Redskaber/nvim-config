-- ~/.config/nvim/lua/modules/lang/kotlin.lua

return {
  version = 1,
  treesitter = { "kotlin" },
  lsp = {
    kotlin_language_server = {},
  },
  formatters = {
    kotlin = {
      { kind = "formatter", name = "ktfmt" },
    },
  },
  linters = {
    kotlin = { "ktlint" },
  },
  mason = { "ktlint", "ktfmt" },
}

