-- ~/.config/nvim/lua/core/capability.lua
-- Central capability registry.
--
--   • Lang modules RETURN a plain table — zero side-effects.
--   • Only the pipeline's collect Pass writes to the registry via M.add().
--   • M.snapshot() returns a deep-copy so callers cannot mutate internal state.
--   • M.reset() is provided for debug_run isolation.

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

-- { [lang_name]: Capability }
local _store = {}

--- Add (deep-merge) a validated capability bundle.
---@param name string
---@param cap  Capability
function M.add(name, cap)
  cap = schema.validate(name, cap)

  if not _store[name] then
    _store[name] = { lsp = {}, formatters = {}, linters = {}, treesitter = {}, mason = {} }
  end
  local r = _store[name]

  if cap.lsp then
    for k, v in pairs(cap.lsp) do
      r.lsp[k] = r.lsp[k] and vim.tbl_deep_extend("force", r.lsp[k], v) or vim.deepcopy(v)
    end
  end

  if cap.formatters then
    for ft, v in pairs(cap.formatters) do
      -- v is always a list (schema enforces this); deep-merge lists
      if r.formatters[ft] and type(r.formatters[ft]) == "table" then
        vim.list_extend(r.formatters[ft], vim.deepcopy(v))
      else
        r.formatters[ft] = vim.deepcopy(v)
      end
    end
  end

  if cap.linters then
    for ft, v in pairs(cap.linters) do
      if r.linters[ft] then
        vim.list_extend(r.linters[ft], v)
      else
        r.linters[ft] = vim.deepcopy(v)
      end
    end
  end

  if cap.treesitter then
    vim.list_extend(r.treesitter, cap.treesitter)
  end

  if cap.mason then
    vim.list_extend(r.mason, cap.mason)
  end
end

--- Return a deep-copy snapshot of the registry (immutable to callers).
---@return table<string, Capability>
function M.snapshot()
  return vim.deepcopy(_store)
end

--- Reset the registry (used by debug_run to avoid accumulating stale data).
function M.reset()
  _store = {}
end

--- Dump the raw store for introspection (debug only).
---@return string
function M.dump()
  return vim.inspect(_store)
end

return M
