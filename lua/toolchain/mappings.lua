-- ~/.config/nvim/lua/toolchain/mappings.lua
-- Single source of truth for tool-name → mason-package-name mappings.
-- Edit here to add/override; never scatter mappings across adapters.
--
-- Merged `always_system` and nil-valued `tool_to_mason` entries into a
-- single `system_tools` set.  `tool_to_mason` now only lists tools whose mason
-- package name DIFFERS from the tool name — no nil sentinel values.
-- `resolve()` checks `system_tools` first, then `tool_to_mason`, then identity.

local M = {}

-- ── LSP server name → mason package name ────────────────────────────────────
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

-- ── Formatter / linter tool name → mason package name ───────────────────────
-- Only tools whose mason package name DIFFERS from the tool name are listed.
-- Tools that are always system-managed belong in `system_tools` below.
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

-- ── Tools that must ALWAYS come from the system ──────────────────────────────
-- Combines the former `always_system` list and nil-valued `tool_to_mason` entries.
-- Add any binary that ships with its language toolchain or a system package manager.
M.system_tools = {
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

-- ── User-defined overrides ───────────────────────────────────────────────────
-- Can also be set via vim.g.ltos_tool_overrides in globals.lua.
-- Each entry: tool_name → { use_mason: boolean, pkg: string|nil }
M.overrides = {}

-- ── Public API ───────────────────────────────────────────────────────────────

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
  if M.system_tools[tool] then
    return nil
  end
  return M.tool_to_mason[tool] or tool -- identity fallback
end

--- Unified resolution entry point for any tool.
--- Priority: user overrides → system_tools → tool_to_mason → identity
---@param tool string
---@return { use_mason: boolean, pkg: string|nil }
function M.resolve(tool)
  -- 1. User overrides (vim.g.ltos_tool_overrides or M.overrides)
  local user_overrides = vim.g.ltos_tool_overrides or {}
  local override = M.overrides[tool] or user_overrides[tool]
  if override ~= nil then
    return override
  end

  -- 2. System-only tools (unified set — replaces always_system + nil sentinel)
  if M.system_tools[tool] then
    return { use_mason = false, pkg = nil }
  end

  -- 3. Explicit mason package mapping (name differs from tool name)
  local mapped = M.tool_to_mason[tool]
  if mapped then
    return { use_mason = true, pkg = mapped }
  end

  -- 4. Identity fallback: tool name is its own mason package name
  if vim.g.ltos_debug then
    vim.notify("[ltos] identity mapping for tool: " .. tool, vim.log.levels.DEBUG)
  end
  return { use_mason = true, pkg = tool }
end

return M
