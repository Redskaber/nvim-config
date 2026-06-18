-- spec/core/invariants_spec.lua
-- core.compiler.invariants: architectural invariant runtime checks.

local R = require("spec._runner")

R.describe("core.compiler.invariants", function()
  local inv = require("core.compiler.invariants")
  local ir_mod = require("core.compiler.ir")

  R.before_each(function()
    inv.disable()
  end)
  R.after_each(function()
    inv.disable()
  end)

  -- ── enable / disable ──────────────────────────────────────────────────────

  R.describe("enable / disable", function()
    R.it("starts disabled", function()
      R.assert_false(inv.is_enabled())
    end)
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

  -- ── INV-6: assert_stage_forward ───────────────────────────────────────────

  R.describe("assert_stage_forward (INV-6)", function()
    R.it("no-op when disabled — regression passes silently", function()
      inv.disable()
      inv.assert_stage_forward("SPEC", "AST", "ctx") -- would throw if enabled
    end)
    R.it("passes for valid forward transitions", function()
      inv.enable()
      inv.assert_stage_forward("AST", "HIR", "ctx")
      inv.assert_stage_forward("HIR", "MIR", "ctx")
      inv.assert_stage_forward("MIR", "LIR", "ctx")
      inv.assert_stage_forward("LIR", "SPEC", "ctx")
    end)
    R.it("throws for HIR → AST regression", function()
      inv.enable()
      R.assert_false(pcall(inv.assert_stage_forward, "HIR", "AST", "ctx"))
    end)
    R.it("throws for SPEC → LIR regression", function()
      inv.enable()
      R.assert_false(pcall(inv.assert_stage_forward, "SPEC", "LIR", "ctx"))
    end)
  end)

  -- ── INV-1: assert_ir_shape (LIR guard) ────────────────────────────────────

  R.describe("assert_ir_shape (INV-1 LIR guard)", function()
    R.it("no-op when disabled", function()
      inv.disable()
      inv.assert_ir_shape({ stage = "LIR" }, "ctx")
    end)
    R.it("throws when LIR missing required fields", function()
      inv.enable()
      R.assert_false(pcall(inv.assert_ir_shape, { stage = "LIR" }, "ctx"))
    end)
    R.it("passes for well-formed LIR", function()
      inv.enable()
      inv.assert_ir_shape({
        stage = "LIR",
        caps = {},
        resolved = {},
        merged_lsp = {},
        all_parsers = {},
      }, "ctx")
    end)
    R.it("non-LIR stage passes trivially", function()
      inv.enable()
      inv.assert_ir_shape({ stage = "AST" }, "ctx")
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

  -- ── INV-4: assert_strategy_shape ──────────────────────────────────────────

  R.describe("assert_strategy_shape (INV-4)", function()
    R.it("passes for valid strategy table", function()
      inv.enable()
      inv.assert_strategy_shape({
        name = "strat",
        resolve = function()
          return {}
        end,
        priority = 50,
      }, "ctx")
    end)
    R.it("throws for missing resolve function", function()
      inv.enable()
      R.assert_false(pcall(inv.assert_strategy_shape, { name = "s", priority = 50 }, "ctx"))
    end)
    R.it("throws for missing name", function()
      inv.enable()
      R.assert_false(pcall(inv.assert_strategy_shape, { resolve = function() end, priority = 50 }, "ctx"))
    end)
    R.it("no-op when disabled", function()
      inv.disable()
      inv.assert_strategy_shape({}, "ctx") -- would throw if enabled
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
        run = function(i)
          return i
        end, -- violation: same table
      }
      local ir = ir_mod.new({}, "full")
      local ok = pcall(pass_mod.run_phase, mutating_phase, ir)
      R.assert_false(ok, "invariant check must catch same-table COW violation")
    end)
  end)
end)
