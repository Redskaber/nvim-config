-- ~/.config/nvim/lua/toolchain/mappings.lua
-- Single source of truth for tool-name → mason-package-name mappings (P0-1).
--
-- Rules:
--   • tool_to_mason contains ONLY entries whose mason pkg differs from tool name.
--     No nil sentinel values — system-only tools live in system_tools.
--   • system_tools: tools that must NEVER be mason-managed.
--   • resolve() priority: user overrides → system_tools → tool_to_mason → identity

local M = {}

-- ── LSP server name → mason package name ────────────────────────────────────
-- Only entries that DIFFER from the server name are listed.
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
-- Only tools whose mason package name DIFFERS from the tool name.
-- Tools that ship with their language toolchain belong in system_tools below.
M.tool_to_mason = {
  ruff_format = "ruff",
}

-- ── Tools that must ALWAYS come from the system (never via mason) ────────────
-- Includes: language toolchain binaries, system package manager tools,
-- and any tool that would conflict with external environment management.
M.system_tools = {
  -- Shell / system
  rustup = true,
  nix = true,
  git = true,
  make = true,
  cc = true,
  -- Language toolchain formatters / linters (managed by their own toolchain)
  rustfmt = true,
  clippy = true,
  gofmt = true,
  zigfmt = true,
  fish_indent = true,
  fish = true,
  nixpkgs_fmt = true,
}

-- ── User-defined overrides ───────────────────────────────────────────────────
-- Can also be set via vim.g.ltos_tool_overrides at runtime.
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
--- Returns nil when the tool is system-only.
---@param tool string
---@return string|nil
function M.tool_pkg(tool)
  if M.system_tools[tool] then
    return nil
  end
  return M.tool_to_mason[tool] or tool -- identity fallback
end

--- Unified resolution entry point for any tool or server name.
--- Priority: user overrides → system_tools → tool_to_mason → identity
---@param tool string
---@return { use_mason: boolean, pkg: string|nil }
function M.resolve(tool)
  -- 1. User overrides (vim.g or M.overrides)
  local user_overrides = vim.g.ltos_tool_overrides or {}
  local override = M.overrides[tool] or user_overrides[tool]
  if override ~= nil then
    return override
  end

  -- 2. System-only set
  if M.system_tools[tool] then
    return { use_mason = false, pkg = nil }
  end

  -- 3. Explicit mapping (pkg name differs from tool name)
  local mapped = M.tool_to_mason[tool]
  if mapped then
    return { use_mason = true, pkg = mapped }
  end

  -- 4. Identity fallback
  if vim.g.ltos_debug then
    vim.notify("[ltos] identity mapping: " .. tool, vim.log.levels.DEBUG)
  end
  return { use_mason = true, pkg = tool }
end

return M
