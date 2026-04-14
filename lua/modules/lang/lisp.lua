-- ~/.config/nvim/lua/modules/lang/lisp.lua

return {
  version = 1,
  treesitter = { "commonlisp", "scheme", "clojure" },
  lsp = {
    -- Clojure
    clojure_lsp = {},
  },
  formatters = {
    lisp = {
      { kind = "formatter", name = "cljfmt" },
    },
  },
  linters = {
    lisp = {
      "clj-kondo",
    },
  },
  mason = {
    "clojure-lsp",
    "clj-kondo",
  },
}
