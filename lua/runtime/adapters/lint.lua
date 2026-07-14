-- ~/.config/nvim/lua/runtime/adapters/lint.lua
-- Backend layer: IR → nvim-lint LazySpec.
-- Builds linters_by_ft from IR.caps.
--
-- FIX-TEST-BUG (2026-06-26): opts is now a STATIC table, not a lazy function.
-- Tests index `spec.opts.linters_by_ft` directly. lazy.nvim still merges
-- static `opts = { ... }` with other specs' opts for the same plugin, so the
-- merge behaviour is preserved.

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
            -- de-dup within a filetype so multiple lang modules
            -- contributing the same linter do not produce duplicates.
            local seen = false
            for _, existing in ipairs(linters_by_ft[ft]) do
              if existing == linter then
                seen = true
                break
              end
            end
            if not seen then
              linters_by_ft[ft][#linters_by_ft[ft] + 1] = linter
            end
          end
        end
      end
    end
  end

  return {
    {
      "mfussenegger/nvim-lint",
      _source = "ltos:lint",
      opts = { linters_by_ft = linters_by_ft },
    },
  }
end

return M