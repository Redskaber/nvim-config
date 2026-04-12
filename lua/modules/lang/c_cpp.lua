-- ~/.config/nvim/lua/modules/lang/c_cpp.lua
-- V2: pure return, zero side-effects. Mason decision delegated to resolve stage.

return {
  version = 1,
  treesitter = { "c", "cpp", "cmake" },
  lsp = {
    clangd = {
      cmd = {
        "clangd",
        "--background-index",
        "--compile-commands-dir=build",
        "--fallback-style=llvm",
        "--all-scopes-completion",
      },
    },
  },
  formatters = {
    c = { "clang-format" },
    cpp = { "clang-format" },
  },
  linters = {
    c = { "clangtidy" },
    cpp = { "clangtidy" },
  },
  mason = { "clang-format" }, -- clangd resolved via mappings.lsp_pkg("clangd")
}
