-- ~/.config/nvim/lua/modules/lang/rust.lua
-- rust-analyzer and rustfmt are managed by rustup; mason decision delegated to resolve stage.

return {
  treesitter = { "rust", "toml" },
  lsp = {
    rust_analyzer = {
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
  mason = { "rust-analyzer" },
}
