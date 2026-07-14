-- ~/.config/nvim/lua/plugins/lang/typescript.lua
-- TypeScript / JavaScript language editing enhancements.
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter (runtime/adapters/) owns: LSP (vtsls), formatter
--     (prettierd_or_prettier strategy), linters (eslint), mason packages,
--     treesitter (javascript/typescript/tsx/jsdoc).
--   • This file owns: TypeScript compiler integration (tsc.nvim).
--
-- tsc.nvim: runs `tsc --noEmit` in the background and surfaces type errors
-- as Neovim diagnostics. Complements vtsls (which provides fast in-editor
-- intelligence) by catching whole-project type errors that the LSP server
-- may not surface (especially across files with different tsconfigs).
--
-- Usage: <leader>ct — run tsc and populate quickfix/diagnostics
return {
  {
    "dmmulroy/tsc.nvim",
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    cmd = "TSC",
    opts = {
      auto_open_qflist = true,
      auto_close_qflist = false,
      auto_focus_qflist = false,
      use_trouble_qflist = true, -- integrates with trouble.nvim (already installed)
      flags = { noEmit = true },
      hide_progress = false,
    },
    config = function(_, opts)
      require("tsc").setup(opts)
      vim.keymap.set("n", "<leader>ct", "<cmd>TSC<cr>", { desc = "TypeScript check (tsc)" })
    end,
  },
}