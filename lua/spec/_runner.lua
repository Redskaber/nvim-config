-- lua/spec/_runner.lua
-- Backward-compatibility shim: re-exports the canonical runner from spec/_runner.lua.
-- Old-style lua/spec/* modules can still use R.assert_eq etc.
return require("spec._runner")
