-- ~/.config/nvim/lua/plugins/lang/lisp.lua
-- Lisp family language editing enhancements (Clojure / Scheme / Common Lisp).
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter (runtime/adapters/) owns: LSP (clojure_lsp), formatter
--     (cljfmt), linters (clj-kondo), mason packages, treesitter.
--   • This file owns: interactive REPL evaluation (conjure).
--
-- conjure.nvim: the de-facto standard REPL client for Lisp languages in
-- Neovim. Connects to a running REPL (nrepl for Clojure, socket for
-- Scheme/Common Lisp) and evaluates forms inline. Essential for the
-- REPL-driven development workflow that defines the Lisp ecosystem.
--
-- Supported filetypes (auto-detected by conjure):
--   • fennel • clojure • scheme • commonlisp • janet • hy • julia
--
-- Key evaluations (conjure provides its own <localleader> mappings):
--   • <localleader>ee — eval current form
--   • <localleader>eb — eval current buffer
--   • <localleader>er — eval root form
--   • <localleader>ls — show log (REPL output)
return {
  {
    "Olical/conjure",
    ft = { "clojure", "scheme", "lisp", "fennel", "janet" },
    init = function()
      -- Conjure reads g:conjure#settings at load time; set before require.
      vim.g["conjure#mapping#prefix"] = "<localleader>"
      vim.g["conjure#log#hud#enabled"] = true
      vim.g["conjure#log#hud#width"] = 1.0
      vim.g["conjure#log#hud#height"] = 0.3
      vim.g["conjure#log#hud#border"] = "rounded"
      -- Auto-evaluate files on open (useful for small Clojure scripts)
      vim.g["conjure#eval#result_register"] = "0"
    end,
    opts = {},
  },
}