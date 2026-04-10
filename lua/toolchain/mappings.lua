-- ~/.config/nvim/lua/toolchain/mappings.lua
-- Single source of truth for tool-name → mason-package-name mappings.
-- Edit here to add/override; never scatter mappings across adapters.

local M = {}

-- LSP server name  →  mason package name
-- Only entries that DIFFER from the server name need to be listed.
M.lsp_to_mason = {
  lua_ls = "lua-language-server",
  rust_analyzer = "rust-analyzer",
  nil_ls = "nil",
  tsserver = "typescript-language-server",
  jsonls = "json-lsp",
  yamlls = "yaml-language-server",
  pylsp = "python-lsp-server",
  clangd = "clangd",
  gopls = "gopls",
  zls = "zls",
  vtsls = "vtsls",
  taplo = "taplo",
  pyright = "pyright",
}

-- Formatter / linter tool name  →  mason package name
-- Only entries that DIFFER need to be listed.
M.tool_to_mason = {
  ruff_format = "ruff",
  fish_indent = nil, -- system only; never install via mason
  fish = nil, -- linter is the fish binary itself
  nixpkgs_fmt = nil, -- nix-managed
  rustfmt = nil, -- comes with rustup
  clippy = nil, -- comes with rustup
  gofmt = nil, -- ships with Go toolchain
  zigfmt = nil, -- ships with Zig toolchain
}

-- Tools that must ALWAYS come from the system, regardless of nix detection.
M.always_system = {
  rustup = true,
  nix = true,
  git = true,
  make = true,
  cc = true,
  fish = true,
  rustfmt = true,
  clippy = true,
  gofmt = true,
  zigfmt = true,
  fish_indent = true,
  nixpkgs_fmt = true,
}

--- Resolve an LSP server name to its mason package name.
---@param server string
---@return string
function M.lsp_pkg(server)
  return M.lsp_to_mason[server] or server
end

--- Resolve a formatter/linter tool name to its mason package name.
--- Returns nil when the tool must not be mason-managed.
---@param tool string
---@return string|nil
function M.tool_pkg(tool)
  if M.tool_to_mason[tool] == nil and not M.always_system[tool] then
    return tool -- identity: package name == tool name
  end
  return M.tool_to_mason[tool] -- may be nil (system-only)
end

return M
