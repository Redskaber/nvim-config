-- ~/.config/nvim/lua/modules/lang/kotlin.lua

return {
  version = 1,
  treesitter = { "kotlin" },
  lsp = {
    kotlin_language_server = {},
  },
  formatters = {
    kotlin = {
      { kind = "formatter", exe = "ktfmt" },
    },
  },
  linters = {
    kotlin = {
      "ktlint",
    },
  },
  mason = {
    "kotlin-language-server",
    "ktlint",
    "ktfmt",
  },
}
