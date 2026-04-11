-- ~/.config/nvim/lua/core/capability.lua
-- Domain IR layer: immutable CapabilitySet builder (TODO-6.1).
--
-- Design:
--   • Lang modules RETURN plain tables — zero side-effects.
--   • Only the collect pass calls M.add() (write path).
--   • M.snapshot() returns a deep-copy; callers cannot mutate internal state.
--   • M.reset() is provided for debug_run isolation.
--   • The global mutable _store is a necessary runtime evil (Neovim module cache
--     means we can't escape it); it is wrapped in pure-functional accessors.

local schema = require("core.schema")

local M = {}

---@alias CapKind "lsp"|"formatter"|"linter"|"treesitter"|"mason_extra"

---@class LspConfig
---@field settings? table
---@field cmd?      string[]
---@field mason?    boolean   nil = auto-resolved by toolchain

---@class Capability
---@field lsp?        table<string, LspConfig>
---@field formatters? table<string, (string|FormatterNode)[]>
---@field linters?    table<string, string[]>
---@field treesitter? string[]
---@field mason?      string[]

-- Module-level store: { [lang_name]: Capability }
local _store = {}

-- ── Pure merge helpers ────────────────────────────────────────────────────────

local function merge_lsp(dst, src)
  for k, v in pairs(src) do
    dst[k] = dst[k] and vim.tbl_deep_extend("force", dst[k], v) or vim.deepcopy(v)
  end
end

local function merge_list_map(dst, src)
  for ft, v in pairs(src) do
    if dst[ft] and type(dst[ft]) == "table" then
      vim.list_extend(dst[ft], vim.deepcopy(v))
    else
      dst[ft] = vim.deepcopy(v)
    end
  end
end

-- ── Write path (collect pass only) ───────────────────────────────────────────

--- Add (deep-merge) a validated capability bundle.
--- Returns { ok, diags } so the caller can surface schema errors.
---@param name string
---@param raw  table
---@return { ok: boolean, diags: table[] }
function M.add(name, raw)
  local result = schema.validate(name, raw)

  -- Surface warnings even on success
  if #result.diags > 0 then
    local msg = schema.format_diags(result.diags)
    local level = result.ok and vim.log.levels.WARN or vim.log.levels.ERROR
    vim.notify(("[capability:%s] schema issues:\n%s"):format(name, msg), level)
  end

  if not result.ok or not result.cap then
    return { ok = false, diags = result.diags }
  end

  local cap = result.cap

  if not _store[name] then
    _store[name] = { lsp = {}, formatters = {}, linters = {}, treesitter = {}, mason = {} }
  end
  local r = _store[name]

  if cap.lsp then
    merge_lsp(r.lsp, cap.lsp)
  end
  if cap.formatters then
    merge_list_map(r.formatters, cap.formatters)
  end
  if cap.linters then
    merge_list_map(r.linters, cap.linters)
  end
  if cap.treesitter then
    vim.list_extend(r.treesitter, cap.treesitter)
  end
  if cap.mason then
    vim.list_extend(r.mason, cap.mason)
  end

  return { ok = true, diags = result.diags }
end

-- ── Read path ─────────────────────────────────────────────────────────────────

--- Return a deep-copy snapshot (immutable to callers).
---@return table<string, Capability>
function M.snapshot()
  return vim.deepcopy(_store)
end

--- Reset the registry (used by debug_run to avoid accumulating stale data).
function M.reset()
  _store = {}
end

--- Raw dump for introspection (debug only).
---@return string
function M.dump()
  return vim.inspect(_store)
end

return M
