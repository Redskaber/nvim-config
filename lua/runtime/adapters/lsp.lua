-- ~/.config/nvim/lua/runtime/adapters/lsp.lua
-- Backend layer: IR → nvim-lspconfig LazySpec.
-- Reads only IR.merged_lsp and IR.resolved.lsp — no toolchain logic here.

local M = {}

---@param ir table  LIR or SPEC-ready IR
---@return table[]  LazySpec[]
function M.build(ir)
  if not ir.merged_lsp then
    vim.notify("[ltos:lsp] IR missing required field: merged_lsp", vim.log.levels.WARN)
    return {}
  end

  -- Build the servers table for lspconfig opts
  local servers = {}
  for server, cfg in pairs(ir.merged_lsp) do
    -- Only include servers that are NOT mason-managed
    -- (mason-managed ones are handled by mason-lspconfig)
    local want_mason = vim.tbl_get(ir, "resolved", "lsp", server)
    if not want_mason then
      -- System-managed LSP: configure directly
      servers[server] = cfg
    else
      -- Mason-managed: still set config, mason-lspconfig will call setup()
      servers[server] = cfg
    end
  end

  -- remove unused variable: server_names not needed
  return {
    {
      "neovim/nvim-lspconfig",
      _source = "ltos:lsp",
      opts = {
        servers = servers,
      },
    },
    {
      "mason-org/mason-lspconfig.nvim",
      _source = "ltos:lsp",
      opts = {
        -- Only auto-install servers that are mason-managed
        -- mason-lspconfig.nvim expects lspconfig server names, not mason pkg names
        ensure_installed = (function()
          local pkgs = {}
          for server, _ in pairs(ir.merged_lsp) do
            local want = vim.tbl_get(ir, "resolved", "lsp", server)
            if want then
              pkgs[#pkgs + 1] = server -- lspconfig server name, not mason pkg name
            end
          end
          return pkgs
        end)(),
        automatic_installation = false,
      },
    },
  }
end

return M
