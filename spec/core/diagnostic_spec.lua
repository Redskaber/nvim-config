-- spec/core/diagnostic_spec.lua
-- core.domain.diagnostic: Layer 2 Diagnostic value type.
-- Validates: creation, determinism, severity prefixes, format, IR re-export.

local R = require("spec._runner")

R.describe("core.domain.diagnostic", function()
  local diag = require("core.domain.diagnostic")

  -- ── new() shape ────────────────────────────────────────────────────────────

  R.describe("new()", function()
    R.it("produces Diagnostic with all required fields", function()
      local d = diag.new("collect", "mod.a", "failed to load", "error")
      R.assert_eq(d.stage, "collect")
      R.assert_eq(d.node, "mod.a")
      R.assert_eq(d.message, "failed to load")
      R.assert_eq(d.severity, "error")
      R.assert_type(d.code, "string")
      R.assert_true(#d.code > 0)
      R.assert_match(d.code, "^[EWI]%x+")
    end)

    R.it("defaults severity to 'error'", function()
      local d = diag.new("s", "n", "msg")
      R.assert_eq(d.severity, "error")
    end)

    R.it(
      "error → E-prefixed code",
      function() R.assert_eq(diag.new("s", "n", "m", "error").code:sub(1, 1), "E") end
    )
    R.it(
      "warn → W-prefixed code",
      function() R.assert_eq(diag.new("s", "n", "m", "warn").code:sub(1, 1), "W") end
    )
    R.it(
      "info → I-prefixed code",
      function() R.assert_eq(diag.new("s", "n", "m", "info").code:sub(1, 1), "I") end
    )
  end)

  -- ── determinism ────────────────────────────────────────────────────────────

  R.describe("determinism", function()
    R.it("same inputs → same code across calls", function()
      local d1 = diag.new("normalize", "mod.x", "bad input", "warn")
      local d2 = diag.new("normalize", "mod.x", "bad input", "warn")
      R.assert_eq(d1.code, d2.code)
    end)
    R.it("different stage/node → different codes", function()
      local d1 = diag.new("collect", "mod.a", "err", "error")
      local d2 = diag.new("normalize", "mod.b", "err", "error")
      R.assert_ne(d1.code, d2.code)
    end)
    R.it("different messages → different codes", function()
      local d1 = diag.new("s", "n", "message-one", "error")
      local d2 = diag.new("s", "n", "message-two", "error")
      R.assert_ne(d1.code, d2.code)
    end)
  end)

  -- ── format() ──────────────────────────────────────────────────────────────

  R.describe("format()", function()
    R.it("output contains severity, stage, node", function()
      local d = diag.new("collect", "mod.x", "some error", "error")
      local out = diag.format(d)
      R.assert_match(out, "error")
      R.assert_match(out, "collect")
      R.assert_match(out, "mod.x")
    end)
  end)

  -- ── IR backward-compat re-export ──────────────────────────────────────────

  R.describe("IR re-export compatibility", function()
    R.it("ir.diag() produces identical code to diag.new()", function()
      local ir_mod = require("core.compiler.ir")
      local d1 = diag.new("s", "n", "m", "warn")
      local d2 = ir_mod.diag("s", "n", "m", "warn")
      R.assert_eq(d1.code, d2.code)
    end)
    R.it("ir.error() alias works", function()
      local ir_mod = require("core.compiler.ir")
      local d = ir_mod.error("normalize", "python", "unknown strategy")
      R.assert_eq(d.stage, "normalize")
      R.assert_type(d.code, "string")
    end)
  end)
end)