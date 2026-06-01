-- lua/spec/runtime/pipeline_spec.lua (shim)
-- Delegates to canonical spec; keeps old SPEC_MODULES entry working.
local R = require("spec._runner")

return {
  test_collect_ext = function()
    local collect_ext = require("runtime.passes.collect_ext")
    local ir_mod = require("core.compiler.ir")
    R.assert_true(#collect_ext.registered() >= 5)
    local ir = collect_ext.pass.run(ir_mod.new({ "modules.lang.lua_lang" }, "full"))
    R.assert_true(next(ir.ext_caps.image) ~= nil)
  end,

  test_cap_resolve = function()
    local ir_mod = require("core.compiler.ir")
    local ir = require("runtime.passes.collect_ext").pass.run(ir_mod.new({}, "full"))
    ir = require("runtime.passes.cap_resolve").pass.run(ir)
    R.assert_type(ir.cap_specs.image, "table")
  end,

  test_cap_registry = function()
    local reg = require("runtime.adapters.cap_registry")
    R.assert_true(#reg.list() >= 4)
    R.assert_not_nil(reg.get("image"))
  end,

  test_lifecycle = function()
    local lc = require("runtime.lifecycle")
    lc._reset()
    R.assert_eq(lc.state(), "BOOT")
    R.assert_true(lc.transition("SCHEMA_LOAD"))
    R.assert_true(lc.transition("COMPILE"))
    R.assert_true(lc.transition("EMIT"))
    R.assert_true(lc.transition("READY"))
    R.assert_true(lc.is_ready())
  end,

  test_pipeline_phases = function()
    local pipeline = require("runtime.pipeline")
    local function has_phase(name)
      for _, p in ipairs(pipeline.PHASE_ORDER) do
        if p == name then
          return true
        end
      end
      return false
    end
    R.assert_true(#pipeline.PHASE_ORDER >= 7)
    local required = {
      "collect",
      "collect_ext",
      "normalize",
      "canonicalize",
      "resolve",
      "optimize",
      "cap_resolve",
      "codegen",
    }
    for _, name in ipairs(required) do
      R.assert_true(has_phase(name), name .. " must be present")
    end
    R.assert_eq(pipeline.PHASE_ORDER[1], "collect")
  end,

  test_adapter_registry = function()
    local reg = require("runtime.adapters.registry")
    R.assert_eq(reg.list()[1], "runtime.adapters.lsp")
  end,

  test_runtime_build = function()
    local runtime = require("runtime")
    local specs = runtime.build()
    R.assert_true(#specs > 0)
  end,
}
