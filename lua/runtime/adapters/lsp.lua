-- ~/.config/nvim/lua/runtime/adapters/lsp.lua
-- Codegen adapter: IR → nvim-lspconfig LazySpec.

local M = {}

---@param ir table  post-optimize IR
---@return table[]
function M.build(ir)
  local servers = ir.merged_lsp
  if not servers or vim.tbl_isempty(servers) then
    return {}
  end

  -- Strip the internal `mason` flag; lspconfig does not consume it.
  local clean = {}
  for server, cfg in pairs(servers) do
    local c = vim.deepcopy(cfg)
    c.mason = nil
    clean[server] = c
  end

  return {
    {
      "neovim/nvim-lspconfig",
      opts = { servers = clean },
      _source = "ltos:lsp",
    },
  }
end

return M
