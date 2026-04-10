-- ~/.config/nvim/lua/modules/lang/rust.lua
local cap = require("core.capability")
local tc = require("core.toolchain")

cap.register("rust", {
  treesitter = { "rust", "toml" },
  lsp = {
    rust_analyzer = {
      mason = tc.use_mason("rust-analyzer"),
      settings = {
        ["rust-analyzer"] = {
          cargo = { allFeatures = true, loadOutDirsFromCheck = true },
          procMacro = { enable = true },
          checkOnSave = { command = "check" },
          inlayHints = { enable = true, chainingHints = true, maxLength = 25 },
        },
      },
    },
  },
  formatters = { rust = { "rustfmt" } },
  linters = { rust = { "clippy" } },
  mason = tc.use_mason("rust-analyzer") and { "rust-analyzer" } or {},
})
