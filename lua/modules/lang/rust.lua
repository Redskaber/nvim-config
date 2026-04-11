-- ~/.config/nvim/lua/modules/lang/rust.lua
-- DSL: Rust toolchain declaration.
-- rustfmt and clippy are system-managed (via rustup); never via mason.

return {
  treesitter = { "rust", "toml" },
  lsp = {
    rust_analyzer = {
      settings = {
        ["rust-analyzer"] = {
          cargo = { allFeatures = true, loadOutDirsFromCheck = true, runBuildScripts = true },
          checkOnSave = { allFeatures = true, command = "clippy", extraArgs = { "--no-deps" } },
          procMacro = {
            enable = true,
            ignored = {
              ["async-trait"] = { "async_trait" },
              ["napi-derive"] = { "napi" },
              ["async-recursion"] = { "async_recursion" },
            },
          },
        },
      },
    },
  },
  formatters = {
    rust = { "rustfmt" },
  },
  linters = {
    rust = { "clippy" },
  },
  -- rustfmt / clippy come with the Rust toolchain; mason handles only the LSP
  mason = {},
}
