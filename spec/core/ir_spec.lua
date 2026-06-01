-- spec/core/ir_spec.lua
-- IR value type: immutability, COW, stage transitions, diagnostics, diff.

local R = require("spec._runner")

R.describe("core.compiler.ir", function()
  local ir_mod = require("core.compiler.ir")
  local F = require("spec._fixtures.ir")
  local ver = require("core.compiler.cache.version")

  -- ── ir.new() ───────────────────────────────────────────────────────────────

  R.describe("new()", function()
    R.it("produces correct initial shape", function()
      local ir = ir_mod.new({ "a", "b" }, "minimal")
      R.assert_type(ir.caps, "table")
      R.assert_type(ir.diagnostics, "table")
      R.assert_eq(#ir.diagnostics, 0)
      R.assert_eq(ir.profile, "minimal")
      R.assert_eq(ir.meta.lang_modules[1], "a")
    end)

    R.it("embeds ir_version = SCHEMA_VERSION in meta (P6-C4)", function()
      local ir = ir_mod.new({}, "full")
      R.assert_type(ir.meta.ir_version, "number")
      R.assert_eq(ir.meta.ir_version, ver.SCHEMA_VERSION)
    end)

    R.it("initialises ext_caps with all known cap_type buckets", function()
      local cap_types = require("core.domain.cap_types")
      local ir = ir_mod.new({}, "full")
      R.assert_type(ir.ext_caps, "table")
      for _, ct in ipairs(cap_types.ALL) do
        R.assert_type(ir.ext_caps[ct], "table", "ext_caps." .. ct .. " must be a table")
        R.assert_true(next(ir.ext_caps[ct]) == nil, "ext_caps." .. ct .. " must be empty initially")
      end
    end)

    R.it("initialises cap_specs as empty table", function()
      local ir = ir_mod.new({}, "full")
      R.assert_type(ir.cap_specs, "table")
      R.assert_true(next(ir.cap_specs) == nil)
    end)
  end)

  -- ── ir.clone() ─────────────────────────────────────────────────────────────

  R.describe("clone()", function()
    R.it("produces deep-independent copy", function()
      local ir = ir_mod.new({ "mod" }, "full")
      ir.caps = { python = { lsp = { pyright = {} } } }
      local copy = ir_mod.clone(ir)
      copy.caps.python.lsp.pyright.settings = { injected = true }
      R.assert_nil(ir.caps.python.lsp.pyright.settings)
    end)
  end)

  -- ── ir.with() ──────────────────────────────────────────────────────────────

  R.describe("with()", function()
    R.it("patches fields without touching others", function()
      local ir = ir_mod.new({ "m" }, "full")
      ir.caps = { lua = {} }
      local next_ir = ir_mod.with(ir, { resolved = { lsp = {}, tools = {} } })
      R.assert_not_nil(next_ir.resolved)
      R.assert_eq(next_ir.caps, ir.caps)
      R.assert_nil(ir.resolved)
    end)

    R.it("returns a new table (COW)", function()
      local ir = ir_mod.new({}, "full")
      local next_ir = ir_mod.with(ir, { stage = "HIR" })
      R.assert_ne(next_ir, ir)
    end)
  end)

  -- ── ir.append_diag() ───────────────────────────────────────────────────────

  R.describe("append_diag()", function()
    R.it("returns new IR; original unchanged", function()
      local ir = ir_mod.new({}, "full")
      local d = ir_mod.diag("collect", "mod.x", "failed to load")
      local next_ir = ir_mod.append_diag(ir, d)
      R.assert_eq(#ir.diagnostics, 0)
      R.assert_eq(#next_ir.diagnostics, 1)
      R.assert_eq(next_ir.diagnostics[1].stage, "collect")
    end)

    R.it("backward compat: append_error alias works", function()
      local ir = ir_mod.new({}, "full")
      local d = ir_mod.error("normalize", "python", "unknown strategy")
      local n = ir_mod.append_error(ir, d)
      R.assert_eq(#n.diagnostics, 1)
    end)
  end)

  -- ── ir.diag() ──────────────────────────────────────────────────────────────

  R.describe("diag()", function()
    R.it("produces Diagnostic with all fields including code", function()
      local d = ir_mod.diag("normalize", "python", "unknown strategy", "warn")
      R.assert_eq(d.stage, "normalize")
      R.assert_eq(d.node, "python")
      R.assert_eq(d.message, "unknown strategy")
      R.assert_eq(d.severity, "warn")
      R.assert_type(d.code, "string")
      R.assert_true(#d.code > 0)
      R.assert_match(d.code, "^[WEI]%x+")
    end)

    R.it("is deterministic (same input → same code)", function()
      local d1 = ir_mod.diag("collect", "mod.a", "same message", "error")
      local d2 = ir_mod.diag("collect", "mod.a", "same message", "error")
      R.assert_eq(d1.code, d2.code)
    end)
  end)

  -- ── ir.validate() ──────────────────────────────────────────────────────────

  R.describe("validate()", function()
    R.it("passes when required fields present for 'normalize'", function()
      local ir = F.ast({})
      local errs = ir_mod.validate(ir, "normalize")
      R.assert_eq(#errs, 0)
    end)

    R.it("returns Diagnostic for missing required field", function()
      local ir = F.ast({})
      ir.resolved = nil
      local errs = ir_mod.validate(ir, "optimize")
      R.assert_true(#errs > 0)
      R.assert_match(errs[1].message, "resolved")
    end)

    R.it("returns error for unknown stage", function()
      local ir = F.ast({})
      local errs = ir_mod.validate(ir, "nonexistent")
      R.assert_eq(#errs, 1)
      R.assert_match(errs[1].message, "unknown stage")
    end)
  end)

  -- ── ir.diag_counts() ───────────────────────────────────────────────────────

  R.describe("diag_counts()", function()
    R.it("counts errors and warns correctly", function()
      local ir = ir_mod.new({}, "full")
      ir = ir_mod.append_diag(ir, ir_mod.diag("s", "n", "e1", "error"))
      ir = ir_mod.append_diag(ir, ir_mod.diag("s", "n", "w1", "warn"))
      ir = ir_mod.append_diag(ir, ir_mod.diag("s", "n", "e2", "error"))
      local c = ir_mod.diag_counts(ir)
      R.assert_eq(c.errors, 2)
      R.assert_eq(c.warns, 1)
    end)
  end)

  -- ── ir.transition() ────────────────────────────────────────────────────────

  R.describe("transition()", function()
    R.it("advances AST → HIR → MIR → LIR → SPEC", function()
      local ir = ir_mod.new({}, "full")
      R.assert_eq(ir.stage, "AST")
      ir = ir_mod.transition(ir)
      R.assert_eq(ir.stage, "HIR")
      ir = ir_mod.transition(ir)
      R.assert_eq(ir.stage, "MIR")
      ir = ir_mod.transition(ir)
      R.assert_eq(ir.stage, "LIR")
      ir = ir_mod.transition(ir)
      R.assert_eq(ir.stage, "SPEC")
    end)

    R.it("throws on illegal transition from SPEC", function()
      local ir = ir_mod.with(ir_mod.new({}, "full"), { stage = "SPEC" })
      R.assert_false(pcall(ir_mod.transition, ir))
    end)

    R.it("does not mutate input IR", function()
      local ir = ir_mod.new({}, "full")
      ir_mod.transition(ir)
      R.assert_eq(ir.stage, "AST")
    end)
  end)

  -- ── ir.assert_stage() ──────────────────────────────────────────────────────

  R.describe("assert_stage()", function()
    R.it("passes when stage matches", function()
      local ir = ir_mod.new({}, "full")
      ir_mod.assert_stage(ir, "AST") -- must not throw
    end)

    R.it("throws on mismatch", function()
      local ir = ir_mod.new({}, "full")
      R.assert_false(pcall(ir_mod.assert_stage, ir, "HIR"))
    end)
  end)

  -- ── ir.ctx() ───────────────────────────────────────────────────────────────

  R.describe("ctx()", function()
    R.it("produces CompilerContext with unique run_id per call", function()
      local ir = ir_mod.new({}, "full")
      local c1 = ir_mod.ctx(ir, "s", "k")
      local c2 = ir_mod.ctx(ir, "s", "k")
      R.assert_type(c1.run_id, "string")
      R.assert_ne(c1.run_id, c2.run_id)
      R.assert_eq(c1.cache_key, "k")
    end)
  end)

  -- ── ir.diff() ──────────────────────────────────────────────────────────────

  R.describe("diff()", function()
    R.it("returns empty list for structurally identical IRs (excluding timing)", function()
      local ir = ir_mod.new({ "m" }, "full")
      local changes = ir_mod.diff(ir, ir_mod.clone(ir))
      local non_timing = {}
      for _, c in ipairs(changes) do
        if not c.path:find("started_at") then
          non_timing[#non_timing + 1] = c
        end
      end
      R.assert_eq(#non_timing, 0)
    end)

    R.it("detects stage change", function()
      local ir1 = ir_mod.new({}, "full")
      local ir2 = ir_mod.with(ir1, { stage = "HIR" })
      local changes = ir_mod.diff(ir1, ir2)
      local found = false
      for _, c in ipairs(changes) do
        if c.path:find("stage") and c.old == "AST" and c.new == "HIR" then
          found = true
          break
        end
      end
      R.assert_true(found)
    end)

    R.it("format_diff() returns '(no changes)' for empty list", function()
      R.assert_eq(ir_mod.format_diff({}), "(no changes)")
    end)
  end)
end)
