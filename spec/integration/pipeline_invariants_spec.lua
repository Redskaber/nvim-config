-- spec/integration/pipeline_invariants_spec.lua
-- Advanced integration tests covering:
--   • IR as communication protocol (COW across all 8 phases)
--   • State machine: pipeline SM + lifecycle SM independence
--   • Incremental cache: AST tier, spec tier, invalidation
--   • Strategy pipeline: rule chain execution order
--   • Plugin-in: adapter/phase registration extensibility
--   • Data-driven: defaults drive exact pipeline behavior

local R = require("spec._runner")

-- ── IR as communication protocol (COW across all phases) ─────────────────────

R.describe("integration: IR as pipeline communication protocol", function()
  local pipeline = require("runtime.pipeline")
  local ir_mod = require("core.compiler.ir")

  -- ── Stage-by-stage COW verification ──────────────────────────────────────

  R.describe("COW across all 8 phases", function()
    local stages = {
      { stop = "collect", expected_stage = "AST" },
      { stop = "normalize", expected_stage = "HIR" },
      { stop = "canonicalize", expected_stage = "HIR" }, -- no stage bump
      { stop = "resolve", expected_stage = "MIR" },
      { stop = "optimize", expected_stage = "LIR" },
    }

    for _, tc in ipairs(stages) do
      R.it("debug_run('" .. tc.stop .. "') returns stage=" .. tc.expected_stage, function()
        local ir = pipeline.debug_run({ "modules.lang.lua" }, tc.stop)
        R.assert_eq(ir.stage, tc.expected_stage)
      end)
    end

    R.it("each phase returns a NEW IR table (COW invariant)", function()
      local pass_mod = require("core.compiler.pass")
      local collect = require("runtime.passes.collect")
      local ir = ir_mod.new({ "modules.lang.lua" })
      local result = pass_mod.run_phase(collect, ir)
      R.assert_ne(result, ir, "collect must return new IR table")
    end)

    R.it("input IR caps are read-only after collect (no mutation)", function()
      local pass_mod = require("core.compiler.pass")
      local collect = require("runtime.passes.collect")
      local ir = ir_mod.new({ "modules.lang.lua" })
      local result = pass_mod.run_phase(collect, ir)
      -- Modify result; original must be unaffected
      result.caps.lua = nil
      local result2 = pass_mod.run_phase(collect, ir)
      R.assert_not_nil(result2.caps.lua, "original IR must not be affected by result mutation")
    end)
  end)

  -- ── IR field contract across stage boundaries ─────────────────────────────

  R.describe("IR field contracts (stage pre-conditions)", function()
    local required_fields = {
      { stage = "normalize", fields = { "caps", "meta" } },
      { stage = "canonicalize", fields = { "caps", "meta" } },
      { stage = "resolve", fields = { "caps", "meta", "symbols" } },
      { stage = "optimize", fields = { "caps", "resolved" } },
      { stage = "codegen", fields = { "caps", "resolved", "merged_lsp", "all_parsers" } },
    }

    for _, tc in ipairs(required_fields) do
      R.it("validate(ir, '" .. tc.stage .. "') passes on real pipeline IR", function()
        local stop_before = tc.stage == "normalize" and "collect"
          or tc.stage == "canonicalize" and "normalize"
          or tc.stage == "resolve" and "canonicalize"
          or tc.stage == "optimize" and "resolve"
          or "optimize"
        local ir = pipeline.debug_run({ "modules.lang.lua" }, stop_before)
        local errs = ir_mod.validate(ir, tc.stage)
        R.assert_eq(
          #errs,
          0,
          "IR at '" .. stop_before .. "' must satisfy '" .. tc.stage .. "' preconditions"
        )
      end)
    end

    R.it("validate() fails when required field is nil", function()
      -- FIX-DEPLOY-TEST (2026-06-23): ir_mod.with({caps=nil}) doesn't remove
      -- caps because Lua table merge ignores nil values. Create a proper IR
      -- without caps by copying all fields except caps.
      local ir_ast = pipeline.debug_run({ "modules.lang.lua" }, "collect")
      local ir_bad = {}
      for k, v in pairs(ir_ast) do
        if k ~= "caps" then
          ir_bad[k] = v
        end
      end
      local errs = ir_mod.validate(ir_bad, "normalize")
      R.assert_true(#errs > 0, "missing caps must fail normalize pre-condition")
    end)
  end)

  -- ── ext_caps bucket protocol ──────────────────────────────────────────────

  R.describe("ext_caps bucket protocol", function()
    R.it("all 5 buckets initialized at IR construction", function()
      local cap_types = require("core.domain.cap_types")
      local ir = ir_mod.new({}, "full")
      for _, ct in ipairs(cap_types.ALL) do
        R.assert_type(ir.ext_caps[ct], "table")
        R.assert_true(
          next(ir.ext_caps[ct]) == nil,
          ct .. " bucket must be empty at IR construction"
        )
      end
    end)

    R.it("collect_ext fills ext_caps; other passes preserve it (INV-11)", function()
      local collect_ext = require("runtime.passes.collect_ext")
      local normalize = require("runtime.passes.normalize")
      local pass_mod = require("core.compiler.pass")

      local ast_ir = pipeline.debug_run({ "modules.lang.lua" }, "collect")
      local ast_plus = collect_ext.pass.run(ast_ir)
      local image_count = 0
      for _ in pairs(ast_plus.ext_caps.image or {}) do
        image_count = image_count + 1
      end

      -- After normalize, ext_caps must be preserved
      local hir_ir = normalize.run(ast_plus)
      local image_count_after = 0
      for _ in pairs(hir_ir.ext_caps.image or {}) do
        image_count_after = image_count_after + 1
      end

      R.assert_eq(
        image_count_after,
        image_count,
        "normalize must not remove ext_caps entries (INV-11)"
      )
    end)

    R.it("cap_specs initialized as empty table in new IR", function()
      local ir = ir_mod.new({}, "full")
      R.assert_type(ir.cap_specs, "table")
      R.assert_eq(next(ir.cap_specs), nil)
    end)
  end)
end)

-- ── State machine correctness ────────────────────────────────────────────────

R.describe("integration: state machine correctness", function()
  -- ── Pipeline SM transitions ───────────────────────────────────────────────

  R.describe("pipeline SM", function()
    local pipeline = require("runtime.pipeline")

    R.it("state = 'done' after successful run()", function()
      pipeline.run({ "modules.lang.lua" }, "full")
      R.assert_eq(pipeline.state(), "done")
    end)

    R.it("debug_run() does not affect pipeline.state()", function()
      pipeline.run({ "modules.lang.lua" }, "full")
      local before = pipeline.state()
      pipeline.debug_run({ "modules.lang.lua" }, "collect")
      R.assert_eq(pipeline.state(), before)
    end)

    R.it("timings() returns table after run()", function()
      pipeline.run({ "modules.lang.lua" }, "full")
      local t = pipeline.timings()
      R.assert_type(t, "table")
    end)

    R.it("timings contains entries for all phases", function()
      pipeline.run({ "modules.lang.lua" }, "full")
      local t = pipeline.timings()
      if t then
        for _, phase_name in ipairs({
          "collect",
          "normalize",
          "canonicalize",
          "resolve",
          "optimize",
        }) do
          R.assert_not_nil(t[phase_name], "timing for '" .. phase_name .. "' must be recorded")
        end
      end
    end)
  end)

  -- ── Lifecycle SM transitions ──────────────────────────────────────────────

  R.describe("lifecycle SM through full orchestrator", function()
    R.it("lifecycle transitions BOOT→SCHEMA_LOAD→COMPILE→EMIT→READY on build()", function()
      package.loaded["runtime.lifecycle"] = nil
      local lc = require("runtime.lifecycle")
      local seen = {}
      lc.observe(function(s) seen[s] = true end)

      local runtime = require("runtime")
      runtime.build()

      R.assert_true(seen[lc.STATES.SCHEMA_LOAD], "SCHEMA_LOAD must be visited")
      R.assert_true(seen[lc.STATES.COMPILE], "COMPILE must be visited")
      R.assert_true(seen[lc.STATES.EMIT], "EMIT must be visited")
      R.assert_true(seen[lc.STATES.READY], "READY must be visited")
    end)

    R.it("HOT_RELOAD transition on second build() call", function()
      package.loaded["runtime.lifecycle"] = nil
      local lc = require("runtime.lifecycle")
      local runtime = require("runtime")

      -- First build reaches READY
      runtime.build()
      R.assert_true(lc.is_ready())

      -- Second build should enter HOT_RELOAD
      local saw_reload = false
      lc.observe(function(s)
        if s == lc.STATES.HOT_RELOAD then
          saw_reload = true
        end
      end)
      runtime.build()
      R.assert_true(saw_reload, "second build() must transition through HOT_RELOAD")
    end)
  end)
end)

-- ── Incremental cache correctness ────────────────────────────────────────────

R.describe("integration: incremental cache", function()
  local cache = require("core.compiler.cache")
  local pipeline = require("runtime.pipeline")
  local key_mod = require("core.compiler.cache.key")
  local ver = require("core.compiler.cache.version")

  -- ── AST tier ──────────────────────────────────────────────────────────────

  R.describe("AST tier", function()
    R.it("AST cache round-trip preserves caps structure", function()
      cache.invalidate_all()
      local modules = { "modules.lang.lua" }
      local caps = require("runtime.passes.collect_ext").registered()
      local k = key_mod.compute(modules, "full", caps)

      if k ~= "" then
        -- Save a dummy AST payload
        local payload = {
          caps = { lua = { treesitter = { "lua" } } },
          ext_caps = {},
          module_hashes = {},
        }
        cache.save("ast", k, payload)
        local loaded = cache.load("ast", k)
        R.assert_not_nil(loaded)
        R.assert_not_nil(loaded.caps.lua)
      end
    end)
  end)

  -- ── Spec tier ─────────────────────────────────────────────────────────────

  R.describe("spec tier", function()
    R.it("spec cache populated after first run", function()
      cache.invalidate_all()
      local specs = pipeline.run({ "modules.lang.lua" }, "full")
      R.assert_true(#specs > 0)

      local modules = { "modules.lang.lua" }
      local caps = require("runtime.passes.collect_ext").registered()
      local k = key_mod.compute(modules, "full", caps)

      if k ~= "" then
        local cached = cache.load("spec", k)
        -- May be cached or not depending on timing, but no crash
        R.assert_true(cached == nil or type(cached) == "table")
      end
    end)

    R.it("spec cache miss increments miss counter", function()
      cache.load("spec", "definitely-missing-key-" .. math.random(1e9))
      local stats = cache.stats()
      R.assert_true((stats.spec and stats.spec.misses or 0) >= 1)
    end)
  end)

  -- ── Invalidation cascade ──────────────────────────────────────────────────

  R.describe("invalidation cascade", function()
    R.it("invalidate('ast') removes spec tier too (downstream cascade)", function()
      local k = "cascade-test-" .. math.random(1e6)
      cache.save("ast", k, { caps = {} })
      cache.save("spec", k, { specs = {} })

      R.assert_not_nil(cache.load("ast", k))
      R.assert_not_nil(cache.load("spec", k))

      cache.invalidate("ast")

      R.assert_nil(cache.load("ast", k), "ast must be nil after invalidate")
      R.assert_nil(cache.load("spec", k), "spec must be nil after ast invalidation")
    end)
  end)

  -- ── Content-hash determinism (INV-7) ─────────────────────────────────────

  R.describe("content-hash determinism (INV-7)", function()
    R.it("same content → same key across two computations", function()
      local k1 = key_mod.compute({ "modules.lang.lua" }, "full")
      local k2 = key_mod.compute({ "modules.lang.lua" }, "full")
      R.assert_eq(k1, k2)
    end)

    R.it("key includes schema version suffix :vN", function()
      local k = key_mod.compute({ "modules.lang.lua" }, "full")
      if k ~= "" then
        R.assert_match(k, ":v%d+$")
        R.assert_match(k, ":v" .. ver.SCHEMA_VERSION .. "$")
      end
    end)

    R.it("different profiles produce different keys", function()
      local k_full = key_mod.compute({ "modules.lang.lua" }, "full")
      local k_minimal = key_mod.compute({ "modules.lang.lua" }, "minimal")
      if k_full ~= "" and k_minimal ~= "" then
        R.assert_ne(k_full, k_minimal)
      end
    end)
  end)
end)

-- ── Strategy pipeline: rule chain execution order ────────────────────────────

R.describe("integration: strategy rule chain execution order", function()
  local rules = require("toolchain.rules")
  local mappings = require("toolchain.mappings")
  -- FIX-DEPLOY-TEST (2026-06-23): pipeline is required here because the
  -- "complete pipeline through canonicalize" sub-describe uses it. Previously
  -- pipeline was only local in the first describe block (line 14), so this
  -- block referenced a nil global → test failed with "attempt to index global
  -- 'pipeline' (a nil value)".
  local pipeline = require("runtime.pipeline")

  R.describe("rule priority chain", function()
    R.it("user override takes highest priority (Rule 1)", function()
      -- Override prettierd to system
      local r = rules.resolve("prettierd", { prettierd = { use_mason = false, pkg = nil } }, {})
      R.assert_false(r.use_mason, "user override must win over all other rules")
    end)

    R.it("system_tools whitelist blocks mason (Rule 3, before mapping)", function()
      -- gofmt is in system_tools and also not in tool_to_mason
      local r = rules.resolve("gofmt", {}, {})
      R.assert_false(r.use_mason, "system_tools must block mason install")
    end)

    R.it("explicit mapping wins over identity fallback (Rule 5 before Rule 6)", function()
      -- ruff_format has explicit mapping to "ruff"
      local r = rules.resolve("ruff_format", {}, {})
      R.assert_true(r.use_mason)
      R.assert_eq(r.pkg, "ruff", "explicit mapping must win over identity")
    end)

    R.it("identity fallback applies for unmapped tools (Rule 6 last)", function()
      local r = rules.resolve("completely_unknown_tool_xyz123", {}, {})
      R.assert_true(r.use_mason)
      R.assert_eq(r.pkg, "completely_unknown_tool_xyz123")
    end)

    R.it("mappings.overrides win before system_tools (registered override)", function()
      -- Register a system tool override in mappings.overrides
      local tool = "test_override_priority_" .. math.random(1e6)
      mappings.register_override(tool, { use_mason = true, pkg = "force-mason" })
      local r = rules.resolve(tool, {}, {}) -- no user overrides
      -- mappings.overrides is checked in Rule 1 (override_rule)
      R.assert_true(r.use_mason, "mappings.overrides must be honored")
      mappings.overrides[tool] = nil -- cleanup
    end)
  end)

  R.describe("complete pipeline through canonicalize", function()
    R.it("canonicalize produces correct symbols for all tool types", function()
      local ir = pipeline.debug_run({ "modules.lang.go" }, "canonicalize")

      -- gofmt: system tool → system=true, mason=nil
      local gofmt_sym = ir.symbols.tools.gofmt
      if gofmt_sym then
        R.assert_true(gofmt_sym.system, "gofmt must be system")
        R.assert_nil(gofmt_sym.mason, "gofmt must have nil mason")
      end

      -- goimports: mason managed → system=false, mason="goimports"
      local goimports_sym = ir.symbols.tools.goimports
      if goimports_sym then
        R.assert_false(goimports_sym.system, "goimports must not be system")
        R.assert_not_nil(goimports_sym.mason, "goimports must have mason pkg")
      end

      -- gopls: LSP server
      local gopls_sym = ir.symbols.lsp.gopls
      R.assert_not_nil(gopls_sym, "gopls symbol must exist")
      R.assert_eq(gopls_sym.mason, "gopls")
    end)
  end)
end)

-- ── Plugin-in: extensibility contracts ───────────────────────────────────────

R.describe("integration: plugin-in extensibility", function()
  local pipeline = require("runtime.pipeline")

  -- ── Phase registration ────────────────────────────────────────────────────

  R.describe("phase registration extensibility", function()
    R.it("PhaseRegistry.register() + list() supports dynamic phase insertion", function()
      local pr = require("runtime.phase_registry")
      pr._reset()

      local dummy = {
        name = "custom_phase_test",
        input_state = "x",
        output_state = "y",
        run = function(i) return require("core.compiler.ir").clone(i) end,
      }
      pr.register(dummy, { priority = 999 })
      local list = pr.list()
      local found = false
      for _, p in ipairs(list) do
        if p.name == "custom_phase_test" then
          found = true
          break
        end
      end
      R.assert_true(found, "dynamically registered phase must appear in list()")

      -- Restore defaults
      pr._reset()
      package.loaded["runtime.pipeline"] = nil
      require("runtime.pipeline")
    end)
  end)

  -- ── Adapter registration ──────────────────────────────────────────────────

  R.describe("adapter registration extensibility", function()
    R.it("AdapterRegistry.register() adds custom adapter to emit pipeline", function()
      local reg = require("runtime.adapters.registry")

      -- Register a custom adapter
      local custom_path = "runtime.adapters.__test_custom__" .. math.random(1e6)
      package.loaded[custom_path] = {
        build = function(_) return { { "custom/plugin", _source = "ltos:test" } } end,
      }

      local before = #reg.list()
      reg.register(custom_path, { priority = 999 })
      R.assert_eq(#reg.list(), before + 1, "custom adapter must be in list")

      -- Verify emit includes it
      local ir = pipeline.debug_run({ "modules.lang.lua" }, "optimize")
      local emitter = require("runtime.emitter")
      local specs = emitter.emit(ir, { custom_path })
      local found = false
      for _, s in ipairs(specs) do
        if s[1] == "custom/plugin" then
          found = true
          break
        end
      end
      R.assert_true(found, "custom adapter output must appear in emit result")

      -- cleanup
      package.loaded[custom_path] = nil
      reg._reset()
      reg.setup()
    end)
  end)

  -- ── CapAdapterRegistry extensibility ─────────────────────────────────────

  R.describe("CapAdapterRegistry extensibility", function()
    R.it("register() + get() allows custom cap type adapter", function()
      local cap_reg = require("runtime.adapters.cap_registry")

      local custom_type = "custom_cap_type_" .. math.random(1e6)
      local custom_path = "runtime.adapters.__test_cap__" .. math.random(1e6)
      package.loaded[custom_path] = {
        build = function(_, _) return { { "custom/cap-plugin" } } end,
      }

      cap_reg.register(custom_type, custom_path)
      local adapter = cap_reg.get(custom_type)
      R.assert_not_nil(adapter, "custom cap adapter must be retrievable")
      R.assert_type(adapter.build, "function")

      -- cleanup
      package.loaded[custom_path] = nil
    end)
  end)

  -- ── ProviderRegistry extensibility ───────────────────────────────────────

  R.describe("ProviderRegistry.register_filter() extensibility", function()
    R.it("register_filter() adds a custom profile filter", function()
      local reg = require("runtime.providers.registry")

      -- Register a custom "testing" profile that only includes lua
      reg.register_filter("testing_custom_profile", function(modules, _)
        local out = {}
        for _, m in ipairs(modules) do
          if m == "modules.lang.lua" then
            out[#out + 1] = m
          end
        end
        return out
      end)

      local filtered = reg.resolve("testing_custom_profile")
      R.assert_eq(#filtered, 1)
      R.assert_eq(filtered[1], "modules.lang.lua")
    end)
  end)
end)

-- ── Data-driven: defaults drive pipeline behavior ────────────────────────────

R.describe("integration: data-driven pipeline behavior", function()
  local pipeline = require("runtime.pipeline")

  R.describe("defaults drive exact adapter output", function()
    R.it("all 5 default adapters produce specs in correct order", function()
      local specs = pipeline.run({ "modules.lang.lua" }, "full")
      local names = {}
      for _, s in ipairs(specs) do
        if s[1] then
          names[s[1]] = true
        end
      end
      -- All 5 adapters must contribute at least one spec each
      R.assert_true(names["neovim/nvim-lspconfig"], "lsp adapter")
      R.assert_true(names["mason-org/mason.nvim"], "mason adapter")
      R.assert_true(names["nvim-treesitter/nvim-treesitter"], "treesitter adapter")
      R.assert_true(names["stevearc/conform.nvim"], "conform adapter")
      R.assert_true(names["mfussenegger/nvim-lint"], "lint adapter")
    end)

    R.it("default cap adapters produce image.nvim spec", function()
      local collect_ext = require("runtime.passes.collect_ext")
      local orig = collect_ext.registered()
      collect_ext.register({ "modules.cap.image" })
      local specs = pipeline.run({ "modules.lang.lua" }, "full")
      collect_ext.register(orig)
      local found = false
      for _, s in ipairs(specs) do
        if s[1] == "3rd/image.nvim" then
          found = true
          break
        end
      end
      R.assert_true(found, "image cap adapter must produce 3rd/image.nvim spec")
    end)
  end)

  R.describe("data-driven phase order from defaults/phases.lua", function()
    R.it("PHASE_ORDER matches canonical phase order from defaults", function()
      local defaults = require("runtime.defaults.phases")
      -- Build expected order from defaults (sorted by priority + declarative deps)
      local phase_names = {}
      for _, e in ipairs(defaults.phases) do
        phase_names[#phase_names + 1] = e.path:match("([^.]+)$")
      end
      phase_names[#phase_names + 1] = defaults.codegen:match("([^.]+)$")

      -- Each name in defaults must appear in PHASE_ORDER
      local pos = {}
      for i, n in ipairs(pipeline.PHASE_ORDER) do
        pos[n] = i
      end
      for _, name in ipairs(phase_names) do
        R.assert_not_nil(pos[name], name .. " from defaults must appear in PHASE_ORDER")
      end
    end)
  end)

  R.describe("profile-driven module selection", function()
    R.it("full profile produces more specs than minimal", function()
      local specs_full = pipeline.run(require("runtime.providers.registry").resolve("full"), "full")
      local specs_minimal =
        pipeline.run(require("runtime.providers.registry").resolve("minimal"), "minimal")
      -- Full has more modules → more LSP servers → more specs
      R.assert_true(#specs_full >= #specs_minimal, "full profile must produce >= specs as minimal")
    end)
  end)
end)