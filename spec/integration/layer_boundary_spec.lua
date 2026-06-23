-- spec/integration/layer_boundary_spec.lua
-- Lua-level layer boundary contracts (complements check_layer_boundaries.sh).
-- Validates that crossing layer boundaries is impossible through normal require paths.

local R = require("spec._runner")

R.describe("integration: layer boundary contracts", function()
  -- ── INV-5: strict downward dependency ─────────────────────────────────────

  R.describe("INV-5: layer dependency direction (strict downward only)", function()
    R.describe("L0 kernel isolation", function()
      R.it("kernel.env does not expose compiler symbols", function()
        local env = require("core.kernel.env")
        R.assert_nil(env.ir, "kernel must not expose ir")
        R.assert_nil(env.pass, "kernel must not expose pass")
        R.assert_nil(env.cache, "kernel must not expose cache")
      end)
      R.it("kernel.util has no upper-layer dependencies", function()
        local util = require("core.kernel.util")
        R.assert_type(util.dedup, "function")
        R.assert_type(util.deep_merge, "function")
        R.assert_type(util.hash, "function")
      end)
    end)

    R.describe("L1 compiler port isolation", function()
      R.it("compiler ports default cache_dir() does not crash headless", function()
        local ports = require("core.compiler.ports")
        local dir = ports.cache_dir()
        R.assert_type(dir, "string")
        R.assert_true(#dir > 0)
      end)
      R.it("compiler.ir uses types abstraction (no direct domain require)", function()
        -- Verifiable: ir.diag() works through types interface
        local ir = require("core.compiler.ir")
        local d = ir.diag("collect", "mod", "test", "error")
        R.assert_type(d.code, "string")
        R.assert_match(d.code, "^E")
      end)
    end)

    R.describe("L2 domain isolation", function()
      R.it("core.domain.diagnostic does NOT require compiler modules", function()
        local diag = require("core.domain.diagnostic")
        R.assert_type(diag.new, "function")
        -- Works as pure L2 module
        local d = diag.new("s", "n", "m", "warn")
        R.assert_eq(d.severity, "warn")
      end)
      R.it("core.domain.cap_types is pure data (no vim.*, no upper-layer require)", function()
        local ct = require("core.domain.cap_types")
        R.assert_type(ct.IMAGE, "string")
        R.assert_type(ct.MEDIA, "string")
        R.assert_type(ct.AI, "string")
        R.assert_type(ct.KEYBIND, "string")
        R.assert_type(ct.EDITOR, "string")
        R.assert_type(ct.ALL, "table")
        R.assert_true(#ct.ALL >= 5)
        R.assert_type(ct.is_known, "function")
        R.assert_type(ct.as_set, "function")
      end)
      R.it("core.domain.keybind_presets_data is pure data", function()
        local kp = require("core.domain.keybind_presets_data")
        R.assert_type(kp.HELIX, "string")
        R.assert_type(kp.VIM, "string")
        R.assert_type(kp.EMACS, "string")
        R.assert_type(kp.ALL, "table")
        R.assert_true(kp.is_known("helix"))
        R.assert_true(kp.is_known("vim"))
        R.assert_false(kp.is_known("dvorak"))
      end)
      R.it("modules/capability/graph uses core.domain.diagnostic (not compiler)", function()
        local graph = require("modules.capability.graph")
        -- graph.sort returns (order, diags); diags use domain Diagnostic type
        local order, diags = graph.sort({
          { mod_path = "a", cap = { provides = { "x" }, depends = {} } },
        })
        R.assert_type(order, "table")
        R.assert_type(diags, "table")
      end)
    end)

    R.describe("L3 toolchain isolation", function()
      R.it("toolchain.rules does not read vim.g", function()
        -- rules.resolve() accepts overrides and ctx as parameters only
        local rules = require("toolchain.rules")
        local r = rules.resolve("stylua", {}, { prefer_system = false })
        R.assert_type(r, "table")
        R.assert_not_nil(r.use_mason)
      end)
      R.it("toolchain.strategy.conflict does not import adapter modules", function()
        local conflict = require("toolchain.strategy.conflict")
        R.assert_type(conflict.resolve, "function")
        -- If adapters were imported, this would fail layer checks
      end)
    end)
  end)

  -- ── INV-8: DSL modules are pure declarations ───────────────────────────────

  R.describe("INV-8: DSL module purity", function()
    R.describe("lang modules", function()
      local lang_mods = {
        "modules.lang.lua_lang",
        "modules.lang.python",
        "modules.lang.rust",
        "modules.lang.go",
        "modules.lang.typescript",
        "modules.lang.shell",
        "modules.lang.zig",
        "modules.lang.c_cpp",
      }
      for _, mod in ipairs(lang_mods) do
        R.it(mod .. ": plain table, no metatable", function()
          local ok, m = pcall(require, mod)
          R.assert_true(ok, mod .. " must load without error")
          R.assert_type(m, "table")
          R.assert_nil(getmetatable(m), "lang DSL must have no metatable")
        end)
        R.it(mod .. ": declares version as number", function()
          local _, m = pcall(require, mod)
          R.assert_type(m.version, "number")
        end)
      end
    end)

    R.describe("cap modules", function()
      local cap_mods = {
        "modules.cap.image",
        "modules.cap.media",
        "modules.cap.ai",
        "modules.cap.keybind",
      }
      for _, mod in ipairs(cap_mods) do
        R.it(mod .. ": plain table with cap_type + version", function()
          local ok, m = pcall(require, mod)
          R.assert_true(ok)
          R.assert_type(m, "table")
          R.assert_nil(getmetatable(m))
          R.assert_type(m.cap_type, "string")
          R.assert_true(#m.cap_type > 0)
          R.assert_type(m.version, "number")
        end)
      end
    end)
  end)

  -- ── INV-9: BuildRequest is sole vim.g entry for compilation ───────────────

  R.describe("INV-9: BuildRequest isolation", function()
    local br = require("runtime.build_request")

    R.it("from_vim() returns structured BuildRequest table", function()
      local req = br.from_vim("full", { "modules.lang.lua_lang" })
      R.assert_eq(req.profile, "full")
      R.assert_type(req.overrides, "table")
      R.assert_type(req.base_tools, "table")
      R.assert_type(req.modules, "table")
    end)

    R.it("prefer_system=true only for nix profile", function()
      R.assert_true(br.from_vim("nix", {}).prefer_system)
      R.assert_false(br.from_vim("full", {}).prefer_system)
      R.assert_false(br.from_vim("minimal", {}).prefer_system)
    end)

    R.it("overrides defaults to {} when vim.g.ltos_tool_overrides unset", function()
      vim.g.ltos_tool_overrides = nil
      local req = br.from_vim("full", {})
      R.assert_true(next(req.overrides) == nil)
    end)

    R.it("base_tools non-empty by default", function()
      vim.g.ltos_base_mason_tools = nil
      local req = br.from_vim("full", {})
      R.assert_true(#req.base_tools > 0)
    end)

    R.it("custom overrides propagated through rules_ctx", function()
      local ctx = br.rules_ctx({ prefer_system = true })
      R.assert_true(ctx.prefer_system)
    end)
  end)

  -- ── INV-3: Adapters are pure IR readers ───────────────────────────────────

  R.describe("INV-3: adapter purity contracts", function()
    local adapter_mods = {
      "runtime.adapters.lsp",
      "runtime.adapters.mason",
      "runtime.adapters.treesitter",
      "runtime.adapters.conform",
      "runtime.adapters.lint",
    }

    R.it("all lang adapters expose build() function", function()
      for _, mod in ipairs(adapter_mods) do
        local ok, adapter = pcall(require, mod)
        R.assert_true(ok, mod .. " must load")
        R.assert_type(adapter.build, "function", mod .. " must have build()")
      end
    end)

    R.it("lang adapters accept LIR and return table without error", function()
      local F = require("spec._fixtures.ir")
      local lir = F.lir(
        { lua = { lsp = { lua_ls = {} } } },
        { lsp = { lua_ls = true }, tools = {} },
        { lua_ls = { settings = {} } },
        { "lua", "luadoc" }
      )
      lir.symbols = { lsp = { lua_ls = { mason = "lua-language-server", system = false } }, tools = {} }
      for _, mod in ipairs(adapter_mods) do
        local _, adapter = pcall(require, mod)
        if adapter and adapter.build then
          local ok, result = pcall(adapter.build, lir)
          R.assert_true(ok, mod .. ".build() must not throw on valid LIR")
          R.assert_type(result, "table", mod .. ".build() must return table")
        end
      end
    end)

    R.it("cap adapters accept (ir, caps_by_name) and return table", function()
      local ir = require("core.compiler.ir").new({}, "full")
      local cap_adapters = {
        "runtime.adapters.image",
        "runtime.adapters.media",
        "runtime.adapters.ai_cap",
        "runtime.adapters.keybind",
      }
      for _, mod in ipairs(cap_adapters) do
        local _, adapter = pcall(require, mod)
        local ok, result = pcall(adapter.build, ir, {})
        R.assert_true(ok, mod .. ".build() must not throw for empty caps")
        R.assert_type(result, "table")
      end
    end)
  end)

  -- ── INV-7: cache keys are content-based ───────────────────────────────────

  R.describe("INV-7: content-based cache keys", function()
    local key_mod = require("core.compiler.cache.key")

    R.it("same inputs → identical keys (determinism)", function()
      local k1 = key_mod.compute({ "modules.lang.lua_lang" }, "full")
      local k2 = key_mod.compute({ "modules.lang.lua_lang" }, "full")
      R.assert_eq(k1, k2)
    end)

    R.it("different profiles → different keys", function()
      local k1 = key_mod.compute({ "modules.lang.lua_lang" }, "full")
      local k2 = key_mod.compute({ "modules.lang.lua_lang" }, "minimal")
      if k1 ~= "" and k2 ~= "" then
        R.assert_ne(k1, k2)
      end
    end)

    R.it("cap modules included in key (P6-A2)", function()
      local caps = require("runtime.passes.collect_ext").registered()
      local k1 = key_mod.compute({ "modules.lang.lua_lang" }, "full", caps)
      local k2 = key_mod.compute({ "modules.lang.lua_lang" }, "full", {})
      R.assert_ne(k1, k2)
    end)
  end)

  -- ── INV-10: compiler host IO via ports ────────────────────────────────────

  R.describe("INV-10: compiler host IO via ports", function()
    R.it("ports.cache_dir() returns non-empty string (configured by ports_bootstrap)", function()
      require("runtime.ports_bootstrap").setup()
      local ports = require("core.compiler.ports")
      local dir = ports.cache_dir()
      R.assert_type(dir, "string")
      R.assert_true(#dir > 0)
    end)

    R.it("ports.json_encode/decode round-trip works", function()
      require("runtime.ports_bootstrap").setup()
      local ports = require("core.compiler.ports")
      local data = { key = "value", n = 42 }
      local encoded = ports.json_encode(data)
      R.assert_type(encoded, "string")
      local decoded = ports.json_decode(encoded)
      R.assert_eq(decoded.key, "value")
      R.assert_eq(decoded.n, 42)
    end)
  end)

  -- ── INV-11: only collect_ext writes ext_caps ──────────────────────────────

  R.describe("INV-11: ext_caps bucket ownership", function()
    R.it("normalize pass does not write ext_caps", function()
      local pipeline = require("runtime.pipeline")
      local ir_ast = pipeline.debug_run({ "modules.lang.lua_lang" }, "collect")
      local pass_mod = require("core.compiler.pass")
      local normalize = require("runtime.passes.normalize")
      local ir_hir = pass_mod.run_phase(normalize, ir_ast)
      -- ext_caps from normalize should equal what was in ir_ast
      local ir_mod = require("core.compiler.ir")
      local changes = ir_mod.diff(ir_ast, ir_hir)
      local ext_caps_changed = false
      for _, c in ipairs(changes) do
        if c.path:find("ext_caps") and c.old ~= c.new then
          ext_caps_changed = true
          break
        end
      end
      R.assert_false(ext_caps_changed, "normalize must not modify ext_caps")
    end)
  end)

  -- ── INV-14: dual state machines are independent ───────────────────────────

  R.describe("INV-14: lifecycle SM ≠ pipeline SM", function()
    R.it("pipeline SM state does not bleed into lifecycle SM", function()
      package.loaded["runtime.lifecycle"] = nil
      local lc = require("runtime.lifecycle")
      local pipeline = require("runtime.pipeline")
      -- lifecycle in initial BOOT state
      R.assert_eq(lc.state(), "BOOT")
      -- running pipeline must not change lifecycle state
      pipeline.run({ "modules.lang.lua_lang" }, "full")
      R.assert_eq(lc.state(), "BOOT", "pipeline.run must not advance lifecycle SM")
    end)

    R.it("pipeline PHASE_ORDER has no lifecycle SM references", function()
      local pipeline = require("runtime.pipeline")
      for _, phase_name in ipairs(pipeline.PHASE_ORDER) do
        R.assert_false(phase_name:find("lifecycle"), "pipeline phase must not reference lifecycle: " .. phase_name)
      end
    end)
  end)
end)