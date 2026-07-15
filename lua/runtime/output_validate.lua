-- lua/runtime/output_validate.lua
-- Shared post-condition validators for pipeline phases (P6-D2).
--
-- Each phase's output_validate receives the IR AFTER the phase's run()
-- has completed, and returns a list of Diagnostic records (empty = OK).
-- Post-condition failures are non-fatal: pass.run_phase() downgrades
-- them to warn-severity diagnostics appended to the IR (see
-- core.compiler.pass run_phase()).
--
-- Design: minimal, conservative checks. We only assert what each phase
-- CONTRACTUALLY guarantees — typically:
--   1. Stage field is present and non-empty (not regressed to nil/"")
--   2. Fields required by the NEXT phase (per ir.STAGE_REQUIRED) are present
--   3. caps table is non-nil (collect sets it; downstream must preserve)
--
-- We deliberately do NOT check field VALUES (e.g. "caps must contain lua")
-- because that would couple the validator to specific module configurations
-- and produce false positives in minimal/custom profiles.

local ir_mod = require("core.compiler.ir")

local M = {}

--- Build an output_validate function that checks the given required fields
--- are present (non-nil) on the IR, and that stage is a non-empty string.
---@param required_fields? string[]  e.g. {"caps", "meta", "symbols"}
---@return fun(ir: IR): Diagnostic[]
function M.make(required_fields)
  required_fields = required_fields or {}
  return function(ir)
    local diags = {}

    -- Stage must be a non-empty string
    if type(ir.stage) ~= "string" or ir.stage == "" then
      diags[#diags + 1] = ir_mod.diag(
        "output_validate",
        "ir.stage",
        ("stage field must be non-empty string, got %s"):format(type(ir.stage)),
        "warn"
      )
    end

    -- Each required field must be present (non-nil)
    for _, field in ipairs(required_fields) do
      if ir[field] == nil then
        diags[#diags + 1] = ir_mod.diag(
          "output_validate",
          "ir." .. field,
          ("required field %q missing after phase output"):format(field),
          "warn"
        )
      end
    end

    return diags
  end
end

-- ── Per-phase validators ────────────────────────────────────────────────────
-- Each constant is a ready-to-attach output_validate function.
-- Required fields derived from core.compiler.ir.STAGE_REQUIRED (the NEXT
-- phase's input contract) — i.e. a phase's output must satisfy the next
-- phase's pre-condition, otherwise the pipeline will emit a pre-condition
-- error on the next phase.

--- collect output → must have caps + meta (normalize input contract)
M.collect = M.make({ "caps", "meta" })

--- normalize output → must have caps + meta (canonicalize input contract)
M.normalize = M.make({ "caps", "meta" })

--- canonicalize output → must have caps + meta + symbols (resolve input contract)
M.canonicalize = M.make({ "caps", "meta", "symbols" })

--- resolve output → must have caps + resolved (optimize input contract)
M.resolve = M.make({ "caps", "resolved" })

--- optimize output → must have caps + resolved + merged_lsp + all_parsers
--- (codegen input contract)
M.optimize = M.make({ "caps", "resolved", "merged_lsp", "all_parsers" })

--- collect_ext output → must have caps + meta + ext_caps
M.collect_ext = M.make({ "caps", "meta", "ext_caps" })

--- cap_resolve output → must have caps + meta + cap_specs
M.cap_resolve = M.make({ "caps", "meta", "cap_specs" })

--- codegen output → must have caps + resolved + merged_lsp + all_parsers
--- (codegen is terminal — validate it didn't drop any required field)
M.codegen = M.make({ "caps", "resolved", "merged_lsp", "all_parsers" })

return M