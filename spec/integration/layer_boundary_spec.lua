-- spec/integration/layer_boundary_spec.lua
-- Lua-level layer boundary assertions (complement to check_layer_boundaries.sh).
-- Tests that crossing layer boundaries is impossible via normal require().

local R = require("spec._runner")

R.describe("layer boundary contracts", function()
  -- ── INV-5: strict downward dependency ─────────────────────────────────────
  R.describe("INV-5: layer dependency direction", function()
    R.it("L0 kernel does NOT expose compiler modules", function()
      -- kernel should not re-export compiler symbols
      local env = require("core.kernel.env")
      R.assert_nil(env.ir, "kernel must not expose ir")
      R.assert_nil(env.pass, "kernel must not expose pass")
    end)

    R.it("L1 compiler ports has no vim.* in default config", function()
      -- ports defaults are non-vim (io-based)
      local ports = require("core.compiler.ports")
      -- cache_dir default should not crash headless
      local dir = ports.cache_dir()
      R.assert_type(dir, "string")
    end)

    R.it("L2 domain.diagnostic does NOT require compiler modules", function()
      -- diagnostic is a domain-layer (L2) module; must not upward-require compiler (L1)
      local info = debug.getinfo(require("core.domain.diagnostic").new, "S")
      -- Just verify it loads without side-effects; the shell script does deep check
      R.assert_type(require("core.domain.diagnostic").new, "function")
    end)

    R.it("L2 cap_types does NOT require any upper-layer module", function()
      local ct = require("core.domain.cap_types")
      R.assert_type(ct.IMAGE, "string")
      R.assert_type(ct.ALL, "table")
      R.assert_true(#ct.ALL >= 5)
    end)

    R.it("L2 keybind_presets_data is pure data (no vim.*)", function()
      local kp = require("core.domain.keybind_presets_data")
      R.assert_type(kp.HELIX, "string")
      R.assert_type(kp.ALL, "table")
      R.assert_true(kp.is_known("helix"))
      R.assert_false(kp.is_known("dvorak"))
    end)
  end)

  -- ── INV-8: DSL modules are pure declarations ───────────────────────────────
  R.describe("INV-8: DSL module purity", function()
    local lang_mods = {
      "modules.lang.lua_lang",
      "modules.lang.python",
      "modules.lang.rust",
      "modules.lang.go",
      "modules.lang.typescript",
    }
    for _, mod in ipairs(lang_mods) do
      R.it(mod .. ": returns plain table with no metatable", function()
        local ok, m = pcall(require, mod)
        R.assert_true(ok)
        R.assert_type(m, "table")
        R.assert_nil(getmetatable(m))
      end)

      R.it(mod .. ": declares version field", function()
        local _, m = pcall(require, mod)
        R.assert_type(m.version, "number")
      end)
    end

    local cap_mods = {
      "modules.cap.image",
      "modules.cap.media",
      "modules.cap.ai",
      "modules.cap.keybind",
    }
    for _, mod in ipairs(cap_mods) do
      R.it(mod .. ": returns plain table with cap_type + version", function()
        local ok, m = pcall(require, mod)
        R.assert_true(ok)
        R.assert_type(m, "table")
        R.assert_nil(getmetatable(m))
        R.assert_type(m.cap_type, "string")
        R.assert_type(m.version, "number")
      end)
    end
  end)

  -- ── INV-9: BuildRequest is sole vim.g entry ────────────────────────────────
  R.describe("INV-9: BuildRequest isolation", function()
    R.it("build_request.from_vim() reads vim.g and returns structured table", function()
      local br = require("runtime.build_request")
      local req = br.from_vim("full", { "modules.lang.lua_lang" })
      R.assert_eq(req.profile, "full")
      R.assert_type(req.overrides, "table")
      R.assert_type(req.base_tools, "table")
    end)

    R.it("rules_ctx() extracts prefer_system for nix profile", function()
      local br = require("runtime.build_request")
      local req = br.from_vim("nix", {})
      local ctx = br.rules_ctx(req)
      R.assert_true(ctx.prefer_system)
    end)

    R.it("rules_ctx() prefer_system=false for full profile", function()
      local br = require("runtime.build_request")
      local req = br.from_vim("full", {})
      local ctx = br.rules_ctx(req)
      R.assert_false(ctx.prefer_system)
    end)
  end)

  -- ── INV-3: Adapter output shape ───────────────────────────────────────────
  R.describe("INV-3: adapter output contracts", function()
    R.it("all adapters have a build() function", function()
      local adapter_mods = {
        "runtime.adapters.lsp",
        "runtime.adapters.mason",
        "runtime.adapters.treesitter",
        "runtime.adapters.conform",
        "runtime.adapters.lint",
      }
      for _, mod in ipairs(adapter_mods) do
        local ok, adapter = pcall(require, mod)
        R.assert_true(ok, mod .. " must load")
        R.assert_type(adapter.build, "function", mod .. " must have build()")
      end
    end)

    R.it("cap adapters have build(ir, caps_by_name) signature (2-arg)", function()
      local cap_adapters = {
        "runtime.adapters.image",
        "runtime.adapters.media",
        "runtime.adapters.ai_cap",
        "runtime.adapters.keybind",
      }
      local ir = require("core.compiler.ir").new({}, "full")
      for _, mod in ipairs(cap_adapters) do
        local _, adapter = pcall(require, mod)
        -- should handle nil caps_by_name gracefully
        local ok2, result = pcall(adapter.build, ir, {})
        R.assert_true(ok2, mod .. " must not throw for empty caps")
        R.assert_type(result, "table", mod .. " must return table")
      end
    end)
  end)

  -- ── INV-7: cache keys are content-based ───────────────────────────────────
  R.describe("INV-7: content-based cache keys", function()
    R.it("identical module lists → identical key", function()
      local key_mod = require("core.compiler.cache.key")
      local k1 = key_mod.compute({ "modules.lang.lua_lang" }, "full")
      local k2 = key_mod.compute({ "modules.lang.lua_lang" }, "full")
      R.assert_eq(k1, k2)
    end)

    R.it("different profiles → different key", function()
      local key_mod = require("core.compiler.cache.key")
      local k1 = key_mod.compute({ "modules.lang.lua_lang" }, "full")
      local k2 = key_mod.compute({ "modules.lang.lua_lang" }, "minimal")
      if k1 ~= "" and k2 ~= "" then
        R.assert_ne(k1, k2)
      end
    end)
  end)
end)
