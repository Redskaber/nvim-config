-- spec/core/pass_spec.lua
-- core.compiler.pass: Phase interface + protected execution.

local R = require("spec._runner")

R.describe("core.compiler.pass", function()
  local pass_mod = require("core.compiler.pass")
  local ir_mod = require("core.compiler.ir")
  local F = require("spec._fixtures.ir")

  local function identity_phase()
    return {
      name = "identity",
      input_state = "idle",
      output_state = "collecting",
      run = function(ir)
        return ir_mod.clone(ir)
      end,
    }
  end

  -- ── assert_valid ──────────────────────────────────────────────────────────
  R.describe("assert_valid()", function()
    R.it("accepts well-formed phase", function()
      pass_mod.assert_valid(identity_phase())
    end)
    R.it("rejects phase without name", function()
      local p = identity_phase()
      p.name = nil
      R.assert_false(pcall(pass_mod.assert_valid, p))
    end)
    R.it("rejects phase without run", function()
      local p = identity_phase()
      p.run = nil
      R.assert_false(pcall(pass_mod.assert_valid, p))
    end)
    R.it("rejects non-function validate", function()
      local p = identity_phase()
      p.validate = "bad"
      R.assert_false(pcall(pass_mod.assert_valid, p))
    end)
    R.it("rejects non-function output_validate", function()
      local p = identity_phase()
      p.output_validate = "bad"
      R.assert_false(pcall(pass_mod.assert_valid, p))
    end)
  end)

  -- ── run_phase ─────────────────────────────────────────────────────────────
  R.describe("run_phase()", function()
    R.it("identity pass returns same IR content", function()
      local ir = F.ast({ python = {} })
      local result, errs = pass_mod.run_phase(identity_phase(), ir)
      R.assert_eq(#errs, 0)
      R.assert_not_nil(result.caps.python)
    end)

    R.it("COW pass adds field without mutating input", function()
      local adder = {
        name = "adder",
        input_state = "idle",
        output_state = "collecting",
        run = function(ir)
          return ir_mod.with(ir, { resolved = { lsp = {}, tools = {} } })
        end,
      }
      local ir = F.ast()
      local result, _ = pass_mod.run_phase(adder, ir)
      R.assert_not_nil(result.resolved)
      R.assert_nil(ir.resolved)
    end)

    R.it("run error → Diagnostic appended (no crash)", function()
      local broken = {
        name = "broken",
        input_state = "idle",
        output_state = "collecting",
        run = function(_)
          error("exploded")
        end,
      }
      local ir = F.ast()
      local result, errs = pass_mod.run_phase(broken, ir)
      R.assert_eq(#errs, 1)
      R.assert_match(errs[1].message, "exploded")
      R.assert_eq(#result.diagnostics, 1)
    end)

    R.it("validate failure blocks run, appends diag", function()
      local ran = false
      local blocked = {
        name = "blocked",
        input_state = "idle",
        output_state = "collecting",
        validate = function(_)
          return { ir_mod.diag("blocked", "pre", "precondition failed") }
        end,
        run = function(ir)
          ran = true
          return ir
        end,
      }
      local _, errs = pass_mod.run_phase(blocked, F.ast())
      R.assert_false(ran)
      R.assert_eq(#errs, 1)
    end)

    R.it("output_validate failures are non-fatal warn diags (P6-D2)", function()
      local phase = {
        name = "test_post",
        input_state = "idle",
        output_state = "collecting",
        run = function(ir)
          return ir_mod.clone(ir)
        end,
        output_validate = function(_)
          return { ir_mod.diag("test_post", "output", "post failed", "error") }
        end,
      }
      local result, errs = pass_mod.run_phase(phase, ir_mod.new({}, "full"))
      R.assert_eq(#errs, 0, "output_validate failures must not be phase errors")
      local has_warn = false
      for _, d in ipairs(result.diagnostics) do
        if d.severity == "warn" and (d.message or ""):find("post-condition") then
          has_warn = true
          break
        end
      end
      R.assert_true(has_warn)
    end)
  end)

  -- ── run_with_ctx ──────────────────────────────────────────────────────────
  R.describe("run_with_ctx()", function()
    R.it("returns updated CompilerContext", function()
      local adder = {
        name = "ctx_adder",
        input_state = "idle",
        output_state = "collecting",
        run = function(ir)
          return ir_mod.with(ir, { resolved = { lsp = {}, tools = {} } })
        end,
      }
      local ir = F.ast()
      local ctx = ir_mod.ctx(ir, "idle", "test-key")
      local nctx = pass_mod.run_with_ctx(adder, ctx)
      R.assert_not_nil(nctx.ir.resolved)
      R.assert_eq(nctx.run_id, ctx.run_id)
    end)

    R.it("timings are recorded per phase", function()
      local phase = {
        name = "timed",
        input_state = "idle",
        output_state = "collecting",
        run = function(ir)
          return ir_mod.clone(ir)
        end,
      }
      local nctx = pass_mod.run_with_ctx(phase, ir_mod.ctx(F.ast(), "idle", ""))
      R.assert_type(nctx.timings["timed"], "number")
      R.assert_true(nctx.timings["timed"] >= 0)
    end)

    R.it("diagnostics from phase are merged into ctx", function()
      local failing = {
        name = "ctx_fail",
        input_state = "idle",
        output_state = "collecting",
        run = function(_)
          error("ctx error")
        end,
      }
      local nctx = pass_mod.run_with_ctx(failing, ir_mod.ctx(F.ast(), "idle", ""))
      R.assert_true(#nctx.diagnostics > 0)
      R.assert_eq(nctx.diagnostics[1].stage, "ctx_fail")
    end)
  end)
end)
