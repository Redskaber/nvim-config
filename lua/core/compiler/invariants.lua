-- lua/core/compiler/invariants.lua
-- P4: Architectural invariants runtime checks.
--
-- Note: Runtime invariant checking is currently limited to INV-1 (COW
-- identity) via `check_phase_output`; other invariants (INV-4 strategy
-- shape, INV-6 stage forward-only, INV-1 LIR field shape) are statically
-- enforced by `check_layer_boundaries.sh`.

local M = {}

local _enabled = false

--- Enable invariants checks.
function M.enable() _enabled = true end

--- Disable invariants checks.
function M.disable() _enabled = false end

--- Check if invariants are enabled.
---@return boolean
function M.is_enabled() return _enabled end

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

return M