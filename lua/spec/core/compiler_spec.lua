-- lua/spec/core/compiler_spec.lua  (shim — delegates to canonical spec/)
-- Keeps existing ltos_tests.lua entry "spec.core.compiler_spec" working.

local R = require("spec._runner")

-- Re-export as flat test table so runner.run_modules_compat handles it.
-- New tests go into spec/core/ir_spec.lua, spec/core/cache_spec.lua etc.
return {
  test_cache_version = function()
    local v = require("core.compiler.cache.version")
    R.assert_eq(v.CACHE_VERSION, v.SCHEMA_VERSION, "cache version unified")
    R.assert_true(v.CACHE_VERSION >= 7, "version >= 7")
  end,

  test_ir_version_in_meta = function()
    local ir_mod = require("core.compiler.ir")
    local v = require("core.compiler.cache.version")
    local ir = ir_mod.new({}, "full")
    R.assert_type(ir.meta.ir_version, "number")
    R.assert_eq(ir.meta.ir_version, v.SCHEMA_VERSION)
  end,

  test_compiler_ports = function()
    local ports = require("core.compiler.ports")
    R.assert_type(ports.cache_dir(), "string")
  end,

  test_two_tier_cache = function()
    local store = require("core.compiler.cache.store")
    local files = store.tier_files()
    R.assert_not_nil(files.ast)
    R.assert_not_nil(files.spec)
    R.assert_nil(files.ir)
  end,

  test_cache_key_includes_caps = function()
    local key_mod = require("core.compiler.cache.key")
    local caps = require("runtime.passes.collect_ext").registered()
    local k1 = key_mod.compute({ "modules.lang.python" }, "full", caps)
    local k2 = key_mod.compute({ "modules.lang.python" }, "full", {})
    R.assert_ne(k1, k2, "cap modules must affect cache key")
  end,

  test_invariants_cow = function()
    local inv = require("core.compiler.invariants")
    local pass = require("core.compiler.pass")
    local ir = require("core.compiler.ir")
    inv.enable()
    local phase = {
      name = "test",
      input_state = "idle",
      output_state = "collecting",
      run = function(input)
        return input
      end, -- violates COW
    }
    local ok = pcall(pass.run_phase, phase, ir.new({}, "full"))
    inv.disable()
    R.assert_false(ok, "invariants must catch same-table return")
  end,

  test_pass_output_validate = function()
    local pass_mod = require("core.compiler.pass")
    local ir_mod = require("core.compiler.ir")
    local phase = {
      name = "test_post",
      input_state = "idle",
      output_state = "collecting",
      run = function(ir)
        return ir_mod.clone(ir)
      end,
      output_validate = function(_)
        return { ir_mod.diag("test_post", "output", "post condition failed", "error") }
      end,
    }
    local result, errs = pass_mod.run_phase(phase, ir_mod.new({}, "full"))
    R.assert_eq(#errs, 0, "output_validate failures must be non-fatal")
    local has_warn = false
    for _, d in ipairs(result.diagnostics) do
      if d.severity == "warn" and (d.message or ""):find("post-condition") then
        has_warn = true
        break
      end
    end
    R.assert_true(has_warn)
  end,

  test_phase_registry_after_before = function()
    local pr = require("runtime.phase_registry")
    pr._reset()
    pr.register({
      name = "b",
      input_state = "a",
      output_state = "b",
      run = function(ir)
        return ir
      end,
    }, { priority = 20, after = { "a" } })
    pr.register({
      name = "a",
      input_state = "x",
      output_state = "y",
      run = function(ir)
        return ir
      end,
    }, { priority = 10 })
    local list = pr.list()
    local pos = {}
    for i, phase in ipairs(list) do
      pos[phase.name] = i
    end
    R.assert_true(pos["a"] < pos["b"], "after constraint: a must precede b")
    -- restore
    pr._reset()
    package.loaded["runtime.pipeline"] = nil
    require("runtime.pipeline")
  end,
}
