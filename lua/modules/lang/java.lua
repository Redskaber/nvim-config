-- ~/.config/nvim/lua/modules/lang/java.lua

return {
  version = 1,
  treesitter = { "java" },
  lsp = {
    jdtls = {
      settings = {
        java = {
          format = {
            enabled = false, -- 交给 formatter
          },
        },
      },
    },
  },
  formatters = {
    java = { { kind = "formatter", name = "google-java-format" }, },
  },
  linters = {
    java = { "checkstyle", },
  },
  mason = {
    "google-java-format",
    "checkstyle",
  },
}
