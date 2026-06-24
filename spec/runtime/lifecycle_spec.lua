-- spec/runtime/lifecycle_spec.lua
-- runtime.lifecycle: coarse-grained SM, independent of pipeline SM (Invariant 14).

local R = require("spec._runner")

R.describe("runtime.lifecycle", function()
  -- Fresh module instance per test group (avoids shared state)
  local function fresh()
    package.loaded["runtime.lifecycle"] = nil
    return require("runtime.lifecycle")
  end

  -- ── initial state ──────────────────────────────────────────────────────────

  R.describe("initial state", function()
    R.it("starts in BOOT state", function() R.assert_eq(fresh().state(), "BOOT") end)
    R.it("is_ready() = false initially", function() R.assert_false(fresh().is_ready()) end)
    R.it("is_error() = false initially", function() R.assert_false(fresh().is_error()) end)
    R.it(
      "last_fail_reason() = nil initially",
      function() R.assert_nil(fresh().last_fail_reason()) end
    )
  end)

  -- ── happy path ────────────────────────────────────────────────────────────

  R.describe("forward transitions", function()
    R.it("BOOT → SCHEMA_LOAD → COMPILE → EMIT → READY succeeds", function()
      local lc = fresh()
      for _, s in ipairs({
        lc.STATES.SCHEMA_LOAD,
        lc.STATES.COMPILE,
        lc.STATES.EMIT,
        lc.STATES.READY,
      }) do
        R.assert_true(lc.transition(s))
      end
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

  -- ── illegal transitions ───────────────────────────────────────────────────

  R.describe("illegal transitions → ERROR", function()
    R.it("BOOT → COMPILE (skips SCHEMA_LOAD) → state=ERROR", function()
      local lc = fresh()
      R.assert_false(lc.transition(lc.STATES.COMPILE))
      R.assert_true(lc.is_error())
    end)
    R.it("COMPILE → READY (skips EMIT) → state=ERROR", function()
      local lc = fresh()
      lc.transition(lc.STATES.SCHEMA_LOAD)
      lc.transition(lc.STATES.COMPILE)
      R.assert_false(lc.transition(lc.STATES.READY))
    end)
    R.it("SCHEMA_LOAD → READY (skips COMPILE+EMIT) → state=ERROR", function()
      local lc = fresh()
      lc.transition(lc.STATES.SCHEMA_LOAD)
      R.assert_false(lc.transition(lc.STATES.READY))
    end)
  end)

  -- ── ERROR is terminal ─────────────────────────────────────────────────────

  R.describe("ERROR terminal", function()
    R.it("no forward transitions from ERROR", function()
      local lc = fresh()
      lc.fail("test reason")
      for _, s in pairs(lc.STATES) do
        R.assert_false(lc.transition(s))
        R.assert_true(lc.is_error())
      end
    end)

    R.it("fail() records reason", function()
      local lc = fresh()
      lc.fail("disk full")
      R.assert_eq(lc.last_fail_reason(), "disk full")
    end)

    R.it("any non-BOOT state can transition to ERROR", function()
      local lc = fresh()
      lc.transition(lc.STATES.SCHEMA_LOAD)
      R.assert_true(lc.transition(lc.STATES.ERROR))
      R.assert_true(lc.is_error())
    end)
  end)

  -- ── observer API ─────────────────────────────────────────────────────────

  R.describe("observe()", function()
    R.it("callback receives (new_state, prev_state)", function()
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

    R.it("multiple observers all invoked", function()
      local lc = fresh()
      local count = 0
      lc.observe(function() count = count + 1 end)
      lc.observe(function() count = count + 1 end)
      lc.transition(lc.STATES.SCHEMA_LOAD)
      R.assert_eq(count, 2)
    end)

    R.it("observer error does not abort the transition", function()
      local lc = fresh()
      lc.observe(function() error("boom") end)
      R.assert_true(lc.transition(lc.STATES.SCHEMA_LOAD))
      R.assert_eq(lc.state(), lc.STATES.SCHEMA_LOAD)
    end)

    R.it("observer fires on ERROR transition (fail())", function()
      local lc = fresh()
      local saw_error = false
      lc.observe(function(n)
        if n == "ERROR" then
          saw_error = true
        end
      end)
      lc.fail("reason")
      R.assert_true(saw_error)
    end)
  end)

  -- ── timestamps ────────────────────────────────────────────────────────────

  R.describe("timestamps()", function()
    R.it(
      "contains boot entry as number",
      function() R.assert_type(fresh().timestamps().boot, "number") end
    )
    R.it("schema_load timestamp added after transition", function()
      local lc = fresh()
      lc.transition(lc.STATES.SCHEMA_LOAD)
      R.assert_type(lc.timestamps().schema_load, "number")
    end)
    R.it("elapsed(BOOT) >= 0", function()
      local lc = fresh()
      local e = lc.elapsed("BOOT")
      R.assert_type(e, "number")
      R.assert_true(e >= 0)
    end)
    R.it(
      "elapsed() returns nil for future (not-yet-visited) state",
      function() R.assert_nil(fresh().elapsed("READY")) end
    )
  end)

  -- ── STATES enum ───────────────────────────────────────────────────────────

  R.describe("STATES enum completeness", function()
    R.it("all seven state constants defined", function()
      local lc = fresh()
      for _, s in ipairs({
        "BOOT",
        "SCHEMA_LOAD",
        "COMPILE",
        "EMIT",
        "READY",
        "HOT_RELOAD",
        "ERROR",
      }) do
        R.assert_not_nil(lc.STATES[s], "STATES." .. s .. " must exist")
      end
    end)
  end)

  -- ── api.on_ready / on_lifecycle_change (P6-C1) ────────────────────────────

  R.describe("runtime.api lifecycle hooks (P6-C1)", function()
    R.it("on_ready() callback fires when state reaches READY", function()
      package.loaded["runtime.lifecycle"] = nil
      local lc = require("runtime.lifecycle")
      local api = require("runtime.api")
      local fired = false
      api.on_ready(function() fired = true end)
      for _, s in ipairs({
        lc.STATES.SCHEMA_LOAD,
        lc.STATES.COMPILE,
        lc.STATES.EMIT,
        lc.STATES.READY,
      }) do
        lc.transition(s)
      end
      R.assert_true(fired, "on_ready callback must fire when READY reached")
    end)

    R.it("on_lifecycle_change() callback fires on each transition", function()
      package.loaded["runtime.lifecycle"] = nil
      local lc = require("runtime.lifecycle")
      local api = require("runtime.api")
      local count = 0
      api.on_lifecycle_change(function() count = count + 1 end)
      lc.transition(lc.STATES.SCHEMA_LOAD)
      lc.transition(lc.STATES.COMPILE)
      R.assert_true(count >= 2)
    end)
  end)

  -- ── Invariant 14: independence from pipeline SM ───────────────────────────

  R.describe("Invariant 14: lifecycle SM independent from pipeline SM", function()
    R.it("pipeline.run() does not alter lifecycle state", function()
      local lc = fresh()
      local pipeline = require("runtime.pipeline")
      local before = lc.state()
      pipeline.run({ "modules.lang.lua" }, "full")
      R.assert_eq(lc.state(), before, "pipeline.run must not advance the lifecycle SM")
    end)
  end)
end)

