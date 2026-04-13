-- ~/.config/nvim/lua/modules/lang/lisp.lua

return {
  version = 1,
  treesitter = { "commonlisp", "scheme", "clojure" },
  lsp = {
    -- Common Lisp
    lemminx = nil, -- 占位（CL 通常用 sly / slime，不完全 LSP）
    -- Clojure
    clojure_lsp = {},
  },
  formatters = {
    lisp = {
      { kind = "formatter", exe = "cljfmt" },
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
