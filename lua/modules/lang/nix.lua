-- ~/.config/nvim/lua/modules/lang/nix.lua
-- DSL: Nix toolchain declaration.
-- nixpkgs-fmt is system-managed on NixOS; resolved by toolchain rules.

return {
  version = 1,
  treesitter = { "nix" },
  lsp = {
    nil_ls = {},
  },
  formatters = {
    --- nix = { "alejandra" }, --- nixfmt
  },
  linters = {
    nix = { "statix" },
  },
  -- nixpkgs_fmt is in system_tools → rules.resolve() returns use_mason=false
  -- nil_ls mason package name resolved via lsp_to_mason mapping
  mason = {},
}
