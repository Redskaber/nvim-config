-- lua/core/compiler/pass.lua
-- Layer 1 compiler: standard Phase/Pass interface.
--
-- A Phase is a table with:
--   name         : string              — unique identifier
--   input_state  : string              — state machine state required on entry
--   output_state : string              — state machine state set on success
--   validate?    : (IR) -> Diagnostic[]   — pre-condition check (nil = skip)
--   run          : (IR) -> IR             — pure transformation; returns NEW IR
--
-- run() is guaranteed to:
--   • Never mutate its input IR
--   • Return a table (IR) or throw — never return nil
--   • Be wrapped in pcall so errors become Diagnostics, not panics

local ir_mod = require("core.compiler.ir")

local M = {}

---@class Phase
---@field name         string
---@field input_state  string
---@field output_state string
---@field run          fun(ir: IR): IR
---@field validate?    fun(ir: IR): Diagnostic[]|nil

--- Assert that a table satisfies the Phase interface. Throws on failure.
---@param p any
function M.assert_valid(p)
  assert(type(p) == "table", "Phase must be a table, got " .. type(p))
  assert(type(p.name) == "string", "Phase.name must be a string")
  assert(type(p.run) == "function", "Phase.run must be a function")
  assert(type(p.input_state) == "string", "Phase.input_state must be a string")
  assert(type(p.output_state) == "string", "Phase.output_state must be a string")
  if p.validate ~= nil then
    assert(type(p.validate) == "function", "Phase.validate must be a function or nil")
  end
end

--- Run a single Phase with pre-condition validation.
--- Returns (new_ir, Diagnostic[]).  Input IR is never mutated.
---@param phase Phase
---@param ir    IR
---@return IR, Diagnostic[]
function M.run_phase(phase, ir)
  -- 1. Pre-condition validation
  local pre_diags = {}
  if phase.validate then
    local ok, result = pcall(phase.validate, ir)
    if not ok then
      pre_diags[#pre_diags + 1] = ir_mod.diag(phase.name, "validate", tostring(result))
    elseif type(result) == "table" then
      -- Pure Lua extend (no vim API in Layer 1)
      for _, d in ipairs(result) do
        pre_diags[#pre_diags + 1] = d
      end
    end
  end

  if #pre_diags > 0 then
    local acc = ir
    for _, d in ipairs(pre_diags) do
      acc = ir_mod.append_diag(acc, d)
    end
    return acc, pre_diags
  end

  -- 2. Execute transformation (protected)
  local ok, next_ir = pcall(phase.run, ir)
  if not ok then
    local d = ir_mod.diag(phase.name, "run", tostring(next_ir))
    return ir_mod.append_diag(ir, d), { d }
  end

  if type(next_ir) ~= "table" then
    local d = ir_mod.diag(phase.name, "run", "Phase.run returned " .. type(next_ir) .. " instead of IR table")
    return ir_mod.append_diag(ir, d), { d }
  end

  return next_ir, {}
end

-- Backward-compat aliases
M.run_pass = M.run_phase
M.assert_valid_pass = M.assert_valid

return M
