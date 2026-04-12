-- ~/.config/nvim/lua/modules/lang/zig.lua
return {
  treesitter = { "zig" },
  lsp = { zls = {} },
  formatters = { zig = { "zigfmt" } }, -- system binary; skipped by mason adapter
  mason = {}, -- zls resolved via mappings.lsp_pkg("zls"); zigfmt is system-managed
}
