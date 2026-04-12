-- ~/.config/nvim/lua/modules/lang/shell.lua
return {
  treesitter = { "bash", "fish", "zsh" },
  formatters = {
    sh = { "shfmt" },
    bash = { "shfmt" },
    fish = { "fish_indent" }, -- system binary; mason adapter will skip it
  },
  linters = {
    sh = { "shellcheck" },
    bash = { "shellcheck" },
    fish = { "fish" }, -- system binary
  },
  mason = { "shfmt", "shellcheck" },
}
