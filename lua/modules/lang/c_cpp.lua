-- ~/.config/nvim/lua/modules/lang/c_cpp.lua
local cap = require("core.capability")
local tc = require("core.toolchain")

cap.register("c_cpp", {
  treesitter = { "c", "cpp" },
  lsp = {
    clangd = {
      mason = tc.use_mason("clangd"),
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
  mason = tc.use_mason("clangd") and { "clangd", "clang-format" } or { "clang-format" },
})
