-- ~/.config/nvim/lua/modules/lang/nix.lua
-- nil_ls and nixpkgs_fmt are always system-managed on a Nix host.
-- On non-Nix hosts, nil_ls falls back to mason via toolchain.rules.
return {
  treesitter = { "nix" },
  lsp = { nil_ls = {} },
  formatters = { nix = { "nixpkgs_fmt" } },
  -- mason list intentionally empty: both tools are system-resolved
  mason = {},
}
