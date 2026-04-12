-- lua/runtime/passes/codegen.lua
-- REFACTOR (TODO-5.4): delegates vim API side-effects to runtime/emitter/init.lua.
-- This pass is now pure: validate IR → call emitter → return specs.

local ir_mod = require("core.compiler.ir")

local ADAPTERS = {
  "runtime.adapters.lsp",
  "runtime.adapters.mason",
  "runtime.adapters.treesitter",
  "runtime.adapters.conform",
  "runtime.adapters.lint",
}

local codegen_pass = {
  name = "codegen",
  input_state = "optimizing",
  output_state = "codegen",

  validate = function(ir)
    return ir_mod.validate(ir, "codegen")
  end,

  ---@param ir IR
  ---@return table[]  LazySpec[]
  build = function(ir)
    local emitter = require("runtime.emitter")
    return emitter.emit(ir, ADAPTERS)
  end,
}

return codegen_pass
