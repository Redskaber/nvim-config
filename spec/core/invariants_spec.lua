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

  R.describe("enable/disable", function()
    R.it("starts disabled", function()
      R.assert_false(inv.is_enabled())
    end)

    R.it("enable() sets flag", function()
      inv.enable()
      R.assert_true(inv.is_enabled())
    end)

    R.it("disable() clears flag", function()
      inv.enable()
      inv.disable()
      R.assert_false(inv.is_enabled())
    end)
  end)

  R.describe("assert_stage_forward (INV-6)", function()
    R.it("no-op when disabled", function()
      inv.disable()
      inv.assert_stage_forward("SPEC", "AST", "ctx") -- would throw if enabled
    end)

    R.it("passes for valid forward transition", function()
      inv.enable()
      inv.assert_stage_forward("AST", "HIR", "ctx")
      inv.assert_stage_forward("HIR", "MIR", "ctx")
    end)

    R.it("throws for regression", function()
      inv.enable()
      R.assert_false(pcall(inv.assert_stage_forward, "HIR", "AST", "ctx"))
      R.assert_false(pcall(inv.assert_stage_forward, "SPEC", "LIR", "ctx"))
    end)
  end)

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
  end)

  R.describe("check_phase_output (INV-1 COW)", function()
    R.it("throws when same IR table returned", function()
      inv.enable()
      local ir = ir_mod.new({}, "full")
      R.assert_false(pcall(inv.check_phase_output, ir, ir, "phase"))
    end)

    R.it("passes for valid COW output", function()
      inv.enable()
      local ir_in = ir_mod.new({}, "full")
      local ir_out = ir_mod.with(ir_in, { stage = "HIR" })
      inv.check_phase_output(ir_in, ir_out, "phase")
    end)
  end)

  R.describe("assert_strategy_shape (INV-4)", function()
    R.it("passes for valid strategy", function()
      inv.enable()
      inv.assert_strategy_shape({
        name = "s",
        resolve = function()
          return {}
        end,
        priority = 50,
      }, "ctx")
    end)

    R.it("throws for missing resolve", function()
      inv.enable()
      R.assert_false(pcall(inv.assert_strategy_shape, { name = "s", priority = 50 }, "ctx"))
    end)
  end)
end)
