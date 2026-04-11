-- ~/.config/nvim/lua/runtime/adapters/lint.lua
-- Codegen adapter: IR → nvim-lint LazySpec.

local M = {}

---@param ir table  post-optimize IR
---@return table[]
function M.build(ir)
  if not ir.caps then
    vim.notify("[ltos:lint] IR missing required field: caps", vim.log.levels.WARN)
    return {}
  end

  local by_ft = { text = { "typos" } }

  for _, cap in pairs(ir.caps) do
    if cap.linters then
      for ft, lnts in pairs(cap.linters) do
        if by_ft[ft] then
          vim.list_extend(by_ft[ft], lnts)
        else
          by_ft[ft] = vim.deepcopy(lnts)
        end
      end
    end
  end

  return {
    {
      "mfussenegger/nvim-lint",
      opts = {
        events = { "BufWritePost", "BufReadPost", "InsertLeave" },
        linters_by_ft = by_ft,
        linters = {},
      },
      _source = "ltos:lint",
    },
  }
end

return M
