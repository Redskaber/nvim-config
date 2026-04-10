-- ~/.config/nvim/lua/modules/lang/shell.lua
local cap = require("core.capability")

cap.register("shell", {
  treesitter = { "bash" },
  formatters = {
    sh = { "shfmt" },
    bash = { "shfmt" },
    fish = { "fish_indent" },
  },
  linters = {
    sh = { "shellcheck" },
    bash = { "shellcheck" },
    fish = { "fish" },
  },
  mason = { "shfmt", "shellcheck" },
})
