-- ~/.config/nvim/lua/modules/lang/zig.lua
local cap = require("core.capability")

cap.register("zig", {
  treesitter = { "zig" },
  lsp = { zls = {} },
  formatters = { zig = { "zigfmt" } },
})
