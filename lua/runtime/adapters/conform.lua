-- ~/.config/nvim/lua/runtime/adapters/conform.lua
-- Builds conform.nvim formatters_by_ft from capability declarations.
-- Handles the Python ruff/black dynamic selection sentinel.

local M = {}

---@param caps table<string, Capability>
---@return table[]
function M.build(caps)
  local by_ft = {
    ["*"] = { "codespell" },
    ["_"] = { "trim_whitespace" },
  }

  for _, cap in pairs(caps) do
    if cap.formatters then
      for ft, fmts in pairs(cap.formatters) do
        -- Python dynamic formatter: wrap in a function
        if #fmts == 1 and fmts[1] == "__ruff_or_black__" then
          by_ft[ft] = function(bufnr)
            if require("conform").get_formatter_info("ruff_format", bufnr).available then
              return { "ruff_format" }
            end
            return { "isort", "black" }
          end
        else
          -- Merge: later declarations for the same ft are appended
          if by_ft[ft] and type(by_ft[ft]) == "table" then
            for _, f in ipairs(fmts) do
              by_ft[ft][#by_ft[ft] + 1] = f
            end
          else
            by_ft[ft] = vim.deepcopy(fmts)
          end
        end
      end
    end
  end

  return {
    {
      "stevearc/conform.nvim",
      dependencies = { "mason-org/mason.nvim" },
      opts = {
        formatters_by_ft = by_ft,
        formatters = { injected = { options = { ignore_errors = true } } },
      },
    },
  }
end

return M
