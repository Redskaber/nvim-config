-- ~/.config/nvim/lua/runtime/passes/normalize.lua
-- Compiler kernel: Phase 2 — normalize.
--
-- Resolves FormatterNode.strategy → FormatterNode.fn via the strategy registry.
-- Operates entirely on deep-copies; the shared capability registry is never mutated.
-- Produces HIR (High-level IR): caps with fn closures injected.
--
-- State contract: COLLECTING → NORMALIZING
-- IR input:  AST layer (caps, meta)
-- IR output: HIR layer (caps with FormatterNode.fn injected)

local ir_mod = require("core.compiler.ir")
local strategies = require("toolchain.strategy.registry")

---@type Phase
local normalize_pass = {
  name = "normalize",
  input_state = "collecting",
  output_state = "normalizing",

  validate = function(ir)
    return ir_mod.validate(ir, "normalize")
  end,

  ---@param ir IR
  ---@return IR
  run = function(ir)
    -- Ensure built-in strategies are registered before we resolve them
    strategies.bootstrap()

    local next_caps = {}

    for lang, cap in pairs(ir.caps) do
      if not cap.formatters then
        next_caps[lang] = cap
      else
        local patched_formatters = {}
        local cap_patched = false

        for ft, fmts in pairs(cap.formatters) do
          -- Lazy-init: only copy the list when a mutation is needed
          local patched_list = nil

          for i, v in ipairs(fmts) do
            if type(v) == "table" and v.kind == "formatter" and v.strategy and not v.fn then
              if not patched_list then
                patched_list = vim.deepcopy(fmts)
              end

              local strat = strategies.get(v.strategy)
              if strat then
                patched_list[i].fn = strat.resolve
              else
                vim.notify("[pipeline.normalize] unknown formatter strategy: " .. v.strategy, vim.log.levels.WARN)
                -- Graceful degradation: inject a no-op fn rather than crashing
                patched_list[i].fn = function()
                  return {}
                end
              end

              cap_patched = true
            end
          end

          -- Share original list reference when unchanged (structural sharing)
          patched_formatters[ft] = patched_list or fmts
        end

        if cap_patched then
          -- Shallow-copy cap, replacing only the formatters field
          local new_cap = {}
          for k, v in pairs(cap) do
            new_cap[k] = v
          end
          new_cap.formatters = patched_formatters
          next_caps[lang] = new_cap
        else
          next_caps[lang] = cap
        end
      end
    end

    return ir_mod.with(ir, { caps = next_caps, stage = "HIR" })
  end,
}

return normalize_pass
