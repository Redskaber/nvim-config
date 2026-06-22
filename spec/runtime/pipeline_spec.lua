-- spec/runtime/pipeline_spec.lua
-- runtime.pipeline: debug_run per-stage, run(), freeze, diagnostics, run_sub.

local R = require("spec._runner")

R.describe("runtime.pipeline", function()
  local pipeline = require("runtime.pipeline")
  local ir_mod = require("core.compiler.ir")
  local ver = require("core.compiler.cache.version")
  local F = require("spec._fixtures.ir")

  -- ── debug_run: collect ────────────────────────────────────────────────────

  R.describe("debug_run → collect stage", function()
    R.it("IR has caps and meta", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_type(ir.caps, "table")
      R.assert_type(ir.meta, "table")
    end)
    R.it("lua_lang capability present in caps", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_not_nil(ir.caps.lua_lang)
    end)
    R.it("IR stage = AST after collect", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_eq(ir.stage, "AST")
    end)
    R.it("ir_version embedded in meta (P6-C4)", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_eq(ir.meta.ir_version, ver.SCHEMA_VERSION)
    end)
    R.it("caps is deep-copy; modifying result doesn't affect next run", function()
      local ir1 = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      ir1.caps.lua_lang = nil
      local ir2 = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_not_nil(ir2.caps.lua_lang, "registry must not be affected by IR mutation")
    end)
  end)

  -- ── debug_run: normalize ──────────────────────────────────────────────────

  R.describe("debug_run → normalize stage", function()
    R.it("python FormatterNode.fn injected", function()
      local ir = pipeline.debug_run({ "modules.lang.python" }, "normalize")
      local cap = ir.caps and ir.caps.python
      R.assert_not_nil(cap, "python cap must exist")
      local fmts = cap.formatters and cap.formatters.python
      R.assert_not_nil(fmts, "python formatters must exist")
      local node = fmts[1]
      R.assert_type(node, "table")
      R.assert_eq(node.kind, "formatter")
      R.assert_type(node.fn, "function", "fn must be injected by normalize")
    end)
    R.it("fn does not leak into subsequent collect snapshot", function()
      pipeline.debug_run({ "modules.lang.python" }, "normalize")
      local ir = pipeline.debug_run({ "modules.lang.python" }, "collect")
      local fmts = ir.caps.python and ir.caps.python.formatters and ir.caps.python.formatters.python
      if fmts then
        for _, v in ipairs(fmts) do
          if type(v) == "table" then
            R.assert_nil(v.fn, "fn must not appear in collect IR")
          end
        end
      end
    end)
  end)

  -- ── debug_run: canonicalize ───────────────────────────────────────────────

  R.describe("debug_run → canonicalize stage", function()
    R.it("IR.symbols has lsp and tools sub-tables", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "canonicalize")
      R.assert_type(ir.symbols, "table")
      R.assert_type(ir.symbols.lsp, "table")
      R.assert_type(ir.symbols.tools, "table")
    end)
    R.it("lua_ls → mason pkg = lua-language-server", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "canonicalize")
      local sym = ir.symbols.lsp.lua_ls
      R.assert_not_nil(sym, "lua_ls symbol must exist")
      R.assert_eq(sym.mason, "lua-language-server")
      R.assert_false(sym.system)
    end)
    R.it("rustfmt → system=true, mason=nil", function()
      local ir = pipeline.debug_run({ "modules.lang.rust" }, "canonicalize")
      local sym = ir.symbols.tools and ir.symbols.tools.rustfmt
      R.assert_not_nil(sym, "rustfmt symbol must exist")
      R.assert_true(sym.system)
      R.assert_nil(sym.mason)
    end)
  end)

  -- ── debug_run: optimize ───────────────────────────────────────────────────

  R.describe("debug_run → optimize stage", function()
    R.it("all_parsers is deduplicated", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang", "modules.lang.python" }, "optimize")
      R.assert_type(ir.all_parsers, "table")
      local seen = {}
      for _, p in ipairs(ir.all_parsers) do
        R.assert_true(not seen[p], "duplicate parser: " .. p)
        seen[p] = true
      end
    end)
    R.it("merged_lsp contains lua_ls", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      R.assert_type(ir.merged_lsp, "table")
      R.assert_not_nil(ir.merged_lsp.lua_ls)
    end)
    R.it("LIR codegen pre-condition passes (all required fields present)", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      local diags = ir_mod.validate(ir, "codegen")
      R.assert_eq(#diags, 0)
    end)
    R.it("IR stage = LIR after optimize", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      R.assert_eq(ir.stage, "LIR")
    end)
  end)

  -- ── pipeline.run() ────────────────────────────────────────────────────────

  R.describe("run()", function()
    R.it("returns non-empty specs for lua_lang", function()
      local specs = pipeline.run({ "modules.lang.lua_lang" }, "full")
      R.assert_type(specs, "table")
      R.assert_true(#specs > 0)
    end)

    R.it("stable spec count across two runs (determinism)", function()
      local s1 = pipeline.run({ "modules.lang.lua_lang" }, "full")
      local s2 = pipeline.run({ "modules.lang.lua_lang" }, "full")
      R.assert_eq(#s1, #s2)
    end)

    R.it("returns (specs, ir) two-value tuple", function()
      local specs, ir = pipeline.run({ "modules.lang.lua_lang" }, "full")
      R.assert_true(#specs > 0)
      R.assert_not_nil(ir.caps and ir.caps.lua_lang)
    end)

    R.it("state() = 'done' after successful run", function()
      pipeline.run({ "modules.lang.lua_lang" }, "full")
      R.assert_eq(pipeline.state(), "done")
    end)

    R.it("accepts cached_caps and skips collect phase", function()
      local ir_ast = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      local specs = pipeline.run({ "modules.lang.lua_lang" }, "full", ir_ast.caps)
      R.assert_true(#specs > 0)
    end)

    R.it("build_request ends up in IR.meta after run", function()
      local br = require("runtime.build_request")
      local req = br.from_vim("full", { "modules.lang.lua_lang" })
      local _, ir = pipeline.run({ "modules.lang.lua_lang" }, "full", nil, nil, req)
      R.assert_not_nil(ir.meta.build_request)
      R.assert_eq(ir.meta.build_request.profile, "full")
    end)
  end)

  -- ── freeze / debug_run ────────────────────────────────────────────────────

  R.describe("debug_run freeze flag", function()
    R.after_each(function()
      _G._ltos_debug_freeze = false
    end)

    R.it("_ltos_debug_freeze is false after debug_run completes", function()
      pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_false(_G._ltos_debug_freeze)
    end)

    R.it("debug_run does not affect pipeline.state()", function()
      pipeline.run({ "modules.lang.lua_lang" }, "full")
      local before = pipeline.state()
      pipeline.debug_run({ "modules.lang.lua_lang" }, "canonicalize")
      R.assert_eq(pipeline.state(), before)
    end)
  end)

  -- ── error accumulation ────────────────────────────────────────────────────

  R.describe("error accumulation", function()
    R.it("unknown module produces Diagnostic in IR.diagnostics", function()
      local ir = pipeline.debug_run({ "modules.lang.does_not_exist_xyz" }, "collect")
      R.assert_true(#ir.diagnostics > 0)
      R.assert_not_nil(ir.diagnostics[1].stage)
      R.assert_not_nil(ir.diagnostics[1].node)
    end)
  end)

  -- ── run_sub() ─────────────────────────────────────────────────────────────

  R.describe("run_sub()", function()
    R.it("runs subset of phases on existing IR, returns updated IR + diags", function()
      local normalize = require("runtime.passes.normalize")
      local ir_ast = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      local ir_hir, diags = pipeline.run_sub({ normalize }, ir_ast)
      R.assert_eq(#diags, 0)
      R.assert_eq(ir_hir.stage, "HIR")
    end)
  end)

  -- ── ir.diff() integration ─────────────────────────────────────────────────

  R.describe("ir.diff() integration", function()
    R.it("detects stage change between collect and optimize", function()
      local ir_ast = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      local ir_lir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      local changes = ir_mod.diff(ir_ast, ir_lir)
      R.assert_true(#changes > 0)
      local found = false
      for _, c in ipairs(changes) do
        if c.path:find("stage") then
          found = true
          break
        end
      end
      R.assert_true(found, "stage change must appear in diff")
    end)
  end)

  -- ── PHASE_ORDER contract ──────────────────────────────────────────────────

  R.describe("PHASE_ORDER contract", function()
    R.it("is a string list with >= 8 entries", function()
      R.assert_type(pipeline.PHASE_ORDER, "table")
      R.assert_true(#pipeline.PHASE_ORDER >= 8)
    end)
    R.it("first entry is 'collect'", function()
      R.assert_eq(pipeline.PHASE_ORDER[1], "collect")
    end)
    R.it("last entry is 'codegen'", function()
      R.assert_eq(pipeline.PHASE_ORDER[#pipeline.PHASE_ORDER], "codegen")
    end)
  end)
end)