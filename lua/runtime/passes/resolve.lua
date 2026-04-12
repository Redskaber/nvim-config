-- ~/.config/nvim/lua/runtime/passes/resolve.lua
-- Compiler kernel: Phase 3 — resolve.
--
-- Decides use_mason for every LSP server and tool; writes IR.resolved.
-- Produces MIR (Mid-level IR): toolchain decisions fully baked.
--
-- State contract: NORMALIZING → RESOLVING
-- IR input:  HIR layer (caps, meta)
-- IR output: MIR layer (+ resolved)

local ir_mod = require("core.compiler.ir")
local rules = require("toolchain.rules")

---@type Phase
local resolve_pass = {
  name = "resolve",
  input_state = "normalizing",
  output_state = "resolving",

  validate = function(ir)
    return ir_mod.validate(ir, "resolve")
  end,

  ---@param ir IR
  ---@return IR
  run = function(ir)
    local resolved = { lsp = {}, tools = {} }

    -- Helper: mark a list of tool strings into resolved.tools
    local function mark_tools(tbl)
      if not tbl then
        return
      end
      for _, list in pairs(tbl) do
        if type(list) == "table" then
          for _, item in ipairs(list) do
            -- Only plain strings are concrete tool names; FormatterNodes have .kind
            if type(item) == "string" then
              resolved.tools[item] = rules.use_mason(item)
            end
          end
        end
      end
    end

    for _, cap in pairs(ir.caps) do
      -- LSP servers
      if cap.lsp then
        for server, cfg in pairs(cap.lsp) do
          resolved.lsp[server] = rules.use_mason(server) and (cfg.mason ~= false)
        end
      end

      -- Formatters / linters (plain-string entries only)
      mark_tools(cap.formatters)
      mark_tools(cap.linters)

      -- Explicit mason[] list on the cap
      if cap.mason then
        for _, t in ipairs(cap.mason) do
          resolved.tools[t] = rules.use_mason(t)
        end
      end
    end

    return ir_mod.with(ir, { resolved = resolved, stage = "MIR" })
  end,
}

return resolve_pass
