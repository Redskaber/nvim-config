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
-- A nil value means the tool is system-only (never install via mason).
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

-- User-defined overrides. Can also be set via vim.g.ltos_tool_overrides.
-- Each entry: tool_name → { use_mason: boolean, pkg: string|nil }
M.overrides = {}
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

--- Unified resolution entry point for any tool.
--- Priority: overrides[tool] → always_system[tool] → tool_to_mason[tool] → identity
---@param tool string
---@return { use_mason: boolean, pkg: string|nil }
function M.resolve(tool)
  -- Check M.overrides and vim.g.ltos_tool_overrides (user-set in globals.lua)
  local user_overrides = vim.g.ltos_tool_overrides or {}
  local override = M.overrides[tool] or user_overrides[tool]
  if override ~= nil then
    return override
  end

  -- always_system tools are never mason-managed
  if M.always_system[tool] then
    return { use_mason = false, pkg = nil }
  end

  -- tool_to_mason: iterate with pairs() to detect nil-valued keys (system-only entries)
  local has_entry = false
  for k in pairs(M.tool_to_mason) do
    if k == tool then
      has_entry = true
      break
    end
  end
  if has_entry then
    local pkg = M.tool_to_mason[tool] -- string → mason-managed, nil → system-only
    if pkg ~= nil then
      return { use_mason = true, pkg = pkg }
    else
      return { use_mason = false, pkg = nil }
    end
  end

  -- identity: tool name is its own mason package name
  if vim.g.ltos_debug then
    vim.notify("[ltos] identity mapping for tool: " .. tool, vim.log.levels.DEBUG)
  end
  return { use_mason = true, pkg = tool }
end
return M
