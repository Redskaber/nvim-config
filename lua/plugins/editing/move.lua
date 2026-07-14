-- ~/.config/nvim/lua/plugins/editing/move.lua
-- Move lines and selections up/down — high-frequency editing operation.
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter: build-time toolchain config.
--   • This file: editing-layer line/block movement.
--
-- mini.move: from the mini.nvim ecosystem. Provides:
--   • <A-h> / <A-l>  — move current line / selection left / right
--   • <A-j> / <A-k>  — move current line / selection down / up
--
-- Why mini.move over alternatives (move.nvim, etc.):
--   • Consistent with mini.ai / mini.pairs / mini.surround (same ecosystem)
--   • Handles visual block mode correctly
--   • Reindents moved lines automatically (respects 'autoindent')
--   • ~80 LOC, zero dependencies
return {
  {
    "nvim-mini/mini.move",
    event = "VeryLazy",
    opts = {
      mappings = {
        left = "<A-h>",
        right = "<A-l>",
        down = "<A-j>",
        up = "<A-k>",
        line_left = "<A-h>",
        line_right = "<A-l>",
        line_down = "<A-j>",
        line_up = "<A-k>",
      },
      options = {
        reindent_linewise = true,
      },
    },
    config = function(_, opts)
      require("mini.move").setup(opts)
    end,
  },
}