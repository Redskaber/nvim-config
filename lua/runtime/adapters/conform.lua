-- ~/.config/nvim/lua/runtime/adapters/conform.lua
-- Pure function: ctx → conform.nvim spec.
-- Sentinel "__ruff_or_black__" is resolved here to a dynamic function.

local M = {}

local function ruff_or_black_fn()
  return function(bufnr)
    if require("conform").get_formatter_info("ruff_format", bufnr).available then
      return { "ruff_format" }
    end
    return { "isort", "black" }
  end
end

---@param ctx table
---@return table[]
function M.build(ctx)
  local by_ft = {
    ["*"] = { "codespell" },
    ["_"] = { "trim_whitespace" },
  }

  for _, cap in pairs(ctx.caps) do
    if cap.formatters then
      for ft, fmts in pairs(cap.formatters) do
        if type(fmts) == "function" then
          -- already a resolved function (future path)
          by_ft[ft] = fmts
        elseif #fmts == 1 and fmts[1] == "__ruff_or_black__" then
          by_ft[ft] = ruff_or_black_fn()
        else
          if by_ft[ft] and type(by_ft[ft]) == "table" then
            vim.list_extend(by_ft[ft], fmts)
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
