-- lua/runtime/passes/codegen.lua
-- REFACTOR (TODO-5.4): delegates vim API side-effects to runtime/emitter/init.lua.
-- This pass is now pure: validate IR → call emitter → return specs.
--
-- NOTE: codegen is a terminal pass — it does not return a new IR sub-layer.
-- The `run` field satisfies the Phase interface contract (pass_mod.assert_valid),
-- but the pipeline drives codegen via `build()` directly (not via run_phase).
-- `run` is provided for interface compliance and sub-pipeline use only.

local ir_mod = require("core.compiler.ir")
local ov = require("runtime.output_validate")
local util = require("core.kernel.util")

local adapter_registry = require("runtime.adapters.registry")

local codegen_pass = {
  name = "codegen",
  input_state = "optimizing",
  output_state = "codegen",

  validate = function(ir) return ir_mod.validate(ir, "codegen") end,

  -- P6-D2 (2026-06-26): post-condition — terminal pass must still have
  -- all codegen-required fields (caps + resolved + merged_lsp + all_parsers)
  output_validate = ov.codegen,

  --- Phase.run: satisfies Phase interface contract.
  --- Returns IR with stage="SPEC" and embedded specs in ir._specs.
  --- The pipeline uses build() directly; run() is for interface compliance.
  ---@param ir IR
  ---@return IR
  run = function(ir)
    local specs = adapter_registry.emit_all(ir)
    return ir_mod.with(ir, { stage = "SPEC", _specs = specs })
  end,

  --- build(): called by pipeline.lua to produce LazySpec[].
  ---@param ir IR
  ---@return table[]  LazySpec[]
  build = function(ir)
    local specs = adapter_registry.emit_all(ir)
    -- 合并 cap_resolve 产出的能力 specs
    for _, cap_specs in pairs(ir.cap_specs or {}) do
      util.list_extend(specs, cap_specs)
    end
    return specs
  end,
}

return codegen_pass