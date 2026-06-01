-- spec/runtime/lifecycle_spec.lua
-- runtime.lifecycle: coarse-grained runtime SM (Invariant 14).

local R = require("spec._runner")

R.describe("runtime.lifecycle", function()
  local function fresh()
    package.loaded["runtime.lifecycle"] = nil
    return require("runtime.lifecycle")
  end

  -- ── Initial state ──────────────────────────────────────────────────────────
  R.describe("initial state", function()
    R.it("starts BOOT", function()
      R.assert_eq(fresh().state(), "BOOT")
    end)
    R.it("not ready initially", function()
      R.assert_false(fresh().is_ready())
    end)
    R.it("not error initially", function()
      R.assert_false(fresh().is_error())
    end)
  end)

  -- ── Happy path ─────────────────────────────────────────────────────────────
  R.describe("forward transitions", function()
    R.it("BOOT → SCHEMA_LOAD → COMPILE → EMIT → READY", function()
      local lc = fresh()
      R.assert_true(lc.transition(lc.STATES.SCHEMA_LOAD))
      R.assert_true(lc.transition(lc.STATES.COMPILE))
      R.assert_true(lc.transition(lc.STATES.EMIT))
      R.assert_true(lc.transition(lc.STATES.READY))
      R.assert_true(lc.is_ready())
    end)

    R.it("READY → HOT_RELOAD → SCHEMA_LOAD re-enters cycle", function()
      local lc = fresh()
      for _, s in ipairs({
        lc.STATES.SCHEMA_LOAD,
        lc.STATES.COMPILE,
        lc.STATES.EMIT,
        lc.STATES.READY,
      }) do
        lc.transition(s)
      end
      R.assert_true(lc.transition(lc.STATES.HOT_RELOAD))
      R.assert_true(lc.transition(lc.STATES.SCHEMA_LOAD))
    end)
  end)

  -- ── Illegal transitions ────────────────────────────────────────────────────
  R.describe("illegal transitions", function()
    R.it("BOOT → COMPILE (skips SCHEMA_LOAD) → ERROR", function()
      local lc = fresh()
      R.assert_false(lc.transition(lc.STATES.COMPILE))
      R.assert_true(lc.is_error())
    end)
    R.it("COMPILE → READY (skips EMIT) → ERROR", function()
      local lc = fresh()
      lc.transition(lc.STATES.SCHEMA_LOAD)
      lc.transition(lc.STATES.COMPILE)
      R.assert_false(lc.transition(lc.STATES.READY))
    end)
  end)

  -- ── ERROR is terminal ──────────────────────────────────────────────────────
  R.describe("ERROR terminal", function()
    R.it("no transitions from ERROR", function()
      local lc = fresh()
      lc.fail("test")
      for _, s in pairs(lc.STATES) do
        R.assert_false(lc.transition(s))
        R.assert_true(lc.is_error())
      end
    end)

    R.it("any state → ERROR via explicit transition", function()
      local setups = {
        function(lc) end,
        function(lc)
          lc.transition(lc.STATES.SCHEMA_LOAD)
        end,
        function(lc)
          lc.transition(lc.STATES.SCHEMA_LOAD)
          lc.transition(lc.STATES.COMPILE)
        end,
      }
      for _, setup in ipairs(setups) do
        local lc = fresh()
        setup(lc)
        R.assert_true(lc.transition(lc.STATES.ERROR))
        R.assert_true(lc.is_error())
      end
    end)
  end)

  -- ── Observer API ───────────────────────────────────────────────────────────
  R.describe("observe()", function()
    R.it("callback receives new and prev state", function()
      local lc = fresh()
      local got_new, got_prev
      lc.observe(function(n, p)
        got_new = n
        got_prev = p
      end)
      lc.transition(lc.STATES.SCHEMA_LOAD)
      R.assert_eq(got_new, lc.STATES.SCHEMA_LOAD)
      R.assert_eq(got_prev, lc.STATES.BOOT)
    end)

    R.it("multiple observers all called", function()
      local lc = fresh()
      local count = 0
      lc.observe(function()
        count = count + 1
      end)
      lc.observe(function()
        count = count + 1
      end)
      lc.transition(lc.STATES.SCHEMA_LOAD)
      R.assert_eq(count, 2)
    end)

    R.it("observer error does not abort transition", function()
      local lc = fresh()
      lc.observe(function()
        error("boom")
      end)
      R.assert_true(lc.transition(lc.STATES.SCHEMA_LOAD))
      R.assert_eq(lc.state(), lc.STATES.SCHEMA_LOAD)
    end)
  end)

  -- ── Timestamps ─────────────────────────────────────────────────────────────
  R.describe("timestamps()", function()
    R.it("contains boot entry", function()
      R.assert_type(fresh().timestamps().boot, "number")
    end)
    R.it("updated after transition", function()
      local lc = fresh()
      lc.transition(lc.STATES.SCHEMA_LOAD)
      R.assert_type(lc.timestamps().schema_load, "number")
    end)
    R.it("elapsed() nil for future state", function()
      R.assert_nil(fresh().elapsed("READY"))
    end)
    R.it("elapsed(BOOT) >= 0", function()
      local e = fresh().elapsed("BOOT")
      R.assert_type(e, "number")
      R.assert_true(e >= 0)
    end)
  end)

  -- ── STATES enum completeness ───────────────────────────────────────────────
  R.it("STATES enum is complete", function()
    local lc = fresh()
    local expected = { "BOOT", "SCHEMA_LOAD", "COMPILE", "EMIT", "READY", "HOT_RELOAD", "ERROR" }
    for _, s in ipairs(expected) do
      R.assert_not_nil(lc.STATES[s], "STATES." .. s .. " must exist")
    end
  end)
end)
