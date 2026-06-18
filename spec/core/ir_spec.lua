-- spec/core/ir_spec.lua
-- core.compiler.ir: IR value type, COW, stage transitions, diagnostics, diff.

local R = require("spec._runner")

R.describe("core.compiler.ir", function()
  local ir = require("core.compiler.ir")
  local F = require("spec._fixtures.ir")
  local ver = require("core.compiler.cache.version")

  -- ── new() ──────────────────────────────────────────────────────────────────

  R.describe("new()", function()
    R.it("produces correct initial shape", function()
      local i = ir.new({ "a", "b" }, "minimal")
      R.assert_type(i.caps, "table")
      R.assert_type(i.diagnostics, "table")
      R.assert_eq(#i.diagnostics, 0)
      R.assert_eq(i.profile, "minimal")
      R.assert_eq(i.meta.lang_modules[1], "a")
      R.assert_eq(i.stage, "AST")
    end)

    R.it("embeds ir_version = SCHEMA_VERSION in meta (P6-C4)", function()
      local i = ir.new({}, "full")
      R.assert_type(i.meta.ir_version, "number")
      R.assert_eq(i.meta.ir_version, ver.SCHEMA_VERSION)
    end)

    R.it("initialises all ext_caps buckets as empty tables", function()
      local cap_types = require("core.domain.cap_types")
      local i = ir.new({}, "full")
      R.assert_type(i.ext_caps, "table")
      for _, ct in ipairs(cap_types.ALL) do
        R.assert_type(i.ext_caps[ct], "table", "ext_caps." .. ct .. " must be a table")
        R.assert_true(next(i.ext_caps[ct]) == nil, "ext_caps." .. ct .. " must be empty at construction")
      end
    end)

    R.it("cap_specs initialised as empty table", function()
      local i = ir.new({}, "full")
      R.assert_type(i.cap_specs, "table")
      R.assert_true(next(i.cap_specs) == nil)
    end)
  end)

  -- ── clone() ────────────────────────────────────────────────────────────────

  R.describe("clone()", function()
    R.it("produces a deep-independent copy", function()
      local i = ir.new({ "mod" }, "full")
      i.caps = { python = { lsp = { pyright = {} } } }
      local c = ir.clone(i)
      c.caps.python.lsp.pyright.settings = { injected = true }
      R.assert_nil(i.caps.python.lsp.pyright.settings)
    end)
    R.it("clone is a new table identity", function()
      local i = ir.new({}, "full")
      R.assert_ne(ir.clone(i), i)
    end)
  end)

  -- ── with() ─────────────────────────────────────────────────────────────────

  R.describe("with()", function()
    R.it("patches selected fields, leaves others intact", function()
      local i = ir.new({ "m" }, "full")
      i.caps = { lua = {} }
      local n = ir.with(i, { resolved = { lsp = {}, tools = {} } })
      R.assert_not_nil(n.resolved)
      R.assert_eq(n.caps, i.caps)
      R.assert_nil(i.resolved)
    end)
    R.it("returns a new table (copy-on-write)", function()
      local i = ir.new({}, "full")
      R.assert_ne(ir.with(i, { stage = "HIR" }), i)
    end)
  end)

  -- ── append_diag() ──────────────────────────────────────────────────────────

  R.describe("append_diag()", function()
    R.it("returns new IR; original unchanged", function()
      local i = ir.new({}, "full")
      local d = ir.diag("collect", "mod.x", "failed")
      local n = ir.append_diag(i, d)
      R.assert_eq(#i.diagnostics, 0)
      R.assert_eq(#n.diagnostics, 1)
      R.assert_eq(n.diagnostics[1].stage, "collect")
    end)
    R.it("append_error alias forwards correctly", function()
      local i = ir.new({}, "full")
      local n = ir.append_error(i, ir.error("normalize", "python", "unknown"))
      R.assert_eq(#n.diagnostics, 1)
    end)
  end)

  -- ── diag() ────────────────────────────────────────────────────────────────

  R.describe("diag()", function()
    R.it("produces Diagnostic with all fields including code", function()
      local d = ir.diag("normalize", "python", "unknown strategy", "warn")
      R.assert_eq(d.stage, "normalize")
      R.assert_eq(d.node, "python")
      R.assert_eq(d.message, "unknown strategy")
      R.assert_eq(d.severity, "warn")
      R.assert_type(d.code, "string")
      R.assert_match(d.code, "^[WEI]%x+")
    end)
    R.it("code is deterministic", function()
      local d1 = ir.diag("collect", "mod.a", "same", "error")
      local d2 = ir.diag("collect", "mod.a", "same", "error")
      R.assert_eq(d1.code, d2.code)
    end)
  end)

  -- ── validate() ────────────────────────────────────────────────────────────

  R.describe("validate()", function()
    R.it("passes when required fields present for 'normalize'", function()
      local errs = ir.validate(F.ast({}), "normalize")
      R.assert_eq(#errs, 0)
    end)
    R.it("returns Diagnostic for missing field before 'optimize'", function()
      local i = F.ast({})
      i.resolved = nil
      local errs = ir.validate(i, "optimize")
      R.assert_true(#errs > 0)
      R.assert_match(errs[1].message, "resolved")
    end)
    R.it("returns error for unknown stage", function()
      local errs = ir.validate(F.ast({}), "nonexistent")
      R.assert_eq(#errs, 1)
      R.assert_match(errs[1].message, "unknown stage")
    end)
  end)

  -- ── diag_counts() ─────────────────────────────────────────────────────────

  R.describe("diag_counts()", function()
    R.it("counts errors and warns accurately", function()
      local i = ir.new({}, "full")
      i = ir.append_diag(i, ir.diag("s", "n", "e1", "error"))
      i = ir.append_diag(i, ir.diag("s", "n", "w1", "warn"))
      i = ir.append_diag(i, ir.diag("s", "n", "e2", "error"))
      local c = ir.diag_counts(i)
      R.assert_eq(c.errors, 2)
      R.assert_eq(c.warns, 1)
    end)
  end)

  -- ── transition() ──────────────────────────────────────────────────────────

  R.describe("transition()", function()
    R.it("advances through all five stages AST→SPEC", function()
      local i = ir.new({}, "full")
      for _, expected in ipairs({ "HIR", "MIR", "LIR", "SPEC" }) do
        i = ir.transition(i)
        R.assert_eq(i.stage, expected)
      end
    end)
    R.it("throws on illegal transition from SPEC (terminal)", function()
      local i = ir.with(ir.new({}, "full"), { stage = "SPEC" })
      R.assert_false(pcall(ir.transition, i))
    end)
    R.it("does not mutate input IR", function()
      local i = ir.new({}, "full")
      ir.transition(i)
      R.assert_eq(i.stage, "AST")
    end)
  end)

  -- ── assert_stage() ────────────────────────────────────────────────────────

  R.describe("assert_stage()", function()
    R.it("passes when stage matches", function()
      ir.assert_stage(ir.new({}, "full"), "AST")
    end)
    R.it("throws on mismatch", function()
      R.assert_false(pcall(ir.assert_stage, ir.new({}, "full"), "HIR"))
    end)
  end)

  -- ── ctx() ─────────────────────────────────────────────────────────────────

  R.describe("ctx()", function()
    R.it("produces CompilerContext with unique run_id per call", function()
      local i = ir.new({}, "full")
      local c1 = ir.ctx(i, "s", "k")
      local c2 = ir.ctx(i, "s", "k")
      R.assert_type(c1.run_id, "string")
      R.assert_ne(c1.run_id, c2.run_id)
      R.assert_eq(c1.cache_key, "k")
    end)
  end)

  -- ── diff() ────────────────────────────────────────────────────────────────

  R.describe("diff()", function()
    R.it("returns empty for structurally identical IRs (excluding timing)", function()
      local i = ir.new({ "m" }, "full")
      local changes = ir.diff(i, ir.clone(i))
      local relevant = {}
      for _, c in ipairs(changes) do
        if not c.path:find("started_at") then
          relevant[#relevant + 1] = c
        end
      end
      R.assert_eq(#relevant, 0)
    end)
    R.it("detects stage change", function()
      local i1 = ir.new({}, "full")
      local i2 = ir.with(i1, { stage = "HIR" })
      local found = false
      for _, c in ipairs(ir.diff(i1, i2)) do
        if c.path:find("stage") and c.old == "AST" and c.new == "HIR" then
          found = true
          break
        end
      end
      R.assert_true(found)
    end)
    R.it("format_diff() returns '(no changes)' for empty list", function()
      R.assert_eq(ir.format_diff({}), "(no changes)")
    end)
  end)
end)
