-- ~/.config/nvim/lua/toolchain/strategies/init.lua
-- FormatterStrategy registry.
--
-- Strategies are registered by name; the normalize Pass resolves them
-- into FormatterNode.fn closures.  Custom strategies can be registered
-- from any config file before the pipeline runs.

local M = {}

---@class FormatterStrategy
---@field name    string
---@field resolve fun(bufnr: integer): string[]

---@type table<string, FormatterStrategy>
local _registry = {}

--- Register a named formatter strategy.
---@param name string
---@param fn   fun(bufnr: integer): string[]
function M.register(name, fn)
  assert(type(name) == "string" and name ~= "", "strategy name must be a non-empty string")
  assert(type(fn) == "function", "strategy resolver must be a function")
  _registry[name] = { name = name, resolve = fn }
end

--- Retrieve a registered strategy by name.  Returns nil if not found.
---@param name string
---@return FormatterStrategy|nil
function M.get(name)
  return _registry[name]
end

--- List all registered strategy names (for :LtosInfo / debug).
---@return string[]
function M.list()
  local names = vim.tbl_keys(_registry)
  table.sort(names)
  return names
end

-- Load built-in strategies on first require.
-- Pass self (M) as the registry to avoid circular require.
require("toolchain.strategies.formatters").bootstrap(M)

return M
