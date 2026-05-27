-- lua/modules/lang/shell.lua
-- DSL: Shell toolchain declaration.
return {
  version = 1,
  treesitter = { "bash", "zsh", "fish" },
  lsp = {
    bashls = {},
  },
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
