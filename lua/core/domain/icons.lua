-- lua/core/domain/icons.lua
-- Layer 2 domain: single source of truth for all glyphs / symbols.
-- Used by LTOS commands and adapters. config/icons.lua re-exports this for app layer.

return {
  diagnostics = {
    Error = " ",
    Warn = " ",
    Hint = " ",
    Info = " ",
  },
  git = {
    added = " ",
    modified = " ",
    removed = " ",
  },
  fold = {
    open = "",
    close = "",
  },
  todo = {
    FIX = " ",
    TODO = " ",
    HACK = " ",
    WARN = " ",
    PERF = " ",
    NOTE = " ",
    TEST = "⏲ ",
  },
}
