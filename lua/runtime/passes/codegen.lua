-- ~/.config/nvim/lua/runtime/passes/codegen.lua
-- Compiler kernel: Phase 5 — codegen (terminal pass).
--
-- Drives all backend adapters; produces LazySpec[] (SPEC layer).
-- This phase is terminal: it returns spec[], not a new IR.
-- The pipeline runner handles this distinction.
--
-- State contract: OPTIMIZING → CODEGEN → DONE
-- IR input:  LIR layer (caps, resolved, merged_lsp, all_parsers)
-- Output:    LazySpec[]  (consumed by lazy.nvim)
--
-- Adapter interface: { build(ir: IR): LazySpec[] }
-- Adapters are isolated backend implementations; they only READ the IR.

local ir_mod = require("core.ir")

-- Ordered adapter list — order determines spec list ordering for lazy.nvim
local ADAPTERS = {
  "runtime.adapters.lsp",
  "runtime.adapters.mason",
  "runtime.adapters.treesitter",
  "runtime.adapters.conform",
  "runtime.adapters.lint",
}

---@class CodegenPhase
---@field name         string
---@field input_state  string
---@field output_state string
---@field validate     fun(ir: IR): Diagnostic[]
---@field build        fun(ir: IR): table[]   returns LazySpec[], not IR

local codegen_pass = {
  name = "codegen",
  input_state = "optimizing",
  output_state = "codegen",

  validate = function(ir)
    return ir_mod.validate(ir, "codegen")
  end,

  ---@param ir IR
  ---@return table[]  LazySpec list
  build = function(ir)
    local specs = {}

    for _, adapter_path in ipairs(ADAPTERS) do
      local ok, adapter = pcall(require, adapter_path)
      if not ok then
        vim.notify(
          ("[pipeline.codegen] failed to load adapter %s: %s"):format(adapter_path, tostring(adapter)),
          vim.log.levels.ERROR
        )
      elseif type(adapter.build) ~= "function" then
        vim.notify(("[pipeline.codegen] adapter %s has no build() function"):format(adapter_path), vim.log.levels.WARN)
      else
        local build_ok, result = pcall(adapter.build, ir)
        if build_ok then
          for _, spec in ipairs(result) do
            specs[#specs + 1] = spec
          end
        else
          vim.notify(
            ("[pipeline.codegen] adapter %s build() failed: %s"):format(adapter_path, tostring(result)),
            vim.log.levels.WARN
          )
        end
      end
    end

    return specs
  end,
}

return codegen_pass
