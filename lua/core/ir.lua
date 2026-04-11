-- ~/.config/nvim/lua/core/ir.lua
-- IR (Intermediate Representation): immutable value type.
--
-- Design principles (P0-3):
--   • IR is a plain Lua table; every Pass returns a NEW IR (copy-on-write).
--   • IR.clone() performs a safe structural deep-copy.
--   • Stages append fields only; no field is ever overwritten.
--   • CompileError is a structured type (P2-2): { stage, node, message }.
--
-- Stage field contracts:
--   normalize  requires: caps, meta
--   resolve    requires: caps, meta
--   optimize   requires: caps, resolved
--   codegen    requires: caps, resolved, merged_lsp, all_parsers

local M = {}

-- ── Structured error type (P2-2) ─────────────────────────────────────────────

---@class CompileError
---@field stage   string   pipeline stage name ("collect"|"normalize"|…)
---@field node    string   lang module or AST node identifier
---@field message string   human-readable description

--- Construct a CompileError.
---@param stage   string
---@param node    string
---@param message string
---@return CompileError
function M.error(stage, node, message)
  return { stage = stage, node = node, message = message }
end

-- ── Type annotations ─────────────────────────────────────────────────────────

---@class IRMeta
---@field lang_modules string[]
---@field cache_key    string
---@field started_at   number

---@class IRResolved
---@field lsp   table<string, boolean>
---@field tools table<string, boolean>

---@class IR
---@field caps        table<string, table>   -- [collect]  validated capability snapshot
---@field errors      CompileError[]         -- [all]      accumulated structured errors
---@field meta        IRMeta                 -- [collect]  build metadata
---@field profile     string                 -- [collect]  build profile
---@field resolved    IRResolved             -- [resolve]  toolchain decisions
---@field merged_lsp  table<string, table>   -- [optimize] deduped LSP configs
---@field all_parsers string[]               -- [optimize] deduped TS parsers
---@field snapshots?  table<string, table>   -- [debug]    per-stage IR snapshots

-- ── Stage field contracts ────────────────────────────────────────────────────

local STAGE_REQUIRED_FIELDS = {
  normalize = { "caps", "meta" },
  resolve = { "caps", "meta" },
  optimize = { "caps", "resolved" },
  codegen = { "caps", "resolved", "merged_lsp", "all_parsers" },
}

-- ── Constructor ──────────────────────────────────────────────────────────────

--- Construct a fresh IR at the start of a pipeline run.
---@param lang_modules string[]
---@param profile?     string   defaults to "full"
---@return IR
function M.new(lang_modules, profile)
  return {
    caps = {},
    errors = {},
    meta = {
      lang_modules = lang_modules or {},
      cache_key = "",
      started_at = os.clock(),
    },
    profile = profile or "full",
  }
end

-- ── Clone (copy-on-write) ────────────────────────────────────────────────────

--- Return a structural deep-copy of an IR.
--- Passes use this to produce a new IR rather than mutating the input.
---@param ir IR
---@return IR
function M.clone(ir)
  -- vim.deepcopy handles nested tables and preserves metatables.
  return vim.deepcopy(ir)
end

--- Return a shallow-copy of an IR with selected top-level fields replaced.
--- Cheaper than M.clone() when only one or two fields change.
---@param ir      IR
---@param patches table  { field = new_value }
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

-- ── Validation ───────────────────────────────────────────────────────────────

--- Validate that the IR contains all fields required before entering `stage`.
--- Returns a (possibly empty) list of CompileError.
---@param ir    IR
---@param stage string
---@return CompileError[]
function M.validate(ir, stage)
  local required = STAGE_REQUIRED_FIELDS[stage]
  if not required then
    return { M.error(stage, "ir", ("unknown stage %q"):format(stage)) }
  end

  local errs = {}
  for _, field in ipairs(required) do
    if ir[field] == nil then
      errs[#errs + 1] =
        M.error(stage, "ir." .. field, ("stage %q requires field %q but it is nil"):format(stage, field))
    end
  end
  return errs
end

--- Append a CompileError to an IR, returning the new IR (copy-on-write).
---@param ir  IR
---@param err CompileError
---@return IR
function M.append_error(ir, err)
  local new_errors = vim.deepcopy(ir.errors or {})
  new_errors[#new_errors + 1] = err
  return M.with(ir, { errors = new_errors })
end

--- Format all CompileErrors in an IR as a single human-readable string.
---@param ir IR
---@return string
function M.format_errors(ir)
  if not ir.errors or #ir.errors == 0 then
    return ""
  end
  local lines = {}
  for _, e in ipairs(ir.errors) do
    lines[#lines + 1] = string.format("[%s] %s: %s", e.stage or "?", e.node or "?", e.message or "?")
  end
  return table.concat(lines, "\n")
end

return M
