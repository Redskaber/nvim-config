-- lua/core/compiler/pass.lua
-- Phase interface + protected execution.
-- REFACTOR: assert_valid checks contracts at load time.
-- debug mode: input IR is frozen via util.freeze to catch accidental mutation.
-- TODO-2.2: run_with_ctx() provides the ctx-based execution path (forward-compat).

local ir_mod = require("core.compiler.ir")
local util = require("core.kernel.util")
local invariants = require("core.compiler.invariants")

local M = {}

---@class Phase
---@field name              string
---@field input_state       string
---@field output_state      string
---@field run               fun(ir: IR): IR
---@field validate?         fun(ir: IR): Diagnostic[]   pre-condition (input)
---@field output_validate?  fun(ir: IR): Diagnostic[]   post-condition (output)  P6-D2

local REQUIRED_FIELDS = { "name", "input_state", "output_state", "run" }

--- Validate a Phase definition at load time (fail loud).
---@param phase Phase
function M.assert_valid(phase)
  assert(type(phase) == "table", "Phase must be a table")
  for _, f in ipairs(REQUIRED_FIELDS) do
    assert(phase[f] ~= nil, ("Phase missing required field: %q"):format(f))
  end
  assert(type(phase.run) == "function", "Phase.run must be a function")
  if phase.validate ~= nil then
    assert(type(phase.validate) == "function", "Phase.validate must be a function")
  end
  -- P6-D2: output_validate is optional but must be a function if present
  if phase.output_validate ~= nil then
    assert(type(phase.output_validate) == "function", "Phase.output_validate must be a function")
  end
end

M.assert_valid_pass = M.assert_valid

--- Execute a phase with pre-condition validation and pcall protection.
--- In debug mode, input IR is frozen to catch accidental mutation.
--- P6-D2: Also runs output_validate hook after successful phase execution.
---@param phase Phase
---@param ir    IR
---@return IR, Diagnostic[]
function M.run_phase(phase, ir)
  -- Debug mode: freeze input so any mutation attempt raises immediately
  local safe_ir = _G._ltos_debug_freeze and util.freeze(ir, phase.name) or ir

  -- ── Pre-condition validation ─────────────────────────────────────────────
  local pre_diags = {}
  if phase.validate then
    local ok, result = pcall(phase.validate, safe_ir)
    if not ok then
      pre_diags[#pre_diags + 1] = ir_mod.diag(phase.name, "validate", tostring(result))
    elseif type(result) == "table" then
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

  -- ── Execute phase ────────────────────────────────────────────────────────
  local ok, next_ir = pcall(phase.run, safe_ir)
  if not ok then
    local d = ir_mod.diag(phase.name, "run", tostring(next_ir))
    return ir_mod.append_diag(ir, d), { d }
  end
  if type(next_ir) ~= "table" then
    local d = ir_mod.diag(phase.name, "run", "Phase.run returned " .. type(next_ir) .. " instead of IR table")
    return ir_mod.append_diag(ir, d), { d }
  end

  if invariants.is_enabled() then
    invariants.check_phase_output(ir, next_ir, phase.name)
  end

  -- ── Post-condition validation (P6-D2) ────────────────────────────────────
  local post_diags = {}
  if phase.output_validate then
    local ok2, result2 = pcall(phase.output_validate, next_ir)
    if not ok2 then
      post_diags[#post_diags + 1] = ir_mod.diag(phase.name, "output_validate", tostring(result2))
    elseif type(result2) == "table" then
      for _, d in ipairs(result2) do
        post_diags[#post_diags + 1] = d
      end
    end
  end

  -- Post-condition failures are non-fatal: append as warn diagnostics and continue.
  -- Fatal would block downstream; warn preserves pipeline liveness (pipeline-is-additive).
  if #post_diags > 0 then
    for _, d in ipairs(post_diags) do
      -- Downgrade to warn if caller set severity=error on post-conditions
      local warn_d = ir_mod.diag(phase.name, d.node or "output", "[post-condition] " .. (d.message or "?"), "warn")
      next_ir = ir_mod.append_diag(next_ir, warn_d)
    end
  end
  return next_ir, {}
end

--- Execute a phase via CompilerContext (TODO-2.2 forward-compat path).
--- Wraps run_phase(); ctx.ir is updated in-place on the returned ctx.
--- When phases are migrated to run(ctx)->ctx, this becomes the primary path.
---@param phase Phase
---@param ctx   CompilerContext
---@return CompilerContext
function M.run_with_ctx(phase, ctx)
  local t0 = os.clock()
  local next_ir, diags = M.run_phase(phase, ctx.ir)
  local elapsed = os.clock() - t0

  -- Merge diagnostics into ctx
  local new_diags = {}
  for _, d in ipairs(ctx.diagnostics) do
    new_diags[#new_diags + 1] = d
  end
  for _, d in ipairs(diags) do
    new_diags[#new_diags + 1] = d
  end

  -- Update timings
  local new_timings = {}
  for k, v in pairs(ctx.timings) do
    new_timings[k] = v
  end
  new_timings[phase.name] = elapsed

  return {
    ir = next_ir,
    stage = next_ir.stage,
    diagnostics = new_diags,
    cache_key = ctx.cache_key,
    timings = new_timings,
    run_id = ctx.run_id,
  }
end
M.run_pass = M.run_phase

return M
