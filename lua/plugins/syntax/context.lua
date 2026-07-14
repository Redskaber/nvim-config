-- ~/.config/nvim/lua/plugins/syntax/context.lua
-- Sticky context header: pins the current function/class signature at top.
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter: build-time treesitter parser config (ensure_installed).
--   • This file: editing-layer sticky context display.
--
-- nvim-treesitter-context: shows the parent function/class signature as a
-- floating sticky header at the top of the window when you scroll past it.
-- Answers "what function am I currently inside?" without scrolling up.
-- High-frequency for any long file — the single most-requested TS addon.
--
-- Performance: lazy by design (only renders when scrolled past context),
-- uses extmarks, no impact on large-file scroll performance.
return {
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "VeryLazy",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      enable = true,
      max_lines = 0, -- 0 = no limit (show full context stack)
      min_window_height = 0,
      line_numbers = true,
      multiline_threshold = 20, -- max multi-line node size before truncation
      trim_scope = "outer", -- 'outer' | 'inner'
      mode = "cursor", -- 'cursor' | 'topline'
      separator = nil, -- no separator line (use default highlight)
      zindex = 20,
      on_attach = nil,
    },
    config = function(_, opts)
      require("treesitter-context").setup(opts)
      -- Toggle keymap: <leader>ut (utility → toggle context)
      vim.keymap.set("n", "<leader>ut", "<cmd>TSContextToggle<cr>", { desc = "Toggle TS context" })
    end,
  },
}