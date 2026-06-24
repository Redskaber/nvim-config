-- lua/core/compiler/ir.lua
-- Layer 1 compiler: IR value type + CompilerContext.
--
-- IR sub-layers (immutable, copy-on-write):
--   AST   — raw validated capability snapshot from collect pass
--   HIR   — normalised (FormatterNode.fn injected)
--   MIR   — strategy resolved (use_mason decisions)
--   LIR   — optimised (deduped parsers, merged LSP configs)
--   SPEC  — codegen input (all fields present, ready for adapters)
--
-- v4.1 changes (TODO-2.1, TODO-2.2):
--   • IR.stage is now an enum constant, validated on transition
--   • ir.new() / ir.transition() / ir.assert_stage() introduced
--   • Diagnostic gains .code field (machine-readable error codes)
--   • CompilerContext carries run_id for tracing
--   • debug-mode freeze on input IR in run_phase (via util.freeze)
--
-- v4.2 changes (P6-B1):
--   • Diagnostic type moved to core/domain/diagnostic.lua (Layer 2)
--   • Re-exported here for backward compatibility
--
-- v4.3 changes (Dependency Inversion):
--   • Use abstract types interface via core.compiler.types
--   • Concrete implementations injected from runtime layer
--   • Maintains strict layer boundaries (compiler → domain)

local M = {}
local types = require("core.compiler.types") -- abstract type interfaces
local util = require("core.kernel.util") -- for unfreeze in ir.with()

-- ── Stage enum ────────────────────────────────────────────────────────────────

M.STAGES = {
  AST = "AST",
  HIR = "HIR",
  MIR = "MIR",
  LIR = "LIR",
  SPEC = "SPEC",
}

-- Legal forward-only transitions
local STAGE_TRANSITIONS = {
  AST = M.STAGES.HIR,
  HIR = M.STAGES.MIR,
  MIR = M.STAGES.LIR,
  LIR = M.STAGES.SPEC,
}

-- ── Diagnostic ────────────────────────────────────────────────────────────────

--- Creates a Diagnostic using abstract type interface.
---@class Diagnostic
---@param stage    string
---@param node     string
---@param message  string
---@param severity? "error"|"warn"|"info"
---@return Diagnostic
function M.diag(stage, node, message, severity) return types.diag(stage, node, message, severity) end

-- Backward-compat alias
M.error = M.diag

-- ── IR Type ───────────────────────────────────────────────────────────────────

---@class IRMeta
---@field lang_modules  string[]
---@field cache_key     string
---@field started_at    number
---@field content_hash? string              SHA-like hash of module file contents (TODO-7.1)
---@field module_hashes? table<string, string>  per-module content hashes for incremental cache
---@field ir_version?   number              P6-C4: schema version for cache consistency

---@class IRResolved
---@field lsp   table<string, boolean>
---@field tools table<string, boolean>

---@class IRSymbols
---@field lsp   table<string, CanonicalSymbol>
---@field tools table<string, CanonicalSymbol>

---@class CanonicalSymbol
---@field mason  string|nil
---@field system boolean
---@class IR
---@field stage       string                 current sub-layer (AST/HIR/MIR/LIR/SPEC)
---@field caps        table<string, table>   [AST]  validated capability snapshot
---@field diagnostics Diagnostic[]           [all]  accumulated diagnostics
---@field meta        IRMeta                 [AST]  build metadata
---@field profile     string                 [AST]  build profile
---@field symbols?    IRSymbols              [HIR]  canonical symbol table (post-canonicalize)
---@field resolved    IRResolved             [MIR]  toolchain decisions
---@field merged_lsp  table<string, table>   [LIR]  deduped LSP configs
---@field all_parsers string[]               [LIR]  deduped TS parsers
---@field snapshots?  table<string, table>   [debug] per-stage IR snapshots
---@field _timings?   table<string, number>  [debug] per-phase timings (debug_run only)
---@field _specs?     table[]                [debug] codegen output embedded by codegen.run()

-- ── CompilerContext ───────────────────────────────────────────────────────────

---@class CompilerContext
---@field ir          IR
---@field stage       string
---@field diagnostics Diagnostic[]
---@field cache_key   string
---@field timings     table<string, number>
---@field run_id      string              unique per pipeline.run() call (TODO-5.3)

local _run_seq = 0
local function next_run_id()
  _run_seq = _run_seq + 1
  return string.format("run-%04d", _run_seq)
end

---@param ir        IR
---@param stage     string
---@param cache_key? string
---@return CompilerContext
function M.ctx(ir, stage, cache_key)
  return {
    ir = ir,
    stage = stage,
    diagnostics = util.deep_copy(ir.diagnostics or {}), -- pure: no vim API in Layer 1
    cache_key = cache_key or "",
    timings = {},
    run_id = next_run_id(),
  }
end

-- ── Stage field contracts ─────────────────────────────────────────────────────

local STAGE_REQUIRED = {
  normalize = { "caps", "meta" },
  canonicalize = { "caps", "meta" }, -- HIR in: requires caps + meta
  resolve = { "caps", "meta", "symbols" }, -- HIR+ in: symbols set by canonicalize pass
  optimize = { "caps", "resolved" },
  codegen = { "caps", "resolved", "merged_lsp", "all_parsers" },
}

-- ── Constructor ───────────────────────────────────────────────────────────────

---@param lang_modules string[]
---@param profile?     string
---@return IR
function M.new(lang_modules, profile)
  local cap_types = types.cap_types()
  local schema_version = require("core.compiler.cache.version").SCHEMA_VERSION
  return {
    stage = "AST",
    caps = {},
    diagnostics = {},
    meta = {
      lang_modules = lang_modules or {},
      cache_key = "",
      started_at = os.clock(),
      ir_version = schema_version, -- P6-C4: embed schema version
    },
    profile = profile or "full",
    ext_caps = {
      [cap_types.IMAGE] = {},
      [cap_types.MEDIA] = {},
      [cap_types.AI] = {},
      [cap_types.KEYBIND] = {},
      [cap_types.EDITOR] = {},
    },
    cap_specs = {},
  }
end

-- ── Stage transition ──────────────────────────────────────────────────────────

--- Transition IR to next stage (validates the transition is legal).
--- Returns new IR with updated stage field.
---@param ir IR
---@return IR
function M.transition(ir)
  local next = STAGE_TRANSITIONS[ir.stage]
  if not next then
    error(("ir.transition: no legal transition from stage %q"):format(ir.stage), 2)
  end
  return M.with(ir, { stage = next })
end

--- Assert IR is at expected stage. Throws if not.
---@param ir    IR
---@param stage string
function M.assert_stage(ir, stage)
  if ir.stage ~= stage then
    error(("ir.assert_stage: expected %q, got %q"):format(stage, ir.stage), 2)
  end
end

-- ── Copy-on-write ─────────────────────────────────────────────────────────────

--- Deep-copy an IR. Use for large structural changes.
---@param ir IR
---@return IR
function M.clone(ir)
  return util.deep_copy(ir) -- pure: no vim API in Layer 1
end

--- Shallow-copy an IR, replacing selected top-level fields (copy-on-write).
--- Handles freeze proxies correctly (LuaJIT __pairs not supported).
---@param ir      IR
---@param patches table
---@return IR
function M.with(ir, patches)
  -- util.unfreeze: if ir is a freeze proxy, get the original table for iteration
  local src = util.unfreeze(ir)
  local next_ir = {}
  for k, v in pairs(src) do
    next_ir[k] = v
  end
  for k, v in pairs(patches) do
    next_ir[k] = v
  end
  return next_ir
end

-- ── Diagnostics ───────────────────────────────────────────────────────────────

--- Append a Diagnostic, returning a new IR (copy-on-write).
---@param ir IR
---@param d  Diagnostic
---@return IR
function M.append_diag(ir, d)
  local new_diags = util.deep_copy(ir.diagnostics or {}) -- pure: no vim API in Layer 1
  new_diags[#new_diags + 1] = d
  return M.with(ir, { diagnostics = new_diags })
end

-- backward compat
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

-- backward compat
M.format_errors = M.format_diagnostics

--- Count diagnostics by severity.
---@param ir IR
---@return { errors: number, warns: number }
function M.diag_counts(ir)
  local c = { errors = 0, warns = 0 }
  for _, d in ipairs(ir.diagnostics or {}) do
    if d.severity == "error" then
      c.errors = c.errors + 1
    elseif d.severity == "warn" then
      c.warns = c.warns + 1
    end
  end
  return c
end

-- ── Pre-condition validation ──────────────────────────────────────────────────

--- Validate IR has all fields required before entering `stage`.
---@param ir    IR
---@param stage string
---@return Diagnostic[]
function M.validate(ir, stage)
  local required = STAGE_REQUIRED[stage]
  if not required then
    return { M.diag(stage, "ir", ("unknown stage %q"):format(stage)) }
  end
  local diags = {}
  for _, field in ipairs(required) do
    if ir[field] == nil then
      diags[#diags + 1] =
        M.diag(stage, "ir", ("required field %q missing before %s"):format(field, stage))
    end
  end
  return diags
end

-- ── IR diff (TODO-7.2) ────────────────────────────────────────────────────────

--- Compute a structural diff between two IRs.
--- Returns a list of { path, old, new } change records.
--- Useful for debug inspection and cache validation.
---@param old IR
---@param new IR
---@return { path: string, old: any, new: any }[]
function M.diff(old, new)
  local changes = {}

  local function walk(a, b, path)
    -- Compare top-level keys present in either
    local keys = {}
    for k in pairs(a) do
      keys[k] = true
    end
    for k in pairs(b) do
      keys[k] = true
    end

    for k in pairs(keys) do
      local av, bv = a[k], b[k]
      local p = path .. "." .. tostring(k)
      if type(av) ~= type(bv) then
        changes[#changes + 1] = { path = p, old = av, new = bv }
      elseif type(av) == "table" then
        walk(av, bv, p)
      elseif av ~= bv then
        changes[#changes + 1] = { path = p, old = av, new = bv }
      end
    end
  end

  walk(old, new, "ir")
  return changes
end

--- Format diff output as a human-readable string.
---@param changes { path: string, old: any, new: any }[]
---@return string
function M.format_diff(changes)
  if #changes == 0 then
    return "(no changes)"
  end
  local lines = {}
  for _, c in ipairs(changes) do
    lines[#lines + 1] = ("  %s: %s → %s"):format(
      c.path,
      tostring(c.old):sub(1, 60),
      tostring(c.new):sub(1, 60)
    )
  end
  return table.concat(lines, "\n")
end
return M
