-- ~/.config/nvim/lua/core/ir.lua
-- Domain IR layer: immutable value type + compiler context.
--
-- IR sub-layers (TODO-2.1):
--   AST   — raw validated capability snapshot from collect pass
--   HIR   — normalised (FormatterNode.fn injected)
--   MIR   — strategy resolved (use_mason decisions)
--   LIR   — optimised (deduped parsers, merged LSP configs)
--   SPEC  — codegen input (all fields present, ready for adapters)
--
-- CompilerContext (TODO-1.1): unified carry type through the pipeline.
--   { ir, stage, diagnostics, cache_key, timings }
--
-- Copy-on-write: every Pass returns a NEW IR via ir.with() or ir.clone().
-- Passes NEVER mutate their input IR.

local M = {}

-- ── Diagnostic type (pipeline-level, separate from schema.SchemaDiagnostic) ──

---@class Diagnostic
---@field stage    string   pipeline stage
---@field node     string   lang module or AST node identifier
---@field message  string
---@field severity "error"|"warn"|"info"

---@param stage    string
---@param node     string
---@param message  string
---@param severity? "error"|"warn"|"info"
---@return Diagnostic
function M.diag(stage, node, message, severity)
  return { stage = stage, node = node, message = message, severity = severity or "error" }
end

-- Backward-compat alias (old code uses ir.error)
M.error = M.diag

-- ── IR sub-layer type annotations ─────────────────────────────────────────────

---@class IRMeta
---@field lang_modules string[]
---@field cache_key    string
---@field started_at   number

---@class IRResolved
---@field lsp   table<string, boolean>
---@field tools table<string, boolean>

---@class IR
---@field stage       string                 current sub-layer (AST/HIR/MIR/LIR/SPEC)
---@field caps        table<string, table>   [AST]  validated capability snapshot
---@field diagnostics Diagnostic[]           [all]  accumulated diagnostics
---@field meta        IRMeta                 [AST]  build metadata
---@field profile     string                 [AST]  build profile
---@field resolved    IRResolved             [MIR]  toolchain decisions
---@field merged_lsp  table<string, table>   [LIR]  deduped LSP configs
---@field all_parsers string[]               [LIR]  deduped TS parsers
---@field snapshots?  table<string, table>   [debug] per-stage IR snapshots

-- ── CompilerContext ───────────────────────────────────────────────────────────

---@class CompilerContext
---@field ir          IR
---@field stage       string
---@field diagnostics Diagnostic[]
---@field cache_key   string
---@field timings     table<string, number>

---@param ir        IR
---@param stage     string
---@param cache_key? string
---@return CompilerContext
function M.ctx(ir, stage, cache_key)
  return {
    ir = ir,
    stage = stage,
    diagnostics = vim.deepcopy(ir.diagnostics or {}),
    cache_key = cache_key or "",
    timings = {},
  }
end

-- ── Stage field contracts (for pre-condition validation) ──────────────────────

local STAGE_REQUIRED = {
  normalize = { "caps", "meta" },
  resolve = { "caps", "meta" },
  optimize = { "caps", "resolved" },
  codegen = { "caps", "resolved", "merged_lsp", "all_parsers" },
}

-- ── Constructor ───────────────────────────────────────────────────────────────

---@param lang_modules string[]
---@param profile?     string
---@return IR
function M.new(lang_modules, profile)
  return {
    stage = "AST",
    caps = {},
    diagnostics = {},
    meta = {
      lang_modules = lang_modules or {},
      cache_key = "",
      started_at = os.clock(),
    },
    profile = profile or "full",
  }
end

-- ── Copy-on-write helpers ─────────────────────────────────────────────────────

--- Deep-copy an IR. Use for large structural changes.
---@param ir IR
---@return IR
function M.clone(ir)
  return vim.deepcopy(ir)
end

--- Shallow-copy an IR, replacing selected top-level fields.
--- Much cheaper than clone() when only 1-2 fields change.
---@param ir      IR
---@param patches table
---@return IR
function M.with(ir, patches)
  local next_ir = {}
  for k, v in pairs(ir) do
    next_ir[k] = v
  end
  for k, v in pairs(patches) do
    next_ir[k] = v
  end
  return next_ir
end

-- ── Diagnostics ───────────────────────────────────────────────────────────────

--- Append a Diagnostic, returning a new IR (copy-on-write).
---@param ir  IR
---@param d   Diagnostic
---@return IR
function M.append_diag(ir, d)
  local new_diags = vim.deepcopy(ir.diagnostics or {})
  new_diags[#new_diags + 1] = d
  return M.with(ir, { diagnostics = new_diags })
end

-- Backward-compat alias
M.append_error = M.append_diag

--- Format all diagnostics as a single human-readable string.
---@param ir IR
---@return string
function M.format_diagnostics(ir)
  if not ir.diagnostics or #ir.diagnostics == 0 then
    return ""
  end
  local lines = {}
  for _, d in ipairs(ir.diagnostics) do
    lines[#lines + 1] = ("[%s][%s] %s: %s"):format(
      d.severity or "error",
      d.stage or "?",
      d.node or "?",
      d.message or "?"
    )
  end
  return table.concat(lines, "\n")
end

-- Backward-compat alias
M.format_errors = M.format_diagnostics

--- Count diagnostics by severity.
---@param ir IR
---@return { errors: number, warns: number }
function M.diag_counts(ir)
  local counts = { errors = 0, warns = 0 }
  for _, d in ipairs(ir.diagnostics or {}) do
    if d.severity == "error" then
      counts.errors = counts.errors + 1
    elseif d.severity == "warn" then
      counts.warns = counts.warns + 1
    end
  end
  return counts
end

-- ── Pre-condition validation ──────────────────────────────────────────────────

--- Validate IR has all fields required before entering `stage`.
--- Returns a (possibly empty) list of Diagnostic.
---@param ir    IR
---@param stage string
---@return Diagnostic[]
function M.validate(ir, stage)
  local required = STAGE_REQUIRED[stage]
  if not required then
    return { M.diag(stage, "ir", ("unknown stage %q"):format(stage)) }
  end
  local out = {}
  for _, field in ipairs(required) do
    if ir[field] == nil then
      out[#out + 1] = M.diag(stage, "ir." .. field, ("stage %q requires field %q but it is nil"):format(stage, field))
    end
  end
  return out
end

return M
