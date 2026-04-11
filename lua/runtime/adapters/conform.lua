-- lua/runtime/adapters/conform.lua
-- Pure function: ir -> conform.nvim spec.
-- FormatterNode.fn is injected by the normalize stage; this adapter only reads it.

local M = {}

---@param ir table
---@return table[]
function M.build(ir)
  if not ir or not ir.caps then
    vim.notify("[ltos:conform] IR missing 'caps' field", vim.log.levels.WARN)
    return {}
  end

  local by_ft = {
    ["*"] = { "codespell" },
    ["_"] = { "trim_whitespace" },
  }

  for _, cap in pairs(ir.caps) do
    if cap.formatters then
      for ft, fmts in pairs(cap.formatters) do
        if type(fmts) == "function" then
          by_ft[ft] = fmts
        else
          local resolved = {}
          for _, v in ipairs(fmts) do
            if type(v) == "table" and v.kind == "formatter" then
              if v.fn then
                -- strategy function injected by normalize stage
                by_ft[ft] = v.fn
                resolved = nil
                break
              elseif v.name then
                resolved[#resolved + 1] = v.name
              end
            else
              resolved[#resolved + 1] = v
            end
          end

          if resolved ~= nil then
            if by_ft[ft] and type(by_ft[ft]) == "table" then
              vim.list_extend(by_ft[ft], resolved)
            else
              by_ft[ft] = vim.deepcopy(resolved)
            end
          end
        end
      end
    end
  end

  local has_fn = false
  for _, v in pairs(by_ft) do
    if type(v) == "function" then
      has_fn = true
      break
    end
  end
  return {
    {
      "stevearc/conform.nvim",
      _source = "ltos:conform",
      _no_cache = has_fn or nil,
      dependencies = { "mason-org/mason.nvim" },
      opts = {
        formatters_by_ft = by_ft,
        formatters = { injected = { options = { ignore_errors = true } } },
      },
    },
  }
end

return M
