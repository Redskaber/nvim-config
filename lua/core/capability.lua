-- ~/.config/nvim/lua/core/capability.lua
-- Central capability registry: the single source of truth for all language tooling.
-- All lang declarations MUST go through M.register(); nothing else creates plugin specs.

local M = {}

---@alias CapKind "lsp"|"formatter"|"linter"|"treesitter"|"mason_extra"

---@class LspConfig
---@field settings?  table     raw LSP settings
---@field cmd?       string[]  override server command
---@field mason?     boolean   nil = auto-resolved by toolchain

---@class Capability
---@field lsp?        table<string, LspConfig>  server_name → config
---@field formatters? table<string, string[]>   filetype  → formatter list
---@field linters?    table<string, string[]>   filetype  → linter list
---@field treesitter? string[]                  parsers to ensure_installed
---@field mason?      string[]                  extra mason packages (beyond auto-derived)

-- Internal: { [name]: Capability }
local _registry = {}

--- Register a language capability bundle. Idempotent: later registrations
--- deep-merge into the same key so split modules work.
---@param name string  unique lang name, e.g. "rust"
---@param cap  Capability
function M.register(name, cap)
  if not _registry[name] then
    _registry[name] = { lsp = {}, formatters = {}, linters = {}, treesitter = {}, mason = {} }
  end
  local r = _registry[name]
  if cap.lsp then
    vim.tbl_deep_extend("force", r.lsp, cap.lsp)
  end
  if cap.formatters then
    vim.tbl_deep_extend("force", r.formatters, cap.formatters)
  end
  if cap.linters then
    vim.tbl_deep_extend("force", r.linters, cap.linters)
  end
  if cap.treesitter then
    for _, p in ipairs(cap.treesitter) do
      r.treesitter[#r.treesitter + 1] = p
    end
  end
  if cap.mason then
    for _, t in ipairs(cap.mason) do
      r.mason[#r.mason + 1] = t
    end
  end
end

--- Return iterator over all registered capabilities.
---@return fun(): string, Capability
function M.iter()
  return next, _registry
end

--- Return all capabilities as a flat table for adapters.
---@return table<string, Capability>
function M.all()
  return _registry
end

return M
