-- ~/.config/nvim/lua/runtime/passes/collect.lua
-- Compiler kernel: Phase 1 — collect.
--
-- Loads each lang module, validates via schema (through capability.add),
-- builds the capability registry, and snapshots it into IR.caps (AST layer).
--
-- State contract: IDLE → COLLECTING
-- IR input:  { meta, profile }
-- IR output: { meta, profile, caps }   (AST sub-layer complete)

local ir_mod = require("core.ir")
local cap_mod = require("core.capability")

---@type Phase
local collect_pass = {
  name = "collect",
  input_state = "idle",
  output_state = "collecting",

  ---@param ir IR
  ---@return IR
  run = function(ir)
    -- Reset registry so each full pipeline run is isolated
    cap_mod.reset()

    local lang_modules = ir.meta.lang_modules or {}
    local next_ir = ir_mod.clone(ir)
    next_ir.caps = {}
    next_ir.stage = "AST"

    for _, mod in ipairs(lang_modules) do
      -- Load the lang module
      local ok, result = pcall(require, mod)
      if not ok then
        local d = ir_mod.diag("collect", mod, "failed to load: " .. tostring(result), "error")
        next_ir = ir_mod.append_diag(next_ir, d)
        vim.notify("[pipeline.collect] " .. d.message, vim.log.levels.WARN)
      elseif type(result) ~= "table" then
        local d = ir_mod.diag("collect", mod, "module did not return a table; skipping", "warn")
        next_ir = ir_mod.append_diag(next_ir, d)
        vim.notify("[pipeline.collect] " .. d.message, vim.log.levels.WARN)
      else
        local name = mod:match("([^.]+)$") or mod
        local add_result = cap_mod.add(name, result)

        -- Fold schema diagnostics into IR diagnostics
        for _, schema_d in ipairs(add_result.diags or {}) do
          next_ir = ir_mod.append_diag(
            next_ir,
            ir_mod.diag(
              "collect",
              mod,
              ("[schema] %s — %s"):format(schema_d.path, schema_d.message),
              schema_d.severity or "error"
            )
          )
        end

        if not add_result.ok then
          vim.notify(("[pipeline.collect] schema validation failed for %s"):format(mod), vim.log.levels.WARN)
        end
      end
    end

    -- Snapshot registry into IR (deep-copy → registry is independent of IR)
    next_ir.caps = cap_mod.snapshot()
    return next_ir
  end,
}

return collect_pass
