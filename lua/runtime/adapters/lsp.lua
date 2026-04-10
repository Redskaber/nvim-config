-- ~/.config/nvim/lua/runtime/adapters/lsp.lua
-- Converts capability.lsp declarations → nvim-lspconfig plugin spec.

local M = {}

---@param caps table<string, Capability>
---@return table[]
function M.build(caps)
  local servers = {}

  for _, cap in pairs(caps) do
    if cap.lsp then
      for server, config in pairs(cap.lsp) do
        -- Deep-merge if the same server appears in multiple lang modules
        if servers[server] then
          servers[server] = vim.tbl_deep_extend("force", servers[server], config)
        else
          servers[server] = vim.deepcopy(config)
        end
      end
    end
  end

  if vim.tbl_isempty(servers) then
    return {}
  end

  return {
    {
      "neovim/nvim-lspconfig",
      opts = { servers = servers },
    },
  }
end

return M
