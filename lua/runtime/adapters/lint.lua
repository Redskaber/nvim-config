-- ~/.config/nvim/lua/runtime/adapters/lint.lua
-- Pure function: ctx → nvim-lint spec.

local M = {}

---@param ctx table
---@return table[]
function M.build(ctx)
  local by_ft = { text = { "typos" } }

  for _, cap in pairs(ctx.caps) do
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
    },
  }
end

return M
