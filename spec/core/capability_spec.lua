-- spec/core/capability_spec.lua
-- core.domain.capability: immutable CapabilitySet (COW semantics).

local R = require("spec._runner")

R.describe("core.domain.capability", function()
  local cap = require("core.domain.capability")
  local F = require("spec._fixtures.ir")

  -- ── new() ─────────────────────────────────────────────────────────────────

  R.describe("new()", function()
    R.it("returns an empty table", function()
      local s = cap.new()
      R.assert_type(s, "table")
      R.assert_true(next(s) == nil)
    end)
  end)

  -- ── add() ─────────────────────────────────────────────────────────────────

  R.describe("add()", function()
    R.it("returns NEW set; input set is unchanged", function()
      local s0 = cap.new()
      local s1, result = cap.add(s0, "lua", F.lua_cap())
      R.assert_true(result.ok)
      R.assert_ne(s1, s0)
      R.assert_true(next(s0) == nil)
      R.assert_not_nil(s1.lua)
    end)

    R.it("merges treesitter lists across two adds for same module", function()
      local s = cap.new()
      s = cap.add(s, "lang", { treesitter = { "lua" } })
      s = cap.add(s, "lang", { treesitter = { "python" } })
      R.assert_eq(#s.lang.treesitter, 2)
    end)

    R.it("deep-merges LSP configs (right wins on scalar conflict)", function()
      local s = cap.new()
      s = cap.add(s, "l", { lsp = { lua_ls = { settings = { a = 1 } } } })
      s = cap.add(s, "l", { lsp = { lua_ls = { settings = { b = 2 } } } })
      R.assert_eq(s.l.lsp.lua_ls.settings.a, 1)
      R.assert_eq(s.l.lsp.lua_ls.settings.b, 2)
    end)

    R.it("returns ok=false and original set for invalid cap", function()
      local s0 = cap.new()
      local s1, result = cap.add(s0, "bad", "not_a_table")
      R.assert_false(result.ok)
      R.assert_eq(s1, s0)
    end)

    R.it("appends formatter lists per filetype", function()
      local s = cap.new()
      s = cap.add(s, "l", { formatters = { lua = { "stylua" } } })
      s = cap.add(s, "l", { formatters = { lua = { "lua_format" } } })
      R.assert_eq(#s.l.formatters.lua, 2)
    end)
  end)

  -- ── snapshot() ────────────────────────────────────────────────────────────

  R.describe("snapshot()", function()
    R.it("returns deep-copy; mutations don't affect the source set", function()
      local s = cap.add(cap.new(), "l", { treesitter = { "lua" } })
      local snap = cap.snapshot(s)
      snap.l.treesitter[1] = "MUTATED"
      R.assert_eq(s.l.treesitter[1], "lua")
    end)
  end)

  -- ── reset() backward-compat ───────────────────────────────────────────────

  R.describe("reset() backward-compat", function()
    R.it("is a no-op (does not error)", function() cap.reset() end)
  end)

  -- ── golden: lua DSL round-trip ───────────────────────────────────────

  R.describe("golden: lua DSL", function()
    R.it("produces expected capability shape from real module", function()
      local ok, lua = pcall(require, "modules.lang.lua")
      R.assert_true(ok, "modules.lang.lua must load cleanly")
      local s, result = cap.add(cap.new(), "lua", lua)
      R.assert_true(result.ok)
      local c = s.lua
      R.assert_not_nil(c)
      R.assert_not_nil(c.lsp and c.lsp.lua_ls)
      R.assert_not_nil(c.formatters and c.formatters.lua)
      R.assert_true(c.treesitter and #c.treesitter > 0)
    end)
  end)
end)