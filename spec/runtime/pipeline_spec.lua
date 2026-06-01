-- spec/runtime/pipeline_spec.lua
-- Pipeline integration + IR immutability golden tests.

local R = require("spec._runner")

R.describe("runtime.pipeline", function()
  local pipeline = require("runtime.pipeline")
  local ir_mod = require("core.compiler.ir")
  local F = require("spec._fixtures.ir")

  -- ── debug_run: collect ─────────────────────────────────────────────────────
  R.describe("debug_run(collect)", function()
    R.it("IR has caps and meta", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_type(ir.caps, "table")
      R.assert_type(ir.meta, "table")
      R.assert_not_nil(ir.meta.lang_modules)
    end)

    R.it("lua_lang cap present", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_not_nil(ir.caps.lua_lang)
    end)

    R.it("stage is AST", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_eq(ir.stage, "AST")
    end)

    R.it("meta.ir_version embedded (P6-C4)", function()
      local ver = require("core.compiler.cache.version")
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_eq(ir.meta.ir_version, ver.SCHEMA_VERSION)
    end)

    R.it("caps is deep-copy (registry independent)", function()
      local ir1 = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      ir1.caps.lua_lang = nil
      local ir2 = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_not_nil(ir2.caps.lua_lang)
    end)
  end)

  -- ── debug_run: normalize ───────────────────────────────────────────────────
  R.describe("debug_run(normalize)", function()
    R.it("python FormatterNode gets fn injected", function()
      local ir = pipeline.debug_run({ "modules.lang.python" }, "normalize")
      local cap = ir.caps and ir.caps.python
      R.assert_not_nil(cap)
      local fmts = cap.formatters and cap.formatters.python
      R.assert_not_nil(fmts)
      local node = fmts[1]
      R.assert_type(node, "table")
      R.assert_eq(node.kind, "formatter")
      R.assert_type(node.fn, "function")
    end)

    R.it("fn does not leak into subsequent collect stage", function()
      pipeline.debug_run({ "modules.lang.python" }, "normalize")
      local ir = pipeline.debug_run({ "modules.lang.python" }, "collect")
      local fmts = ir.caps.python and ir.caps.python.formatters and ir.caps.python.formatters.python
      if fmts then
        for _, v in ipairs(fmts) do
          if type(v) == "table" then
            R.assert_nil(v.fn)
          end
        end
      end
    end)
  end)

  -- ── debug_run: canonicalize ────────────────────────────────────────────────
  R.describe("debug_run(canonicalize)", function()
    R.it("IR.symbols has lsp and tools", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "canonicalize")
      R.assert_type(ir.symbols, "table")
      R.assert_type(ir.symbols.lsp, "table")
      R.assert_type(ir.symbols.tools, "table")
    end)

    R.it("lua_ls → lua-language-server", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "canonicalize")
      local sym = ir.symbols and ir.symbols.lsp and ir.symbols.lsp.lua_ls
      R.assert_not_nil(sym)
      R.assert_eq(sym.mason, "lua-language-server")
      R.assert_false(sym.system)
    end)

    R.it("rustfmt → system=true, mason=nil", function()
      local ir = pipeline.debug_run({ "modules.lang.rust" }, "canonicalize")
      local sym = ir.symbols and ir.symbols.tools and ir.symbols.tools.rustfmt
      R.assert_not_nil(sym)
      R.assert_true(sym.system)
      R.assert_nil(sym.mason)
    end)
  end)

  -- ── debug_run: optimize ────────────────────────────────────────────────────
  R.describe("debug_run(optimize)", function()
    R.it("all_parsers is deduplicated list", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang", "modules.lang.python" }, "optimize")
      R.assert_type(ir.all_parsers, "table")
      local seen = {}
      for _, p in ipairs(ir.all_parsers) do
        R.assert_true(not seen[p], "duplicate parser: " .. p)
        seen[p] = true
      end
    end)

    R.it("merged_lsp populated with lua_ls", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      R.assert_type(ir.merged_lsp, "table")
      R.assert_not_nil(ir.merged_lsp.lua_ls)
    end)

    R.it("LIR codegen pre-condition passes", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      local diags = ir_mod.validate(ir, "codegen")
      R.assert_eq(#diags, 0)
    end)
  end)

  -- ── pipeline.run() ─────────────────────────────────────────────────────────
  R.describe("run()", function()
    R.it("returns non-empty specs for lua_lang", function()
      local specs = pipeline.run({ "modules.lang.lua_lang" }, "full")
      R.assert_type(specs, "table")
      R.assert_true(#specs > 0)
    end)

    R.it("stable spec count across runs", function()
      local s1 = pipeline.run({ "modules.lang.lua_lang" }, "full")
      local s2 = pipeline.run({ "modules.lang.lua_lang" }, "full")
      R.assert_eq(#s1, #s2)
    end)

    R.it("returns (specs, ir) tuple", function()
      local specs, ir = pipeline.run({ "modules.lang.lua_lang" }, "full")
      R.assert_true(#specs > 0)
      R.assert_not_nil(ir.caps and ir.caps.lua_lang)
    end)

    R.it("state() is 'done' after successful run", function()
      pipeline.run({ "modules.lang.lua_lang" }, "full")
      R.assert_eq(pipeline.state(), "done")
    end)

    R.it("accepts cached_caps and skips collect", function()
      local ir_ast = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      local specs = pipeline.run({ "modules.lang.lua_lang" }, "full", ir_ast.caps)
      R.assert_true(#specs > 0)
    end)
  end)

  -- ── freeze / debug_run ─────────────────────────────────────────────────────
  R.describe("debug_run freeze", function()
    R.after_each(function()
      _G._ltos_debug_freeze = false
    end)

    R.it("freeze disabled after completion", function()
      pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      R.assert_false(_G._ltos_debug_freeze)
    end)

    R.it("does not affect M.state()", function()
      pipeline.run({ "modules.lang.lua_lang" }, "full")
      local before = pipeline.state()
      pipeline.debug_run({ "modules.lang.lua_lang" }, "canonicalize")
      R.assert_eq(pipeline.state(), before)
    end)
  end)

  -- ── Error accumulation ─────────────────────────────────────────────────────
  R.it("unknown module produces Diagnostic in IR.diagnostics", function()
    local ir = pipeline.debug_run({ "modules.lang.does_not_exist" }, "collect")
    R.assert_true(#ir.diagnostics > 0)
    R.assert_not_nil(ir.diagnostics[1].stage)
    R.assert_not_nil(ir.diagnostics[1].node)
  end)

  -- ── run_sub ────────────────────────────────────────────────────────────────
  R.it("run_sub() runs subset of phases on existing IR", function()
    local normalize = require("runtime.passes.normalize")
    local ir_ast = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
    local ir_hir, diags = pipeline.run_sub({ normalize }, ir_ast)
    R.assert_eq(#diags, 0)
    R.assert_eq(ir_hir.stage, "HIR")
  end)

  -- ── ir.diff() integration ──────────────────────────────────────────────────
  R.it("ir.diff() detects stage change between collect and optimize", function()
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
    R.assert_true(found)
  end)
end)
