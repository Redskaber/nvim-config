-- lua/runtime/passes/resolve.lua
-- Compiler kernel: Phase 3 — resolve.
--
-- Reads ir.symbols (set by canonicalize pass) to produce IR.resolved.
-- IR.resolved is the authoritative use_mason decision table consumed by adapters.
--
-- REFACTOR (TODO-0.2): no longer calls rules.use_mason() directly.
-- All symbol→mason decisions are pre-computed in canonicalize pass.
-- This pass is now a pure projection: ir.symbols → ir.resolved.
--
-- State contract: CANONICALIZING → RESOLVING
-- IR input:  HIR + ir.symbols
-- IR output: MIR layer (+ resolved)

local ir_mod = require("core.compiler.ir")

---@type Phase
local resolve_pass = {
  name = "resolve",
  input_state = "canonicalizing",
  output_state = "resolving",

  validate = function(ir)
    -- ir_mod.validate(ir, "resolve") already checks caps, meta, symbols
    -- (STAGE_REQUIRED.resolve = { "caps", "meta", "symbols" })
    return ir_mod.validate(ir, "resolve")
  end,

  ---@param ir IR
  ---@return IR
  run = function(ir)
    local symbols = ir.symbols or { lsp = {}, tools = {} }
    local resolved = { lsp = {}, tools = {} }

    -- Project ir.symbols.lsp → resolved.lsp (use_mason = symbol.mason ~= nil)
    for server, sym in pairs(symbols.lsp) do
      resolved.lsp[server] = not sym.system and sym.mason ~= nil
    end

    -- Project ir.symbols.tools → resolved.tools
    for tool, sym in pairs(symbols.tools) do
      resolved.tools[tool] = not sym.system and sym.mason ~= nil
    end

    -- Also cover FormatterNode.name entries not in symbols
    -- (canonicalize should have caught them, but be defensive)
    for _, cap in pairs(ir.caps) do
      for _, fmts in pairs(cap.formatters or {}) do
        for _, v in ipairs(fmts) do
          if type(v) == "table" and v.name and resolved.tools[v.name] == nil then
            resolved.tools[v.name] = true -- default: try mason
          end
        end
      end
    end

    return ir_mod.with(ir, { resolved = resolved, stage = "MIR" })
  end,
}

return resolve_pass
