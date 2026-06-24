-- ~/.config/nvim/lua/runtime/adapters/lint.lua
-- Backend layer: IR → nvim-lint LazySpec.
-- Builds linters_by_ft from IR.caps.

local M = {}

---@param ir table
---@return table[]
function M.build(ir)
  if not ir.caps then
    return { { _ltos_error = "[ltos:lint] IR missing required field: caps" } }
  end

  -- Merge all linter maps: { [ft]: string[] }
  local linters_by_ft = {}

  for _, cap in pairs(ir.caps) do
    if cap.linters then
      for ft, linters in pairs(cap.linters) do
        if not linters_by_ft[ft] then
          linters_by_ft[ft] = {}
        end
        for _, linter in ipairs(linters) do
          if type(linter) == "string" then
            linters_by_ft[ft][#linters_by_ft[ft] + 1] = linter
          end
        end
      end
    end
  end

  return {
    {
      "mfussenegger/nvim-lint",
      _source = "ltos:lint",
      opts = function(_, opts)
        opts.linters_by_ft = opts.linters_by_ft or {}
        for ft, linters in pairs(linters_by_ft) do
          if not opts.linters_by_ft[ft] then
            opts.linters_by_ft[ft] = linters
          else
            local seen = {}
            for _, l in ipairs(opts.linters_by_ft[ft]) do
              seen[l] = true
            end
            for _, l in ipairs(linters) do
              if not seen[l] then
                opts.linters_by_ft[ft][#opts.linters_by_ft[ft] + 1] = l
                seen[l] = true
              end
            end
          end
        end
        return opts
      end,
    },
  }
end

return M
