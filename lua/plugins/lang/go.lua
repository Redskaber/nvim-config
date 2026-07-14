-- ~/.config/nvim/lua/plugins/lang/go.lua
-- Go language editing enhancements.
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter (runtime/adapters/) owns: LSP (gopls), formatter (gofmt),
--     linters, mason packages, treesitter parsers.
--   • This file owns: debug adapter integration (nvim-dap-go) — the one piece
--     LTOS's compiler pipeline does not cover, since DAP is an editing-layer
--     concern (run/debug breakpoints), not a build-time concern.
--
-- nvim-dap-go: Delve-based Go debugger. Integrates with the existing
-- nvim-dap + nvim-dap-ui setup in plugins/debug/dap.lua. Adds:
--   • <leader>dgt — debug go test (current test under cursor)
--   • <leader>dgl — debug last go test
--   • <leader>dga — debug go test (all tests in package)
return {
  {
    "leoluz/nvim-dap-go",
    ft = "go",
    dependencies = { "mfussenegger/nvim-dap" },
    opts = {}, -- uses sane defaults: delve path auto-detected via mason
    config = function(_, opts)
      require("dap-go").setup(opts)
    end,
  },
}
