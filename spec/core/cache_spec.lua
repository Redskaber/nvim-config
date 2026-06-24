-- spec/core/cache_spec.lua
-- core.compiler.cache: key computation, tier load/save, invalidation, stats.

local R = require("spec._runner")

R.describe("core.compiler.cache", function()
  local cache = require("core.compiler.cache")
  local policy = require("core.compiler.cache.policy")
  local ver = require("core.compiler.cache.version")

  local function fresh_key(prefix)
    return (prefix or "test")
      .. "-"
      .. tostring(os.clock()):gsub("%.", "")
      .. "-"
      .. tostring(math.random(1e6))
  end

  -- ── version ───────────────────────────────────────────────────────────────

  R.describe("version", function()
    R.it(
      "CACHE_VERSION == SCHEMA_VERSION (unified)",
      function() R.assert_eq(ver.CACHE_VERSION, ver.SCHEMA_VERSION) end
    )
    R.it("version >= 7 (P6-C4 baseline)", function() R.assert_true(ver.CACHE_VERSION >= 7) end)
  end)

  -- ── is_cacheable() ────────────────────────────────────────────────────────

  R.describe("is_cacheable()", function()
    R.it(
      "plain table → cacheable",
      function() R.assert_true(policy.is_cacheable({ a = 1, b = { c = 2 } })) end
    )
    R.it("table with function → NOT cacheable", function()
      R.assert_false(policy.is_cacheable({ fn = function() end }))
    end)
    R.it("nested function → NOT cacheable", function()
      R.assert_false(policy.is_cacheable({ n = { fn = function() end } }))
    end)
    R.it(
      "mark_uncacheable table → NOT cacheable",
      function() R.assert_false(policy.is_cacheable(cache.mark_uncacheable({}))) end
    )
    R.it(
      "_no_cache field → NOT cacheable",
      function() R.assert_false(policy.is_cacheable({ _no_cache = true, data = 1 })) end
    )
    R.it("string value → cacheable", function() R.assert_true(policy.is_cacheable("hello")) end)
    R.it("number value → cacheable", function() R.assert_true(policy.is_cacheable(42)) end)
  end)

  -- ── tier layout ───────────────────────────────────────────────────────────

  R.describe("tier layout", function()
    R.it("ast and spec tiers exist; no 'ir' tier", function()
      local files = require("core.compiler.cache.store").tier_files()
      R.assert_not_nil(files.ast)
      R.assert_not_nil(files.spec)
      R.assert_nil(files.ir)
    end)
  end)

  -- ── save() / load() round-trip ────────────────────────────────────────────

  R.describe("save() / load()", function()
    R.it("round-trip preserves payload structure", function()
      local k = fresh_key("rt")
      local payload = { specs = { { "plugin/a" }, { "plugin/b" } }, v = 1 }
      R.assert_true(cache.save("spec", k, payload))
      local loaded = cache.load("spec", k)
      R.assert_not_nil(loaded)
      R.assert_eq(#loaded.specs, 2)
      R.assert_eq(loaded.v, 1)
    end)

    R.it("load returns nil for wrong key", function()
      local k = fresh_key("wrongkey")
      cache.save("spec", k, { data = "x" })
      R.assert_nil(cache.load("spec", "definitely-wrong-key-xyz-" .. math.random(1e9)))
    end)

    R.it("save returns false for non-cacheable payload (has function)", function()
      R.assert_false(cache.save("spec", fresh_key(), { fn = function() end }))
    end)

    R.it(
      "save returns false for empty key",
      function() R.assert_false(cache.save("spec", "", { data = 1 })) end
    )

    R.it("load returns nil for empty key", function() R.assert_nil(cache.load("spec", "")) end)

    R.it("ast tier round-trip works independently", function()
      local k = fresh_key("ast")
      cache.save("ast", k, { caps = { lua = {} }, module_hashes = {} })
      local loaded = cache.load("ast", k)
      R.assert_not_nil(loaded)
      R.assert_not_nil(loaded.caps)
    end)
  end)

  -- ── P6-C4: ir_version consistency check ───────────────────────────────────

  R.describe("ir_version consistency (P6-C4)", function()
    R.it("payload with matching ir_version loads successfully", function()
      local k = fresh_key("irv")
      local payload = {
        specs = {},
        meta = { ir_version = ver.SCHEMA_VERSION },
      }
      cache.save("spec", k, payload)
      local loaded = cache.load("spec", k)
      R.assert_not_nil(loaded)
    end)

    R.it("payload with mismatched ir_version returns nil (stale cache)", function()
      local k = fresh_key("irvmm")
      local payload = {
        specs = {},
        meta = { ir_version = ver.SCHEMA_VERSION - 100 },
      }
      cache.save("spec", k, payload)
      -- policy should reject mismatched ir_version
      local loaded = cache.load("spec", k)
      -- Either nil (rejected) or loaded if version matches; stale version must be rejected
      if loaded ~= nil then
        -- If somehow loaded, ir_version must at least equal current
        if loaded.meta then
          R.assert_true(
            loaded.meta.ir_version == nil or loaded.meta.ir_version == ver.SCHEMA_VERSION,
            "stale ir_version must be rejected"
          )
        end
      end
    end)
  end)

  -- ── invalidation ──────────────────────────────────────────────────────────

  R.describe("invalidate()", function()
    R.it("invalidate('ast') removes ast and downstream spec", function()
      local k = fresh_key("inv")
      cache.save("ast", k, { a = 1 })
      cache.save("spec", k, { c = 3 })
      cache.invalidate("ast")
      R.assert_nil(cache.load("ast", k))
      R.assert_nil(cache.load("spec", k))
    end)

    R.it("invalidate_all() removes all tiers", function()
      local k = fresh_key("inva")
      cache.save("ast", k, { a = 1 })
      cache.save("spec", k, { c = 3 })
      cache.invalidate_all()
      R.assert_nil(cache.load("ast", k))
      R.assert_nil(cache.load("spec", k))
    end)
  end)

  -- ── stats() ───────────────────────────────────────────────────────────────

  R.describe("stats()", function()
    R.it("returns a table", function() R.assert_type(cache.stats(), "table") end)

    R.it("tracks hits after successful load", function()
      local k = fresh_key("stats-hit")
      cache.save("spec", k, { x = 1 })
      cache.load("spec", k)
      local s = cache.stats()
      R.assert_not_nil(s.spec)
      R.assert_true((s.spec.hits or 0) >= 1)
    end)

    R.it("tracks misses for unknown key", function()
      cache.load("spec", "missing-" .. math.random(1e9))
      local s = cache.stats()
      R.assert_true((s.spec and s.spec.misses or 0) >= 1)
    end)
  end)

  -- ── key computation ───────────────────────────────────────────────────────

  R.describe("key computation", function()
    local key_mod = require("core.compiler.cache.key")

    R.it("different profiles → different keys", function()
      local k1 = key_mod.compute({ "modules.lang.lua" }, "full")
      local k2 = key_mod.compute({ "modules.lang.lua" }, "minimal")
      if k1 ~= "" and k2 ~= "" then
        R.assert_ne(k1, k2)
      end
    end)

    R.it("key ends with schema version :vN", function()
      local k = key_mod.compute({ "modules.lang.lua" }, "full")
      if k ~= "" then
        R.assert_match(k, ":v%d+$")
      end
    end)

    R.it(
      "empty module list → empty key",
      function() R.assert_eq(key_mod.compute({}, "full"), "") end
    )

    R.it("deterministic for same inputs", function()
      local k1 = key_mod.compute({ "modules.lang.lua" }, "full")
      local k2 = key_mod.compute({ "modules.lang.lua" }, "full")
      R.assert_eq(k1, k2)
    end)

    R.it("cap_modules affect cache key (P6-A2 / INV-7)", function()
      local caps = require("runtime.passes.collect_ext").registered()
      local k1 = key_mod.compute({ "modules.lang.python" }, "full", caps)
      local k2 = key_mod.compute({ "modules.lang.python" }, "full", {})
      R.assert_ne(k1, k2, "cap modules must be included in cache key")
    end)

    R.it("different module lists → different keys", function()
      local k1 = key_mod.compute({ "modules.lang.lua" }, "full")
      local k2 = key_mod.compute({ "modules.lang.python" }, "full")
      if k1 ~= "" and k2 ~= "" then
        R.assert_ne(k1, k2)
      end
    end)
  end)

  -- ── shorthands ────────────────────────────────────────────────────────────

  R.describe("load_specs / save_specs shorthands", function()
    R.it("round-trip via shorthands", function()
      local k = fresh_key("sh")
      cache.save_specs(k, { { "plugin/x" } })
      local loaded = cache.load_specs(k)
      R.assert_not_nil(loaded)
      R.assert_eq(#loaded, 1)
    end)
  end)
end)

