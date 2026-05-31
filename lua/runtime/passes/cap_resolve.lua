-- lua/runtime/passes/cap_resolve.lua
-- P3: Resolves external capabilities into LazySpecs.

local M = {}

local ir_mod = require("core.compiler.ir")
local util = require("core.kernel.util")

-- Placeholder for CapAdapterRegistry. This will be a separate module.
-- For now, we'll simulate it or require it if it exists.
local CAP_ADAPTER_REGISTRY = {}
local ok, temp_reg = pcall(require, "runtime.adapters.cap_registry")
if ok then
  CAP_ADAPTER_REGISTRY = temp_reg
else
  -- Mock registry for development if the actual registry isn't built yet
  CAP_ADAPTER_REGISTRY.get = function(cap_type)
    -- In a real scenario, this would load the specific adapter for cap_type
    if cap_type == "image" then
      return require("runtime.adapters.image")
    elseif cap_type == "ai" then
      return require("runtime.adapters.ai_cap")
    elseif cap_type == "media" then
      return require("runtime.adapters.media")
    elseif cap_type == "keybind" then
      return require("runtime.adapters.keybind")
    end
    return nil
  end
end

M.pass = {
  name = "cap_resolve",
  input_state = "optimizing",
  output_state = "optimizing", -- sub-pass, same SM state

  --- Run the cap_resolve pass.
  --- Converts ir.ext_caps into ir.cap_specs (LazySpec[]).
  ---@param ir IR
  ---@return IR
  run = function(ir)
    local next_ir = ir_mod.with(ir, { cap_specs = ir_mod.deep_copy(ir.cap_specs or {}) })
    local diagnostics = ir_mod.deep_copy(ir.diagnostics)

    if not ir.ext_caps then
      return next_ir
    end

    for cap_type, caps_by_mod_name in pairs(ir.ext_caps) do
      local adapter = CAP_ADAPTER_REGISTRY.get(cap_type)

      if not adapter then
        table.insert(diagnostics, ir_mod.diag(
          next_ir.stage, cap_type, ("No capability adapter registered for cap_type '%s'."):format(cap_type), "warn"
        ))
        goto continue
      end

      local resolved_specs
      local ok, res = pcall(adapter.build, adapter, next_ir, caps_by_mod_name)
      if ok then
        resolved_specs = res
      else
        table.insert(diagnostics, ir_mod.diag(
          next_ir.stage, cap_type, ("Capability adapter for '%s' failed to build specs: %s"):format(cap_type, tostring(res)), "error"
        ))
        resolved_specs = {}
      end
      next_ir.cap_specs[cap_type] = resolved_specs

      ::continue::
    end

    next_ir = ir_mod.with(next_ir, { diagnostics = diagnostics })
    return next_ir
  end,
}

return M
