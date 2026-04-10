-- ~/.config/nvim/lua/runtime/adapters/lint.lua
-- Builds nvim-lint linters_by_ft from capability declarations.

local M = {}

---@param caps table<string, Capability>
---@return table[]
function M.build(caps)
  local by_ft = { text = { "typos" } }

  for _, cap in pairs(caps) do
    if cap.linters then
      for ft, lnts in pairs(cap.linters) do
        if by_ft[ft] then
          for _, l in ipairs(lnts) do
            by_ft[ft][#by_ft[ft] + 1] = l
          end
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
