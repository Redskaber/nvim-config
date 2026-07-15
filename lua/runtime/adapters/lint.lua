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
  -- FIX-P3 (2026-07-15): O(n²) dedup → O(n) via per-ft seen-set.
  -- Previously inner-looped over linters_by_ft[ft] for each linter, which
  -- degraded quadratically as the list grew. seen_by_ft persists across caps
  -- so duplicate linters contributed by multiple lang modules for the same ft
  -- are still suppressed (preserves original cross-module dedup intent).
  local seen_by_ft = {}

  for _, cap in pairs(ir.caps) do
    if cap.linters then
      for ft, linters in pairs(cap.linters) do
        if not linters_by_ft[ft] then
          linters_by_ft[ft] = {}
          seen_by_ft[ft] = {}
        end
        local seen = seen_by_ft[ft]
        for _, linter in ipairs(linters) do
          if type(linter) == "string" and not seen[linter] then
            seen[linter] = true
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
      opts = { linters_by_ft = linters_by_ft },
    },
  }
end

return M