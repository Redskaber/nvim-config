-- ~/.config/nvim/lua/toolchain/strategies/init.lua
-- Strategy layer: FormatterStrategy registry (TODO-3.2).
--
-- Strategies are registered by name; the normalize Phase resolves them
-- into FormatterNode.fn closures.
--
-- Custom strategies can be registered from any config file before the pipeline:
--   require("toolchain.strategies").register("my_strat", function(bufnr)
--     return { "my_formatter" }
--   end)
--
-- StrategyRegistry interface:
--   register(kind, strategy)
--   resolve(kind, node) — for multi-dispatch
--   get(name)
--   list()

local M = {}

---@class FormatterStrategy
---@field name    string
---@field resolve fun(bufnr: integer): string[]

---@type table<string, FormatterStrategy>
local _registry = {}

-- ── Write API ─────────────────────────────────────────────────────────────────

--- Register a named formatter strategy.
---@param name string
---@param fn   fun(bufnr: integer): string[]
function M.register(name, fn)
  assert(type(name) == "string" and name ~= "", "strategy name must be a non-empty string")
  assert(type(fn) == "function", "strategy resolver must be a function")
  _registry[name] = { name = name, resolve = fn }
end

-- ── Read API ──────────────────────────────────────────────────────────────────

---@param name string
---@return FormatterStrategy|nil
function M.get(name)
  return _registry[name]
end

--- Multi-dispatch: resolve a strategy for a given kind/node (extensible).
---@param kind string   e.g. "formatter"
---@param name string   strategy name
---@return FormatterStrategy|nil
function M.resolve(kind, name) -- luacheck: ignore kind (future extensibility)
  return _registry[name]
end

---@return string[]
function M.list()
  local names = vim.tbl_keys(_registry)
  table.sort(names)
  return names
end

-- ── Bootstrap built-ins ───────────────────────────────────────────────────────

-- Loaded lazily to avoid circular deps
local _bootstrapped = false

function M.bootstrap()
  if _bootstrapped then
    return
  end
  _bootstrapped = true
  require("toolchain.strategies.formatters").bootstrap(M)
end

-- Auto-bootstrap on first get/resolve call (lazy init)
local _orig_get = M.get
function M.get(name)
  M.bootstrap()
  return _orig_get(name)
end

return M
