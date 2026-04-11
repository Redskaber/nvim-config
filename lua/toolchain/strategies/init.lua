-- ~/.config/nvim/lua/toolchain/strategies/init.lua
-- FormatterStrategy registry.
-- Strategies are registered by name and resolved at normalize stage.

local M = {}

---@class FormatterStrategy
---@field name    string
---@field resolve fun(bufnr: integer): string[]

---@type table<string, FormatterStrategy>
local registry = {}

--- Register a named formatter strategy.
---@param name string
---@param fn   fun(bufnr: integer): string[]
function M.register(name, fn)
  registry[name] = { name = name, resolve = fn }
end

--- Retrieve a registered strategy by name. Returns nil if not found.
---@param name string
---@return FormatterStrategy|nil
function M.get(name)
  return registry[name]
end

return M
