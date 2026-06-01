-- spec/core/cache_spec.lua
-- Cache subsystem: key computation, tier load/save, invalidation, stats.

local R = require("spec._runner")

R.describe("core.compiler.cache", function()
  local cache = require("core.compiler.cache")
  local policy = require("core.compiler.cache.policy")
  local ver = require("core.compiler.cache.version")

  -- ── Serializability ────────────────────────────────────────────────────────
  R.describe("is_cacheable()", function()
    R.it("plain table is cacheable", function()
      R.assert_true(policy.is_cacheable({ a = 1, b = { c = 2 } }))
    end)
    R.it("table with function is NOT cacheable", function()
      R.assert_false(policy.is_cacheable({ fn = function() end }))
    end)
    R.it("nested function is NOT cacheable", function()
      R.assert_false(policy.is_cacheable({ n = { fn = function() end } }))
    end)
    R.it("mark_uncacheable table is NOT cacheable", function()
      R.assert_false(policy.is_cacheable(cache.mark_uncacheable({})))
    end)
    R.it("_no_cache field → NOT cacheable", function()
      R.assert_false(policy.is_cacheable({ _no_cache = true, data = 1 }))
    end)
  end)

  -- ── Cache version ──────────────────────────────────────────────────────────
  R.describe("version", function()
    R.it("CACHE_VERSION == SCHEMA_VERSION", function()
      R.assert_eq(ver.CACHE_VERSION, ver.SCHEMA_VERSION)
    end)
    R.it("version >= 7 (P6-C4)", function()
      R.assert_true(ver.CACHE_VERSION >= 7)
    end)
  end)

  -- ── Tier structure ─────────────────────────────────────────────────────────
  R.describe("tier layout", function()
    R.it("ast and spec tiers exist; no 'ir' tier", function()
      local files = require("core.compiler.cache.store").tier_files()
      R.assert_not_nil(files.ast)
      R.assert_not_nil(files.spec)
      R.assert_nil(files.ir)
    end)
  end)

  -- ── Save / Load round-trip ─────────────────────────────────────────────────
  R.describe("save() / load()", function()
    local function fresh_key()
      return "test-" .. tostring(os.clock()) .. "-" .. tostring(math.random(1e6))
    end

    R.it("round-trip preserves payload structure", function()
      local k = fresh_key()
      local payload = { specs = { { "plugin/a" }, { "plugin/b" } }, v = 1 }
      R.assert_true(cache.save("spec", k, payload))
      local loaded = cache.load("spec", k)
      R.assert_not_nil(loaded)
      R.assert_eq(#loaded.specs, 2)
    end)

    R.it("load returns nil for wrong key", function()
      local k = fresh_key()
      cache.save("spec", k, { data = "x" })
      R.assert_nil(cache.load("spec", "wrong-key-xyz"))
    end)

    R.it("save returns false for non-cacheable payload", function()
      R.assert_false(cache.save("spec", fresh_key(), { fn = function() end }))
    end)

    R.it("save returns false for empty key", function()
      R.assert_false(cache.save("spec", "", { data = 1 }))
    end)
  end)

  -- ── Invalidation ──────────────────────────────────────────────────────────
  R.describe("invalidate()", function()
    local function fresh_key()
      return "inv-" .. tostring(os.clock()) .. tostring(math.random(1e6))
    end

    R.it("invalidate('ast') removes ast and spec (downstream)", function()
      local k = fresh_key()
      cache.save("ast", k, { a = 1 })
      cache.save("spec", k, { c = 3 })
      cache.invalidate("ast")
      R.assert_nil(cache.load("ast", k))
      R.assert_nil(cache.load("spec", k))
    end)

    R.it("invalidate_all() removes all tiers", function()
      local k = fresh_key()
      cache.save("ast", k, { a = 1 })
      cache.save("spec", k, { c = 3 })
      cache.invalidate_all()
      R.assert_nil(cache.load("ast", k))
      R.assert_nil(cache.load("spec", k))
    end)
  end)

  -- ── Stats ─────────────────────────────────────────────────────────────────
  R.describe("stats()", function()
    R.it("returns table", function()
      R.assert_type(cache.stats(), "table")
    end)

    R.it("tracks hits after successful load", function()
      local k = "stats-" .. tostring(os.clock())
      cache.save("spec", k, { x = 1 })
      cache.load("spec", k)
      local s = cache.stats()
      R.assert_not_nil(s.spec)
      R.assert_true((s.spec.hits or 0) >= 1)
    end)

    R.it("tracks misses for unknown key", function()
      cache.load("spec", "definitely-missing-" .. math.random(1e9))
      local s = cache.stats()
      R.assert_true((s.spec and s.spec.misses or 0) >= 1)
    end)
  end)

  -- ── Key computation ────────────────────────────────────────────────────────
  R.describe("key computation", function()
    local key_mod = require("core.compiler.cache.key")

    R.it("different profiles → different keys", function()
      local k1 = key_mod.compute({ "modules.lang.lua_lang" }, "full")
      local k2 = key_mod.compute({ "modules.lang.lua_lang" }, "minimal")
      if k1 == "" or k2 == "" then
        return
      end -- module not in rtp
      R.assert_ne(k1, k2)
    end)

    R.it("key ends with schema version :vN", function()
      local k = key_mod.compute({ "modules.lang.lua_lang" }, "full")
      if k == "" then
        return
      end
      R.assert_match(k, ":v%d+$")
    end)

    R.it("empty module list → empty key", function()
      R.assert_eq(key_mod.compute({}, "full"), "")
    end)

    R.it("deterministic for same inputs", function()
      local k1 = key_mod.compute({ "modules.lang.lua_lang" }, "full")
      local k2 = key_mod.compute({ "modules.lang.lua_lang" }, "full")
      R.assert_eq(k1, k2)
    end)

    R.it("cap_modules affect cache key (P6-A2)", function()
      local caps = require("runtime.passes.collect_ext").registered()
      local k1 = key_mod.compute({ "modules.lang.python" }, "full", caps)
      local k2 = key_mod.compute({ "modules.lang.python" }, "full", {})
      R.assert_ne(k1, k2)
    end)
  end)

  -- ── Shorthands ─────────────────────────────────────────────────────────────
  R.describe("load_specs / save_specs", function()
    R.it("round-trip via shorthands", function()
      local k = "sh-" .. tostring(os.clock())
      local specs = { { "plugin/x" } }
      cache.save_specs(k, specs)
      local loaded = cache.load_specs(k)
      R.assert_not_nil(loaded)
      R.assert_eq(#loaded, 1)
    end)
  end)
end)
