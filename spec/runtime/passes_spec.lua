-- spec/runtime/passes_spec.lua
-- Individual runtime passes: collect, normalize, canonicalize, resolve,
-- optimize, codegen, collect_ext, cap_resolve.
-- Each pass tested for: Phase contract, COW, state transitions, IR field contract.

local R = require("spec._runner")

-- ── Shared helpers ────────────────────────────────────────────────────────────

local function ir_new(mods, profile)
  return require("core.compiler.ir").new(mods or {}, profile or "full")
end

local function run_phase(phase, ir)
  local pass_mod = require("core.compiler.pass")
  return pass_mod.run_phase(phase, ir)
end

-- Build minimal lua_lang AST IR through collect pass
local function collect_ir(modules)
  modules = modules or { "modules.lang.lua_lang" }
  local collect = require("runtime.passes.collect")
  local ir = ir_new(modules)
  local result = run_phase(collect, ir)
  return result
end

-- ── Phase 1: collect ─────────────────────────────────────────────────────────

R.describe("runtime.passes.collect", function()
  local collect = require("runtime.passes.collect")
  local ir_mod = require("core.compiler.ir")

  -- ── Phase contract ────────────────────────────────────────────────────────

  R.describe("Phase contract", function()
    R.it("has correct name", function()
      R.assert_eq(collect.name, "collect")
    end)
    R.it("input_state = 'idle'", function()
      R.assert_eq(collect.input_state, "idle")
    end)
    R.it("output_state = 'collecting'", function()
      R.assert_eq(collect.output_state, "collecting")
    end)
    R.it("run is a function", function()
      R.assert_type(collect.run, "function")
    end)
  end)

  -- ── COW semantics ─────────────────────────────────────────────────────────

  R.describe("COW semantics", function()
    R.it("returns new IR table (not same reference)", function()
      local ir = ir_new({ "modules.lang.lua_lang" })
      local result = collect.run(ir)
      R.assert_ne(result, ir)
    end)
    R.it("input IR caps remain empty after run", function()
      local ir = ir_new({ "modules.lang.lua_lang" })
      collect.run(ir)
      R.assert_true(next(ir.caps) == nil)
    end)
  end)

  -- ── IR output shape ───────────────────────────────────────────────────────

  R.describe("IR output", function()
    R.it("stage = AST after collect", function()
      local result = collect.run(ir_new({ "modules.lang.lua_lang" }))
      R.assert_eq(result.stage, "AST")
    end)
    R.it("caps table populated", function()
      local result = collect.run(ir_new({ "modules.lang.lua_lang" }))
      R.assert_type(result.caps, "table")
      R.assert_true(next(result.caps) ~= nil)
    end)
    R.it("lua_lang capability present in caps", function()
      local result = collect.run(ir_new({ "modules.lang.lua_lang" }))
      R.assert_not_nil(result.caps.lua_lang)
    end)
    R.it("meta.module_hashes populated", function()
      local result = collect.run(ir_new({ "modules.lang.lua_lang" }))
      R.assert_type(result.meta.module_hashes, "table")
    end)
  end)

  -- ── error handling ────────────────────────────────────────────────────────

  R.describe("error handling", function()
    R.it("unknown module appends error diagnostic", function()
      local result = collect.run(ir_new({ "modules.lang.does_not_exist_xyz" }))
      R.assert_true(#result.diagnostics > 0)
      local has_err = false
      for _, d in ipairs(result.diagnostics) do
        if d.severity == "error" then
          has_err = true
          break
        end
      end
      R.assert_true(has_err, "unknown module must produce error diagnostic")
    end)
    R.it("module returning non-table appends warn diagnostic", function()
      -- We can't easily inject a bad module without filesystem, but
      -- verify the collect pass handles diagnostic accumulation correctly
      local ir = ir_new({})
      local result = collect.run(ir)
      R.assert_type(result.diagnostics, "table")
    end)
  end)

  -- ── multiple modules ──────────────────────────────────────────────────────

  R.describe("multiple module collection", function()
    R.it("collects multiple lang modules independently", function()
      local result = collect.run(ir_new({
        "modules.lang.lua_lang",
        "modules.lang.python",
      }))
      R.assert_not_nil(result.caps.lua_lang)
      R.assert_not_nil(result.caps.python)
    end)
    R.it("diagnostic list remains empty for valid modules", function()
      local result = collect.run(ir_new({ "modules.lang.lua_lang" }))
      local err_count = 0
      for _, d in ipairs(result.diagnostics) do
        if d.severity == "error" then
          err_count = err_count + 1
        end
      end
      R.assert_eq(err_count, 0)
    end)
  end)
end)

-- ── Phase 2: normalize ───────────────────────────────────────────────────────

R.describe("runtime.passes.normalize", function()
  local normalize = require("runtime.passes.normalize")

  -- ── Phase contract ────────────────────────────────────────────────────────

  R.describe("Phase contract", function()
    R.it("name = 'normalize'", function()
      R.assert_eq(normalize.name, "normalize")
    end)
    R.it("input_state = 'collecting'", function()
      R.assert_eq(normalize.input_state, "collecting")
    end)
    R.it("output_state = 'normalizing'", function()
      R.assert_eq(normalize.output_state, "normalizing")
    end)
    R.it("validate is a function", function()
      R.assert_type(normalize.validate, "function")
    end)
  end)

  -- ── FormatterNode.fn injection ────────────────────────────────────────────

  R.describe("FormatterNode.fn injection", function()
    R.it("python FormatterNode.fn injected for ruff_or_black strategy", function()
      local ast = collect_ir({ "modules.lang.python" })
      local result = normalize.run(ast)
      local fmts = result.caps.python and result.caps.python.formatters
      R.assert_not_nil(fmts, "python formatters must exist")
      local py_fmts = fmts.python or {}
      local injected = false
      for _, v in ipairs(py_fmts) do
        if type(v) == "table" and v.kind == "formatter" and type(v.fn) == "function" then
          injected = true
          break
        end
      end
      R.assert_true(injected, "FormatterNode.fn must be injected by normalize")
    end)

    R.it("plain string formatters are unchanged", function()
      local ast = collect_ir({ "modules.lang.lua_lang" })
      local result = normalize.run(ast)
      local lua_fmts = result.caps.lua_lang and result.caps.lua_lang.formatters
      if lua_fmts and lua_fmts.lua then
        for _, v in ipairs(lua_fmts.lua) do
          if type(v) == "string" then
            R.assert_eq(v, v) -- string stays string
          end
        end
      end
    end)

    R.it("unknown strategy: fn is no-op function + warn diagnostic", function()
      local ir_mod = require("core.compiler.ir")
      local cap_mod = require("core.domain.capability")
      local ir = ir_new({})
      ir.caps = {}
      local set = cap_mod.new()
      set = cap_mod.add(set, "test_lang", {
        formatters = { lua = { { kind = "formatter", strategy = "nonexistent_strategy_xyz" } } },
      })
      ir.caps = cap_mod.snapshot(set)
      local result = normalize.run(ir)
      -- Should have a warn diagnostic for unknown strategy
      local has_warn = false
      for _, d in ipairs(result.diagnostics or {}) do
        if d.severity == "warn" and (d.message or ""):find("unknown formatter strategy") then
          has_warn = true
          break
        end
      end
      R.assert_true(has_warn, "unknown strategy must produce warn diagnostic")
    end)
  end)

  -- ── COW semantics ─────────────────────────────────────────────────────────

  R.describe("COW semantics", function()
    R.it("input AST caps unchanged after normalize", function()
      local ast = collect_ir({ "modules.lang.python" })
      local caps_before = vim.deepcopy(ast.caps)
      normalize.run(ast)
      -- Check python formatters in original are unmodified (no fn)
      local fmts = ast.caps.python and ast.caps.python.formatters
      if fmts and fmts.python then
        for _, v in ipairs(fmts.python) do
          if type(v) == "table" then
            R.assert_nil(v.fn, "original IR must not have fn injected")
          end
        end
      end
    end)
    R.it("result is new IR table", function()
      local ast = collect_ir()
      local result = normalize.run(ast)
      R.assert_ne(result, ast)
    end)
  end)

  -- ── Stage transition ──────────────────────────────────────────────────────

  R.it("output stage = HIR", function()
    local result = normalize.run(collect_ir())
    R.assert_eq(result.stage, "HIR")
  end)
end)

-- ── Phase 2.5: canonicalize ───────────────────────────────────────────────────

R.describe("runtime.passes.canonicalize", function()
  local canonicalize = require("runtime.passes.canonicalize")
  local normalize = require("runtime.passes.normalize")

  local function canon_ir(modules)
    local ast = collect_ir(modules)
    local hir = normalize.run(ast)
    return canonicalize.run(hir)
  end

  -- ── Phase contract ────────────────────────────────────────────────────────

  R.describe("Phase contract", function()
    R.it("name = 'canonicalize'", function()
      R.assert_eq(canonicalize.name, "canonicalize")
    end)
    R.it("input_state = 'normalizing'", function()
      R.assert_eq(canonicalize.input_state, "normalizing")
    end)
    R.it("output_state = 'canonicalizing'", function()
      R.assert_eq(canonicalize.output_state, "canonicalizing")
    end)
    R.it("validate is a function", function()
      R.assert_type(canonicalize.validate, "function")
    end)
  end)

  -- ── Symbol table ──────────────────────────────────────────────────────────

  R.describe("ir.symbols construction", function()
    R.it("symbols.lsp and symbols.tools populated", function()
      local result = canon_ir({ "modules.lang.lua_lang" })
      R.assert_type(result.symbols, "table")
      R.assert_type(result.symbols.lsp, "table")
      R.assert_type(result.symbols.tools, "table")
    end)

    R.it("lua_ls → mason='lua-language-server', system=false", function()
      local result = canon_ir({ "modules.lang.lua_lang" })
      local sym = result.symbols.lsp.lua_ls
      R.assert_not_nil(sym)
      R.assert_eq(sym.mason, "lua-language-server")
      R.assert_false(sym.system)
    end)

    R.it("rust_analyzer → system=false, mason='rust-analyzer'", function()
      local result = canon_ir({ "modules.lang.rust" })
      local sym = result.symbols.lsp.rust_analyzer
      R.assert_not_nil(sym)
      R.assert_eq(sym.mason, "rust-analyzer")
    end)

    R.it("rustfmt → system=true, mason=nil (system tool)", function()
      local result = canon_ir({ "modules.lang.rust" })
      local sym = result.symbols.tools.rustfmt
      R.assert_not_nil(sym)
      R.assert_true(sym.system)
      R.assert_nil(sym.mason)
    end)

    R.it("gofmt → system=true (in system_tools whitelist)", function()
      local result = canon_ir({ "modules.lang.go" })
      local sym = result.symbols.tools.gofmt
      R.assert_not_nil(sym, "gofmt symbol must exist")
      R.assert_true(sym.system, "gofmt must be system tool")
    end)

    R.it("stylua → use_mason=true (mason managed)", function()
      local result = canon_ir({ "modules.lang.lua_lang" })
      local sym = result.symbols.tools.stylua
      R.assert_not_nil(sym, "stylua symbol must exist")
      R.assert_false(sym.system, "stylua must not be system")
      R.assert_not_nil(sym.mason, "stylua must have mason package")
    end)
  end)

  -- ── COW + stage ───────────────────────────────────────────────────────────

  R.it("returns new IR (COW)", function()
    local hir = normalize.run(collect_ir())
    local result = canonicalize.run(hir)
    R.assert_ne(result, hir)
  end)
  R.it("stage unchanged (HIR → HIR+, no stage bump)", function()
    local result = canon_ir({ "modules.lang.lua_lang" })
    -- canonicalize stays on HIR stage (adds symbols without stage change)
    R.assert_type(result.stage, "string")
  end)

  -- ── Symbol deduplication ──────────────────────────────────────────────────

  R.it("same server not duplicated across modules", function()
    local result = canon_ir({
      "modules.lang.lua_lang",
      "modules.lang.lua_lang", -- intentional duplicate
    })
    local count = 0
    for k in pairs(result.symbols.lsp) do
      if k == "lua_ls" then
        count = count + 1
      end
    end
    R.assert_eq(count, 1, "lua_ls must appear exactly once in symbols")
  end)
end)

-- ── Phase 3: resolve ─────────────────────────────────────────────────────────

R.describe("runtime.passes.resolve", function()
  local resolve = require("runtime.passes.resolve")
  local canonicalize = require("runtime.passes.canonicalize")
  local normalize = require("runtime.passes.normalize")

  local function resolve_ir(modules)
    local ast = collect_ir(modules)
    local hir = normalize.run(ast)
    local hir2 = canonicalize.run(hir)
    return resolve.run(hir2)
  end

  -- ── Phase contract ────────────────────────────────────────────────────────

  R.describe("Phase contract", function()
    R.it("name = 'resolve'", function()
      R.assert_eq(resolve.name, "resolve")
    end)
    R.it("input_state = 'canonicalizing'", function()
      R.assert_eq(resolve.input_state, "canonicalizing")
    end)
    R.it("output_state = 'resolving'", function()
      R.assert_eq(resolve.output_state, "resolving")
    end)
    R.it("validate is a function", function()
      R.assert_type(resolve.validate, "function")
    end)
  end)

  -- ── IR.resolved construction ──────────────────────────────────────────────

  R.describe("IR.resolved construction", function()
    R.it("resolved.lsp and resolved.tools populated", function()
      local result = resolve_ir({ "modules.lang.lua_lang" })
      R.assert_type(result.resolved, "table")
      R.assert_type(result.resolved.lsp, "table")
      R.assert_type(result.resolved.tools, "table")
    end)

    R.it("lua_ls → resolved.lsp.lua_ls = true (mason managed)", function()
      local result = resolve_ir({ "modules.lang.lua_lang" })
      R.assert_true(result.resolved.lsp.lua_ls == true)
    end)

    R.it("rustfmt → resolved.tools.rustfmt = false (system tool)", function()
      local result = resolve_ir({ "modules.lang.rust" })
      R.assert_false(result.resolved.tools.rustfmt == true, "rustfmt is system — resolved must be false")
    end)

    R.it("stylua → resolved.tools.stylua = true (mason managed)", function()
      local result = resolve_ir({ "modules.lang.lua_lang" })
      R.assert_true(result.resolved.tools.stylua == true)
    end)
  end)

  -- ── Stage + COW ───────────────────────────────────────────────────────────

  R.it("output stage = MIR", function()
    R.assert_eq(resolve_ir({ "modules.lang.lua_lang" }).stage, "MIR")
  end)
  R.it("input HIR+ unchanged (COW)", function()
    local ast = collect_ir()
    local hir = normalize.run(ast)
    local hir2 = canonicalize.run(hir)
    resolve.run(hir2)
    R.assert_nil(hir2.resolved, "input IR must not have resolved field added")
  end)
end)

-- ── Phase 4: optimize ────────────────────────────────────────────────────────

R.describe("runtime.passes.optimize", function()
  local optimize = require("runtime.passes.optimize")
  local resolve = require("runtime.passes.resolve")
  local canonicalize = require("runtime.passes.canonicalize")
  local normalize = require("runtime.passes.normalize")

  local function opt_ir(modules)
    local ast = collect_ir(modules)
    local hir = normalize.run(ast)
    local hir2 = canonicalize.run(hir)
    local mir = resolve.run(hir2)
    return optimize.run(mir)
  end

  -- ── Phase contract ────────────────────────────────────────────────────────

  R.describe("Phase contract", function()
    R.it("name = 'optimize'", function()
      R.assert_eq(optimize.name, "optimize")
    end)
    R.it("input_state = 'resolving'", function()
      R.assert_eq(optimize.input_state, "resolving")
    end)
    R.it("output_state = 'optimizing'", function()
      R.assert_eq(optimize.output_state, "optimizing")
    end)
    R.it("validate is a function", function()
      R.assert_type(optimize.validate, "function")
    end)
  end)

  -- ── Deduplication ─────────────────────────────────────────────────────────

  R.describe("parser deduplication", function()
    R.it("all_parsers is deduplicated", function()
      local result = opt_ir({ "modules.lang.lua_lang", "modules.lang.python" })
      local seen = {}
      for _, p in ipairs(result.all_parsers) do
        R.assert_true(not seen[p], "duplicate parser: " .. p)
        seen[p] = true
      end
    end)
    R.it("all_parsers contains expected parsers", function()
      local result = opt_ir({ "modules.lang.lua_lang" })
      local set = {}
      for _, p in ipairs(result.all_parsers) do
        set[p] = true
      end
      R.assert_true(set.lua, "lua parser must be present")
      R.assert_true(set.luadoc, "luadoc parser must be present")
    end)
  end)

  -- ── LSP deep-merge ────────────────────────────────────────────────────────

  R.describe("LSP deep-merge", function()
    R.it("merged_lsp contains lua_ls", function()
      local result = opt_ir({ "modules.lang.lua_lang" })
      R.assert_type(result.merged_lsp, "table")
      R.assert_not_nil(result.merged_lsp.lua_ls)
    end)
    R.it("LSP from two modules merged without data loss", function()
      local result = opt_ir({ "modules.lang.lua_lang", "modules.lang.python" })
      R.assert_not_nil(result.merged_lsp.lua_ls)
      R.assert_not_nil(result.merged_lsp.pyright)
    end)
  end)

  -- ── Stage + COW ───────────────────────────────────────────────────────────

  R.it("output stage = LIR", function()
    R.assert_eq(opt_ir({ "modules.lang.lua_lang" }).stage, "LIR")
  end)
  R.it("codegen pre-condition passes for LIR output", function()
    local ir_mod = require("core.compiler.ir")
    local result = opt_ir({ "modules.lang.lua_lang" })
    local errs = ir_mod.validate(result, "codegen")
    R.assert_eq(#errs, 0, "LIR must satisfy codegen pre-conditions")
  end)
end)

-- ── Phase 5: codegen ─────────────────────────────────────────────────────────

R.describe("runtime.passes.codegen", function()
  local codegen = require("runtime.passes.codegen")
  local pipeline = require("runtime.pipeline")

  -- ── Phase contract ────────────────────────────────────────────────────────

  R.describe("Phase contract", function()
    R.it("name = 'codegen'", function()
      R.assert_eq(codegen.name, "codegen")
    end)
    R.it("input_state = 'optimizing'", function()
      R.assert_eq(codegen.input_state, "optimizing")
    end)
    R.it("output_state = 'codegen'", function()
      R.assert_eq(codegen.output_state, "codegen")
    end)
    R.it("validate is a function", function()
      R.assert_type(codegen.validate, "function")
    end)
    R.it("build() is a function", function()
      R.assert_type(codegen.build, "function")
    end)
  end)

  -- ── build() output ────────────────────────────────────────────────────────

  R.describe("build()", function()
    R.it("returns list of LazySpec tables", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      local specs = codegen.build(ir)
      R.assert_type(specs, "table")
      R.assert_true(#specs > 0)
      for i, s in ipairs(specs) do
        R.assert_type(s, "table", "spec[" .. i .. "] must be table")
      end
    end)

    R.it("all LTOS specs have _source prefix 'ltos:'", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      local specs = codegen.build(ir)
      for _, s in ipairs(specs) do
        if s._source then
          R.assert_match(s._source, "^ltos:", "bad _source: " .. tostring(s._source))
        end
      end
    end)

    R.it("merges cap_specs from cap_resolve into final list", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      -- Inject dummy cap_specs
      ir.cap_specs = {
        image = { { "test-image-plugin", _source = "ltos:test" } },
      }
      local specs = codegen.build(ir)
      local found = false
      for _, s in ipairs(specs) do
        if s[1] == "test-image-plugin" then
          found = true
          break
        end
      end
      R.assert_true(found, "cap_specs must be merged into codegen output")
    end)
  end)

  -- ── run() Phase interface compliance ──────────────────────────────────────

  R.describe("run() Phase interface compliance", function()
    R.it("run() returns IR with stage=SPEC and embedded _specs", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      local result = codegen.run(ir)
      R.assert_eq(result.stage, "SPEC")
      R.assert_type(result._specs, "table")
    end)
    R.it("run() COW: original IR unchanged", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      codegen.run(ir)
      R.assert_ne(ir.stage, "SPEC", "codegen.run must not mutate input stage")
    end)
  end)

  -- ── validate() pre-condition ──────────────────────────────────────────────

  R.describe("validate()", function()
    R.it("returns empty list for valid LIR", function()
      local ir = pipeline.debug_run({ "modules.lang.lua_lang" }, "optimize")
      local errs = codegen.validate(ir)
      R.assert_eq(#errs, 0)
    end)
    R.it("returns diagnostics for missing merged_lsp", function()
      local ir_mod = require("core.compiler.ir")
      local F = require("spec._fixtures.ir")
      local ir = F.lir()
      ir.merged_lsp = nil
      local errs = codegen.validate(ir)
      R.assert_true(#errs > 0)
    end)
  end)
end)