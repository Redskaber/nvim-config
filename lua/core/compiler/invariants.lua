-- lua/core/compiler/invariants.lua
-- P4: Architectural invariants runtime checks.

local M = {}

local ir_mod = require("core.compiler.ir")

local _enabled = false

--- Enable invariants checks.
function M.enable() _enabled = true end

--- Disable invariants checks.
function M.disable() _enabled = false end

--- Check if invariants are enabled.
---@return boolean
function M.is_enabled() return _enabled end

--- Assert that the IR stage transition is forward-only (INV-6).
---@param from_stage string
---@param to_stage string
---@param context string
function M.assert_stage_forward(from_stage, to_stage, context)
  if not _enabled then
    return
  end
  -- Simple check: stages should generally progress from AST to SPEC.
  -- This could be more sophisticated with a defined stage order.
  local stage_order = { "AST", "HIR", "MIR", "LIR", "SPEC" }
  local from_idx, to_idx
  for i, stage in ipairs(stage_order) do
    if stage == from_stage then
      from_idx = i
    end
    if stage == to_stage then
      to_idx = i
    end
  end

  if from_idx and to_idx and to_idx < from_idx then
    error(
      string.format(
        "Invariant VIOLATION (INV-6): Stage transition backwards: %s -> %s in %s",
        from_stage,
        to_stage,
        context
      ),
      2
    )
  end
end

--- Assert IR shape for LIR (INV-1).
---@param ir IR
---@param context string
function M.assert_ir_shape(ir, context)
  if not _enabled then
    return
  end
  if ir.stage == ir_mod.STAGES.LIR then
    if not ir.caps or not ir.resolved or not ir.merged_lsp or not ir.all_parsers then
      error(
        string.format("Invariant VIOLATION (INV-1): LIR missing required fields in %s", context),
        2
      )
    end
  end
end

--- Check that a phase output a new IR table (INV-1).
---@param ir_in IR
---@param ir_out IR
---@param phase_name string
function M.check_phase_output(ir_in, ir_out, phase_name)
  if not _enabled then
    return
  end
  if ir_in == ir_out then
    error(
      string.format(
        "Invariant VIOLATION (INV-1): Phase '%s' returned the same IR table (must be COW)",
        phase_name
      ),
      2
    )
  end
end

--- Assert strategy shape (INV-4).
---@param strategy table
---@param context string
function M.assert_strategy_shape(strategy, context)
  if not _enabled then
    return
  end
  if
    type(strategy) ~= "table"
    or not strategy.name
    or not strategy.resolve
    or not strategy.priority
  then
    error(string.format("Invariant VIOLATION (INV-4): Invalid strategy shape in %s", context), 2)
  end
end

return M
