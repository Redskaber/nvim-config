-- spec/core/invariants_spec.lua
-- core.compiler.invariants: architectural invariant runtime checks.

local R = require("spec._runner")

R.describe("core.compiler.invariants", function()
  local inv = require("core.compiler.invariants")
  local ir_mod = require("core.compiler.ir")

  R.before_each(function() inv.disable() end)
  R.after_each(function() inv.disable() end)

  -- ── enable / disable ──────────────────────────────────────────────────────

  R.describe("enable / disable", function()
    R.it("starts disabled", function() R.assert_false(inv.is_enabled()) end)
    R.it("enable() activates flag", function()
      inv.enable()
      R.assert_true(inv.is_enabled())
    end)
    R.it("disable() clears flag", function()
      inv.enable()
      inv.disable()
      R.assert_false(inv.is_enabled())
    end)
  end)

  -- ── INV-1: check_phase_output (COW) ───────────────────────────────────────

  R.describe("check_phase_output (INV-1 COW)", function()
    R.it("throws when same IR table returned (mutation violation)", function()
      inv.enable()
      local i = ir_mod.new({}, "full")
      R.assert_false(pcall(inv.check_phase_output, i, i, "phase"))
    end)
    R.it("passes for valid COW output (distinct tables)", function()
      inv.enable()
      local ir_in = ir_mod.new({}, "full")
      local ir_out = ir_mod.with(ir_in, { stage = "HIR" })
      inv.check_phase_output(ir_in, ir_out, "phase")
    end)
  end)

  -- ── integration: pass.run_phase respects invariants ───────────────────────

  R.describe("run_phase integration", function()
    R.it("pass returning same IR table triggers invariant error", function()
      inv.enable()
      local pass_mod = require("core.compiler.pass")
      local mutating_phase = {
        name = "mutating",
        input_state = "idle",
        output_state = "collecting",
        run = function(i) return i end, -- violation: same table
      }
      local ir = ir_mod.new({}, "full")
      local ok = pcall(pass_mod.run_phase, mutating_phase, ir)
      R.assert_false(ok, "invariant check must catch same-table COW violation")
    end)
  end)
end)