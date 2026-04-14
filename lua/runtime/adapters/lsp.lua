-- lua/runtime/adapters/lsp.lua
-- Backend layer: IR → nvim-lspconfig LazySpec.
-- REFACTOR (TODO-5.4): pure IR reader — no vim API calls.
-- Reads only IR.merged_lsp and IR.resolved.lsp.

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

  local servers = {}
  for server, cfg in pairs(ir.merged_lsp) do
    servers[server] = cfg
  end

  local ensure_installed = {}
  for server, _ in pairs(ir.merged_lsp) do
    local want = tget(ir, "resolved", "lsp", server)
    if want then
      ensure_installed[#ensure_installed + 1] = server
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
