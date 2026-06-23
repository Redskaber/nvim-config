-- ~/.config/nvim/lua/runtime/passes/optimize.lua
-- Compiler kernel: Phase 4 — optimize.
--
-- Deduplicates treesitter parsers; merges LSP configs.
-- Produces LIR (Low-level IR): ready for codegen adapters.
--
-- State contract: RESOLVING → OPTIMIZING
-- IR input:  MIR layer (caps, resolved)
-- IR output: LIR layer (+ merged_lsp, all_parsers)

local ir_mod = require("core.compiler.ir")
local util = require("core.kernel.util")

---@type Phase
local optimize_pass = {
  name = "optimize",
  input_state = "resolving",
  output_state = "optimizing",

  validate = function(ir)
    return ir_mod.validate(ir, "optimize")
  end,

  ---@param ir IR
  ---@return IR
  run = function(ir)
    -- ── Treesitter: deduplicate parser list ──────────────────────────────
    local all_parsers = {}
    for _, cap in pairs(ir.caps) do
      if cap.treesitter then
        for _, p in ipairs(cap.treesitter) do
          all_parsers[#all_parsers + 1] = p
        end
      end
    end

    -- ── LSP: deep-merge configs using util.deep_merge (no vim API) ────────
    local merged_lsp = {}
    for _, cap in pairs(ir.caps) do
      if cap.lsp then
        for server, cfg in pairs(cap.lsp) do
          if merged_lsp[server] then
            merged_lsp[server] = util.deep_merge(merged_lsp[server], cfg)
          else
            -- shallow-copy to avoid sharing references
            local copy = {}
            for k, v in pairs(cfg) do
              copy[k] = v
            end
            merged_lsp[server] = copy
          end
        end
      end
    end

    return ir_mod.with(ir, {
      all_parsers = util.dedup(all_parsers),
      merged_lsp = merged_lsp,
      stage = "LIR",
    })
  end,
}

return optimize_pass