-- ~/.config/nvim/lua/core/capability.lua
-- Central capability registry.
--   • lang modules RETURN a plain table – zero side-effects.
--   • runtime.pipeline.collect() calls registry.add() on each returned table.
--   • This module owns the single mutable store; nobody else writes to it.

local schema = require("core.schema")

local M = {}

---@alias CapKind "lsp"|"formatter"|"linter"|"treesitter"|"mason_extra"

---@class LspConfig
---@field settings?  table
---@field cmd?       string[]
---@field mason?     boolean   nil = auto-resolved by toolchain

---@class Capability
---@field lsp?        table<string, LspConfig>
---@field formatters? table<string, string[]|fun(bufnr:integer):string[]>
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
      if r.formatters[ft] and type(r.formatters[ft]) == "table" and type(v) == "table" then
        vim.list_extend(r.formatters[ft], v)
      else
        r.formatters[ft] = type(v) == "function" and v or vim.deepcopy(v)
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

---@return table<string, Capability>
function M.all()
  return _store
end

--- Reset the registry store (used by debug_run to avoid accumulating stale data).
function M.reset()
  _store = {}
end
--- Snapshot the registry for debug/dump purposes.
---@return string
function M.dump()
  return vim.inspect(_store)
end

return M
