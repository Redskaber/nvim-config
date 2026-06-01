-- spec/core/util_spec.lua
-- core.kernel.util: pure utility functions.

local R = require("spec._runner")

R.describe("core.kernel.util", function()
  local util = require("core.kernel.util")

  -- ── dedup ──────────────────────────────────────────────────────────────────
  R.describe("dedup()", function()
    R.it("empty list → empty list", function()
      R.assert_eq(#util.dedup({}), 0)
    end)
    R.it("no duplicates → same order", function()
      local r = util.dedup({ "a", "b", "c" })
      R.assert_eq(r[1], "a")
      R.assert_eq(r[2], "b")
      R.assert_eq(r[3], "c")
    end)
    R.it("removes duplicates, keeps first", function()
      local r = util.dedup({ "a", "b", "a", "c", "b" })
      R.assert_eq(#r, 3)
      R.assert_eq(r[1], "a")
      R.assert_eq(r[2], "b")
      R.assert_eq(r[3], "c")
    end)
    R.it("works with integers", function()
      local r = util.dedup({ 1, 2, 1, 3 })
      R.assert_eq(#r, 3)
    end)
    R.it("does not mutate input", function()
      local input = { "x", "x", "y" }
      util.dedup(input)
      R.assert_eq(#input, 3)
    end)
  end)

  -- ── merge / deep_merge ─────────────────────────────────────────────────────
  R.describe("merge()", function()
    R.it("right wins on conflict", function()
      local r = util.merge({ a = 1, b = 2 }, { b = 99, c = 3 })
      R.assert_eq(r.a, 1)
      R.assert_eq(r.b, 99)
      R.assert_eq(r.c, 3)
    end)
    R.it("does not mutate either input", function()
      local a, b = { x = 1 }, { y = 2 }
      util.merge(a, b)
      R.assert_nil(a.y)
      R.assert_nil(b.x)
    end)
  end)

  R.describe("deep_merge()", function()
    R.it("nested tables merged recursively", function()
      local r = util.deep_merge({ s = { a = 1, b = 2 } }, { s = { b = 99, c = 3 } })
      R.assert_eq(r.s.a, 1)
      R.assert_eq(r.s.b, 99)
      R.assert_eq(r.s.c, 3)
    end)
    R.it("does not mutate inputs", function()
      local a, b = { x = { v = 1 } }, { x = { w = 2 } }
      util.deep_merge(a, b)
      R.assert_nil(a.x.w)
      R.assert_nil(b.x.v)
    end)
    R.it("scalar from b overrides table from a", function()
      local r = util.deep_merge({ a = { nested = true } }, { a = 42 })
      R.assert_eq(r.a, 42)
    end)
  end)

  -- ── deep_equal ─────────────────────────────────────────────────────────────
  R.describe("deep_equal()", function()
    R.it("identical scalars", function()
      R.assert_true(util.deep_equal(1, 1))
      R.assert_true(util.deep_equal("x", "x"))
    end)
    R.it("different scalars", function()
      R.assert_false(util.deep_equal(1, 2))
    end)
    R.it("identical nested tables", function()
      R.assert_true(util.deep_equal({ x = { y = 1 } }, { x = { y = 1 } }))
    end)
    R.it("different nested tables", function()
      R.assert_false(util.deep_equal({ x = { y = 1 } }, { x = { y = 2 } }))
    end)
    R.it("extra key in b → not equal", function()
      R.assert_false(util.deep_equal({ a = 1 }, { a = 1, b = 2 }))
    end)
  end)

  -- ── basename ───────────────────────────────────────────────────────────────
  R.describe("basename()", function()
    R.it("extracts last segment", function()
      R.assert_eq(util.basename("modules.lang.python"), "python")
      R.assert_eq(util.basename("core.compiler.ir"), "ir")
    end)
    R.it("single segment returns itself", function()
      R.assert_eq(util.basename("python"), "python")
    end)
  end)

  -- ── hash ───────────────────────────────────────────────────────────────────
  R.describe("hash()", function()
    R.it("returns integer", function()
      local h = util.hash("hello")
      R.assert_eq(math.floor(h), h)
    end)
    R.it("is deterministic", function()
      R.assert_eq(util.hash("test"), util.hash("test"))
    end)
    R.it("different inputs → different hashes", function()
      R.assert_ne(util.hash("abc"), util.hash("xyz"))
    end)
  end)

  -- ── freeze / unfreeze ──────────────────────────────────────────────────────
  R.describe("freeze()", function()
    R.before_each(function()
      _G._ltos_debug_freeze = false
    end)
    R.after_each(function()
      _G._ltos_debug_freeze = false
    end)

    R.it("no-op when _ltos_debug_freeze is false", function()
      local t = { a = 1 }
      R.assert_eq(util.freeze(t), t)
    end)

    R.it("write to proxy raises error", function()
      _G._ltos_debug_freeze = true
      local proxy = util.freeze({ a = 1 }, "test")
      R.assert_false(pcall(function()
        proxy.a = 99
      end))
    end)

    R.it("read through proxy works", function()
      _G._ltos_debug_freeze = true
      local t = { x = 42 }
      local proxy = util.freeze(t)
      R.assert_eq(proxy.x, 42)
    end)
  end)

  R.describe("unfreeze()", function()
    R.before_each(function()
      _G._ltos_debug_freeze = true
    end)
    R.after_each(function()
      _G._ltos_debug_freeze = false
    end)

    R.it("returns original table from proxy", function()
      local t = { z = 99 }
      local proxy = util.freeze(t, "test")
      R.assert_eq(util.unfreeze(proxy), t)
    end)

    R.it("plain table passes through unchanged", function()
      local t = { a = 1 }
      R.assert_eq(util.unfreeze(t), t)
    end)
  end)

  -- ── deep_copy ──────────────────────────────────────────────────────────────
  R.describe("deep_copy()", function()
    R.it("nested table is deep-independent", function()
      local t = { x = { y = 1 } }
      local c = util.deep_copy(t)
      c.x.y = 99
      R.assert_eq(t.x.y, 1)
    end)
    R.it("function copied by reference", function()
      local fn = function()
        return 1
      end
      R.assert_eq(util.deep_copy({ f = fn }).f, fn)
    end)
  end)
end)
