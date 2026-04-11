-- ~/.config/nvim/lua/core/icons.lua
-- Single source of truth for all glyphs / symbols used in the config.

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
