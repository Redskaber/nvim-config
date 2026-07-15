-- spec/runtime/output_validate_spec.lua
-- Unit tests for runtime.output_validate: shared post-condition validators.
-- Each of the 8 pipeline phases depends on these validators.

local R = require("spec._runner")

R.describe("runtime.output_validate", function()
  local ov = require("runtime.output_validate")

  -- ── M.make() factory ──────────────────────────────────────────────────

  R.describe("M.make()", function()
    R.it("returns a function", function()
      local fn = ov.make({})
      R.assert_type(fn, "function")
    end)

    R.it("returns empty diags for well-formed IR", function()
      local validate = ov.make({ "caps", "meta" })
      local ir = { stage = "AST", caps = {}, meta = {} }
      local diags = validate(ir)
      R.assert_eq(#diags, 0)
    end)

    R.it("detects missing required field", function()
      local validate = ov.make({ "caps", "meta", "symbols" })
      local ir = { stage = "HIR", caps = {}, meta = {} } -- no symbols
      local diags = validate(ir)
      R.assert_true(#diags > 0, "missing 'symbols' must produce a diag")
      local found = false
      for _, d in ipairs(diags) do
        if d.message and d.message:find("symbols") then
          found = true
          break
        end
      end
      R.assert_true(found, "diag message must mention the missing field")
    end)

    R.it("detects missing stage field", function()
      local validate = ov.make({})
      local ir = { caps = {} } -- no stage
      local diags = validate(ir)
      R.assert_true(#diags > 0, "missing stage must produce a diag")
    end)

    R.it("detects empty string stage", function()
      local validate = ov.make({})
      local ir = { stage = "", caps = {} }
      local diags = validate(ir)
      R.assert_true(#diags > 0, "empty stage must produce a diag")
    end)

    R.it("detects non-string stage", function()
      local validate = ov.make({})
      local ir = { stage = 42, caps = {} }
      local diags = validate(ir)
      R.assert_true(#diags > 0, "non-string stage must produce a diag")
    end)

    R.it("produces warn-severity diagnostics", function()
      local validate = ov.make({ "caps" })
      local ir = { stage = "AST" } -- no caps
      local diags = validate(ir)
      R.assert_true(#diags > 0)
      R.assert_eq(diags[1].severity, "warn")
    end)

    R.it("detects multiple missing fields", function()
      local validate = ov.make({ "caps", "meta", "symbols", "resolved" })
      local ir = { stage = "LIR" } -- all 4 missing
      local diags = validate(ir)
      R.assert_eq(#diags, 4, "all 4 missing fields must each produce a diag")
    end)

    R.it("works with no required fields (stage-only check)", function()
      local validate = ov.make(nil)
      local ir = { stage = "AST" }
      local diags = validate(ir)
      R.assert_eq(#diags, 0, "valid stage + no required fields = no diags")
    end)
  end)

  -- ── Per-phase validators ──────────────────────────────────────────────

  R.describe("per-phase validators", function()
    R.it("ov.collect is a function", function()
      R.assert_type(ov.collect, "function")
    end)

    R.it("ov.normalize is a function", function()
      R.assert_type(ov.normalize, "function")
    end)

    R.it("ov.canonicalize is a function", function()
      R.assert_type(ov.canonicalize, "function")
    end)

    R.it("ov.resolve is a function", function()
      R.assert_type(ov.resolve, "function")
    end)

    R.it("ov.optimize is a function", function()
      R.assert_type(ov.optimize, "function")
    end)

    R.it("ov.collect_ext is a function", function()
      R.assert_type(ov.collect_ext, "function")
    end)

    R.it("ov.cap_resolve is a function", function()
      R.assert_type(ov.cap_resolve, "function")
    end)

    R.it("ov.codegen is a function", function()
      R.assert_type(ov.codegen, "function")
    end)
  end)

  -- ── Phase-specific field requirements ─────────────────────────────────

  R.describe("phase-specific field requirements", function()
    R.it("collect validator checks caps + meta", function()
      local ir = { stage = "AST", caps = {}, meta = {} }
      R.assert_eq(#ov.collect(ir), 0)
      local ir_bad = { stage = "AST", caps = {} }
      R.assert_true(#ov.collect(ir_bad) > 0, "missing meta must fail")
    end)

    R.it("canonicalize validator checks caps + meta + symbols", function()
      local ir = { stage = "HIR", caps = {}, meta = {}, symbols = { lsp = {}, tools = {} } }
      R.assert_eq(#ov.canonicalize(ir), 0)
      local ir_bad = { stage = "HIR", caps = {}, meta = {} }
      R.assert_true(#ov.canonicalize(ir_bad) > 0, "missing symbols must fail")
    end)

    R.it("resolve validator checks caps + resolved", function()
      local ir = { stage = "MIR", caps = {}, resolved = { lsp = {}, tools = {} } }
      R.assert_eq(#ov.resolve(ir), 0)
      local ir_bad = { stage = "MIR", caps = {} }
      R.assert_true(#ov.resolve(ir_bad) > 0, "missing resolved must fail")
    end)

    R.it("optimize validator checks caps + resolved + merged_lsp + all_parsers", function()
      local ir = {
        stage = "LIR", caps = {}, resolved = {},
        merged_lsp = {}, all_parsers = {},
      }
      R.assert_eq(#ov.optimize(ir), 0)
      local ir_bad = { stage = "LIR", caps = {}, resolved = {} }
      local diags = ov.optimize(ir_bad)
      R.assert_eq(#diags, 2, "missing merged_lsp + all_parsers = 2 diags")
    end)

    R.it("collect_ext validator checks caps + meta + ext_caps", function()
      local ir = { stage = "AST", caps = {}, meta = {}, ext_caps = {} }
      R.assert_eq(#ov.collect_ext(ir), 0)
      local ir_bad = { stage = "AST", caps = {}, meta = {} }
      R.assert_true(#ov.collect_ext(ir_bad) > 0, "missing ext_caps must fail")
    end)

    R.it("cap_resolve validator checks caps + meta + cap_specs", function()
      local ir = { stage = "LIR", caps = {}, meta = {}, cap_specs = {} }
      R.assert_eq(#ov.cap_resolve(ir), 0)
      local ir_bad = { stage = "LIR", caps = {}, meta = {} }
      R.assert_true(#ov.cap_resolve(ir_bad) > 0, "missing cap_specs must fail")
    end)

    R.it("codegen validator checks caps + resolved + merged_lsp + all_parsers", function()
      local ir = {
        stage = "SPEC", caps = {}, resolved = {},
        merged_lsp = {}, all_parsers = {},
      }
      R.assert_eq(#ov.codegen(ir), 0)
    end)
  end)

  -- ── Diagnostic shape ──────────────────────────────────────────────────

  R.describe("diagnostic shape", function()
    R.it("each diag has stage, node, message, severity", function()
      local validate = ov.make({ "caps" })
      local ir = { stage = "AST" }
      local diags = validate(ir)
      R.assert_true(#diags > 0)
      local d = diags[1]
      R.assert_not_nil(d.stage)
      R.assert_not_nil(d.node)
      R.assert_not_nil(d.message)
      R.assert_not_nil(d.severity)
    end)

    R.it("stage field in diag is 'output_validate'", function()
      local validate = ov.make({ "caps" })
      local ir = { stage = "AST" }
      local diags = validate(ir)
      R.assert_eq(diags[1].stage, "output_validate")
    end)

    R.it("node field references the missing field name", function()
      local validate = ov.make({ "caps", "meta" })
      local ir = { stage = "AST" } -- both missing
      local diags = validate(ir)
      local has_caps = false
      local has_meta = false
      for _, d in ipairs(diags) do
        if d.node and d.node:find("caps") then has_caps = true end
        if d.node and d.node:find("meta") then has_meta = true end
      end
      R.assert_true(has_caps, "must have diag referencing ir.caps")
      R.assert_true(has_meta, "must have diag referencing ir.meta")
    end)
  end)
end)
