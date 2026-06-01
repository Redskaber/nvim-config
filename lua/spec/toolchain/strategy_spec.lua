-- lua/spec/toolchain/strategy_spec.lua (shim)
local R = require("spec._runner")

return {
  test_rules = function()
    local rules = require("toolchain.rules")
    R.assert_eq(rules.resolve("gofmt", {}).use_mason, false)
  end,

  test_mappings_resolve = function()
    local mappings = require("toolchain.mappings")
    R.assert_eq(mappings.resolve("git").use_mason, false)
    R.assert_eq(mappings.resolve("ruff").use_mason, true)
  end,

  test_conflict = function()
    local conflict = require("toolchain.strategy.conflict")
    local s1 = {
      name = "a",
      priority = 10,
      applies = function()
        return true
      end,
      resolve = function()
        return "a"
      end,
    }
    local s2 = {
      name = "b",
      priority = 5,
      applies = function()
        return true
      end,
      resolve = function()
        return "b"
      end,
    }
    local r = conflict.resolve("tool", { s1, s2 })
    R.assert_eq(r.winner.name, "a")
  end,
}
