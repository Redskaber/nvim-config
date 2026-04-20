-- ~/.config/nvim/lua/modules/lang/dart.lua
-- Dart SDK provides everything: LSP, formatter, analyzer

return {
  version = 1,
  treesitter = { "dart" },

  lsp = {
    dartls = {
      cmd = { "dart", "language-server", "--protocol=lsp" },
      settings = {
        dart = {
          completeFunctionCalls = true,
          showTodos = true,
        },
      },
    },
  },

  formatters = {
    dart = { "dart-format" }, -- maps to `dart format`
  },

  linters = {
    dart = { "dart-analyze" }, -- maps to `dart analyze`
  },

  -- 完全由 SDK 提供，不走 mason
  mason = {},
}
