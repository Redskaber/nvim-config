-- ~/.config/nvim/lua/modules/lang/nix.lua
local cap = require("core.capability")

cap.register("nix", {
  treesitter = { "nix" },
  lsp = { nil_ls = {} },
  formatters = { nix = { "nixpkgs_fmt" } },
})
