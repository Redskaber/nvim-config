-- ~/.config/nvim/lua/runtime/adapters/lsp.lua
-- Pure function: ctx → lazy spec for nvim-lspconfig.
-- No env checks, no toolchain calls; those live in pipeline.resolve().

local M = {}

---@param ctx table  pipeline context (post-optimize)
---@return table[]
function M.build(ctx)
  local servers = ctx.merged_lsp
  if not servers or vim.tbl_isempty(servers) then
    return {}
  end

  -- Strip the internal `mason` flag; lspconfig doesn't know it.
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
