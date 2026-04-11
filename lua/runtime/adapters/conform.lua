-- ~/.config/nvim/lua/runtime/adapters/conform.lua
-- Codegen adapter: IR → conform.nvim LazySpec.
--
-- P0-1 compliance: raw function values are rejected at schema layer;
-- this adapter only handles strings and FormatterNode tables with .fn injected
-- by the normalize pass.  The `type(fmts) == "function"` branch is removed.

local M = {}

---@param ir table  post-optimize IR
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

  local has_fn = false

  for _, cap in pairs(ir.caps) do
    if cap.formatters then
      for ft, fmts in pairs(cap.formatters) do
        -- fmts is always a list: string | FormatterNode (schema-enforced)
        local resolved = {}
        local ft_has_fn = false

        for _, v in ipairs(fmts) do
          if type(v) == "table" and v.kind == "formatter" then
            if v.fn then
              -- Strategy function injected by normalize pass
              by_ft[ft] = v.fn
              ft_has_fn = true
              has_fn = true
              resolved = nil -- signal: ft is handled
              break
            elseif v.name then
              resolved[#resolved + 1] = v.name
            end
            -- nodes with neither fn nor name are no-ops (malformed; schema should catch)
          elseif type(v) == "string" then
            resolved[#resolved + 1] = v
          end
        end

        if not ft_has_fn and resolved ~= nil then
          if by_ft[ft] and type(by_ft[ft]) == "table" then
            vim.list_extend(by_ft[ft], resolved)
          else
            by_ft[ft] = vim.deepcopy(resolved)
          end
        end
      end
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
