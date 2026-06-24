-- ~/.config/nvim/lua/toolchain/mappings.lua
-- Strategy layer: tool-name → mason-package-name (single source of truth).
--
-- Rules:
--   • lsp_to_mason: only entries whose mason pkg DIFFERS from server name.
--   • tool_to_mason: only entries whose mason pkg DIFFERS from tool name.
--   • system_tools: NEVER install via mason.
--   • resolve() priority: user overrides → system_tools → Nix → mappings → identity.
--   • Tool resolution: use toolchain.rules.resolve() — not here (avoids circular require).
-- P2: Uses externalized defaults from toolchain.defaults.mappings
-- FIX-OPT-C (2026-06-23): replaced vim.tbl_deep_extend with pure-Lua shallow copy.
-- strategy layer (Layer 3) should have zero vim.* dependency (INV-9 purity).
-- These are flat string→string/bool tables, so shallow copy is sufficient.

local M = {}

-- Load default mappings
local defaults = require("toolchain.defaults.mappings")
local util = require("core.kernel.util")

-- ── Pure-Lua shallow copy (replaces vim.tbl_deep_extend) ──────────────────────

local function copy_table(t)
  local out = {}
  for k, v in pairs(t) do
    out[k] = v
  end
  return out
end

-- ── LSP server → mason package ────────────────────────────────────────────────

M.lsp_to_mason = copy_table(defaults.lsp_to_mason)

-- ── Formatter / linter tool → mason package ──────────────────────────────────

M.tool_to_mason = copy_table(defaults.tool_to_mason)

-- ── System-only tools (never via mason) ──────────────────────────────────────

M.system_tools = copy_table(defaults.system_tools)

-- ── User-defined overrides (runtime-injected via register_override) ──────────

M.overrides = {}

-- ── Extension API ─────────────────────────────────────────────────────────────

---@param server string
---@param pkg string
function M.register_lsp(server, pkg) M.lsp_to_mason[server] = pkg end

---@param tool string
---@param pkg string
function M.register_tool(tool, pkg) M.tool_to_mason[tool] = pkg end

---@param tool string
---@param override { use_mason: boolean, pkg: string|nil }
function M.register_override(tool, override) M.overrides[tool] = override end

-- ── Public API ────────────────────────────────────────────────────────────────

---@param server string
---@return string
function M.lsp_pkg(server) return M.lsp_to_mason[server] or server end

---@param tool string
---@return string|nil
function M.tool_pkg(tool)
  if M.system_tools[tool] == true then
    return nil
  end
  return M.tool_to_mason[tool] or tool
end

---@param tool string
---@return { use_mason: boolean, pkg: string|nil }
function M.resolve(tool)
  if M.system_tools[tool] then
    return { use_mason = false, pkg = nil }
  end
  return { use_mason = true, pkg = M.tool_to_mason[tool] or tool }
end

return M
