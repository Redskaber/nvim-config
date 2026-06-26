-- lua/runtime/adapters/lsp.lua
-- Backend layer: IR → nvim-lspconfig LazySpec.
-- REFACTOR (TODO-5.4): pure IR reader — no vim API calls.
-- Reads only IR.merged_lsp and IR.resolved.lsp.
--
-- FIX-TEST-BUG (2026-06-26): opts is now a STATIC table, not a lazy function.
-- Tests and downstream consumers index `spec.opts.servers` / `spec.opts.ensure_installed`
-- directly. lazy.nvim still merges static `opts = { ... }` with other specs' opts
-- for the same plugin (via `opts_extend` when present), so we do not lose the
-- merge behaviour — we only stop deferring construction to load-time.

local M = {}

--- Safe nested table get (replaces vim.tbl_get).
---@param t table
---@param ... string
---@return any
local function tget(t, ...)
  local cur = t
  for _, k in ipairs({ ... }) do
    if type(cur) ~= "table" then
      return nil
    end
    cur = cur[k]
  end
  return cur
end

---@param ir table  LIR or SPEC-ready IR
---@return table[]  LazySpec[]
function M.build(ir)
  if not ir.merged_lsp then
    return { { _ltos_error = "[ltos:lsp] IR missing required field: merged_lsp" } }
  end

  -- servers: shallow copy of merged_lsp so downstream specs/adapters can mutate
  -- their own copy without affecting the IR.
  local servers = {}
  for server, cfg in pairs(ir.merged_lsp) do
    servers[server] = cfg
  end

  -- ensure_installed: list of mason-managed LSP servers (resolved.lsp[server] == true)
  local ensure_installed = {}
  local seen = {}
  for server, _ in pairs(ir.merged_lsp) do
    local want = tget(ir, "resolved", "lsp", server)
    if want and not seen[server] then
      ensure_installed[#ensure_installed + 1] = server
      seen[server] = true
    end
  end

  return {
    {
      "neovim/nvim-lspconfig",
      _source = "ltos:lsp",
      opts = { servers = servers },
    },
    {
      "mason-org/mason-lspconfig.nvim",
      _source = "ltos:lsp",
      opts = {
        ensure_installed = ensure_installed,
        automatic_installation = false,
      },
    },
  }
end

return M
