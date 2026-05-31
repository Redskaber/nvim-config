-- lua/runtime/passes/cap_resolve.lua
-- P3: Resolves external capabilities into LazySpecs via CapAdapterRegistry.

local M = {}

local ir_mod = require("core.compiler.ir")
local util = require("core.kernel.util")
local cap_registry = require("runtime.adapters.cap_registry")

M.pass = {
  name = "cap_resolve",
  input_state = "optimizing",
  output_state = "optimizing",

  ---@param ir IR
  ---@return IR
  run = function(ir)
    local next_ir = ir_mod.with(ir, { cap_specs = util.deep_copy(ir.cap_specs or {}) })
    local diagnostics = util.deep_copy(ir.diagnostics or {})

    if not ir.ext_caps then
      return next_ir
    end

    for cap_type, caps_by_mod_name in pairs(ir.ext_caps) do
      if util.tbl_isempty(caps_by_mod_name) then
        goto continue
      end

      local adapter = cap_registry.get(cap_type)
      if not adapter then
        diagnostics[#diagnostics + 1] = ir_mod.diag(
          next_ir.stage,
          cap_type,
          ("No capability adapter registered for cap_type '%s'."):format(cap_type),
          "warn"
        )
        goto continue
      end

      local ok, resolved_specs = pcall(adapter.build, adapter, next_ir, caps_by_mod_name)
      if ok then
        next_ir.cap_specs[cap_type] = resolved_specs or {}
      else
        diagnostics[#diagnostics + 1] = ir_mod.diag(
          next_ir.stage,
          cap_type,
          ("Capability adapter for '%s' failed to build specs: %s"):format(cap_type, tostring(resolved_specs)),
          "error"
        )
        next_ir.cap_specs[cap_type] = {}
      end

      ::continue::
    end

    return ir_mod.with(next_ir, { diagnostics = diagnostics })
  end,
}

return M
