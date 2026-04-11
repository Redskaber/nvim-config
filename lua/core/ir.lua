-- ~/.config/nvim/lua/core/ir.lua
-- IR (Intermediate Representation) type definitions and stage contract validation.
-- Each Pipeline stage appends fields to the IR; prior fields are read-only.

local M = {}

-- ── Type annotations ─────────────────────────────────────────────────────────

---@class IRMeta
---@field lang_modules string[]   -- modules participating in this build
---@field cache_key    string     -- sha256 of all lang module file contents
---@field started_at   number     -- os.clock() timestamp at pipeline start

---@class IRResolved
---@field lsp   table<string, boolean>   -- server  → use_mason
---@field tools table<string, boolean>   -- tool    → use_mason

-- FormatterNode is defined in core/schema.lua (fn? field added there)
---@class IR
---@field caps        table<string, table>   -- [collect]  registry snapshot
---@field errors      string[]               -- [collect+] accumulated errors
---@field meta        IRMeta                 -- [collect]  build metadata
---@field resolved    IRResolved             -- [resolve]  toolchain decisions
---@field merged_lsp  table<string, table>   -- [optimize] merged LSP configs
---@field all_parsers string[]               -- [optimize] deduplicated TS parsers
---@field profile     string                 -- [collect]  build profile

-- ── Stage field contracts ────────────────────────────────────────────────────
-- Maps each stage name to the IR fields that MUST exist before that stage runs.

local STAGE_REQUIRED_FIELDS = {
  normalize = { "caps", "meta" },
  resolve = { "caps", "meta" },
  optimize = { "caps", "resolved" },
  codegen = { "caps", "resolved", "merged_lsp", "all_parsers" },
}

-- ── Public API ───────────────────────────────────────────────────────────────

--- Construct a new IR with initial fields populated.
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

--- Validate that the IR contains all fields required before entering `stage`.
--- Returns a (possibly empty) list of error description strings.
---@param ir    IR
---@param stage string
---@return string[]
function M.validate(ir, stage)
  local required = STAGE_REQUIRED_FIELDS[stage]
  if not required then
    return { ("[ir.validate] unknown stage: %q"):format(stage) }
  end

  local errs = {}
  for _, field in ipairs(required) do
    if ir[field] == nil then
      errs[#errs + 1] = ("[ir.validate] stage %q requires field %q, but it is nil"):format(stage, field)
    end
  end
  return errs
end

return M
