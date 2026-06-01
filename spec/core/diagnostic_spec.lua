-- spec/core/diagnostic_spec.lua
-- core.domain.diagnostic: Layer 2 Diagnostic value type (P6-B1).

local R = require("spec._runner")

R.describe("core.domain.diagnostic", function()
  local diag_mod = require("core.domain.diagnostic")

  R.it("new() produces a Diagnostic with all required fields", function()
    local d = diag_mod.new("collect", "mod.a", "failed to load", "error")
    R.assert_eq(d.stage, "collect")
    R.assert_eq(d.node, "mod.a")
    R.assert_eq(d.message, "failed to load")
    R.assert_eq(d.severity, "error")
    R.assert_type(d.code, "string")
    R.assert_true(#d.code > 0)
    R.assert_match(d.code, "^[EWI]%x+")
  end)

  R.it("new() defaults severity to 'error'", function()
    local d = diag_mod.new("s", "n", "msg")
    R.assert_eq(d.severity, "error")
  end)

  R.it("code is deterministic (same inputs → same code)", function()
    local d1 = diag_mod.new("normalize", "mod.x", "bad input", "warn")
    local d2 = diag_mod.new("normalize", "mod.x", "bad input", "warn")
    R.assert_eq(d1.code, d2.code)
  end)

  R.it("different inputs produce different codes", function()
    local d1 = diag_mod.new("collect", "mod.a", "err1", "error")
    local d2 = diag_mod.new("normalize", "mod.b", "err2", "error")
    R.assert_ne(d1.code, d2.code)
  end)

  R.it("warn produces W-prefixed code", function()
    local d = diag_mod.new("s", "n", "m", "warn")
    R.assert_eq(d.code:sub(1, 1), "W")
  end)

  R.it("error produces E-prefixed code", function()
    local d = diag_mod.new("s", "n", "m", "error")
    R.assert_eq(d.code:sub(1, 1), "E")
  end)

  R.it("info produces I-prefixed code", function()
    local d = diag_mod.new("s", "n", "m", "info")
    R.assert_eq(d.code:sub(1, 1), "I")
  end)

  R.it("format() produces readable string", function()
    local d = diag_mod.new("collect", "mod.x", "some error", "error")
    local out = diag_mod.format(d)
    R.assert_match(out, "error")
    R.assert_match(out, "collect")
    R.assert_match(out, "mod.x")
  end)

  R.it("is re-exported from core.compiler.ir for backward compat", function()
    local ir_mod = require("core.compiler.ir")
    local d1 = diag_mod.new("s", "n", "m", "warn")
    local d2 = ir_mod.diag("s", "n", "m", "warn")
    R.assert_eq(d1.code, d2.code)
  end)
end)
