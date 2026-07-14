-- ~/.config/nvim/lua/plugins/lang/rust.lua
-- Rust language editing enhancements.
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter (runtime/adapters/) owns: LSP (rust_analyzer), formatter
--     (rustfmt, system-managed), linters (clippy, system-managed), treesitter.
--   • This file owns: Cargo.toml dependency management (crates.nvim).
--
-- crates.nvim: displays latest crate versions inline in Cargo.toml, lets
-- you upgrade dependencies with a single keypress. High-frequency for any
-- Rust project. Complements rust_analyzer (which handles code intelligence)
-- by managing the dependency manifest itself.
--
-- Key features:
--   • Highlight crate versions (outdated / pre-release / yanked)
--   • <leader>rcu — update all crates in Cargo.toml
--   • Hoist / hide crate features inline
return {
  {
    "Saecki/crates.nvim",
    ft = { "toml", "rust" },
    event = { "BufRead Cargo.toml" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      src = {
        coq = { enabled = false },
      },
      popup = {
        autofocus = true,
        border = "rounded",
      },
    },
    config = function(_, opts)
      require("crates").setup(opts)
      -- Highlight + keymaps only active in Cargo.toml
      vim.api.nvim_create_autocmd("BufRead", {
        pattern = "Cargo.toml",
        callback = function()
          local crates = require("crates")
          vim.keymap.set(
            "n",
            "<leader>rcu",
            crates.upgrade_all_crates,
            { buffer = true, desc = "Upgrade all crates" }
          )
          vim.keymap.set("n", "<leader>rt", crates.toggle, { buffer = true, desc = "Toggle crate" })
          vim.keymap.set(
            "n",
            "<leader>rv",
            crates.show_versions_popup,
            { buffer = true, desc = "Show versions" }
          )
          vim.keymap.set(
            "n",
            "<leader>rf",
            crates.show_features_popup,
            { buffer = true, desc = "Show features" }
          )
        end,
      })
    end,
  },
}