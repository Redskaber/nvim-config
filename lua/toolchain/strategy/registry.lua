-- lua/toolchain/strategy/registry.lua
-- Layer 3 strategy: FormatterStrategy registry.
--
-- Strategies are registered by name; the normalize Phase resolves them
-- into FormatterNode.fn closures.
--
-- Custom strategies can be registered from any config file before the pipeline:
--   require("toolchain.strategy.registry").register({
--     name = "my_strat",
--     applies = function(tool, env) return tool == "my_strat" end,
--     resolve = function(bufnr) return { "my_formatter" } end,
--     priority = 50,
--   })

local M = {}

---@type table<string, Strategy>
local _registry = {}
local _bootstrapped = false
local _locked = false

-- ── Write API ─────────────────────────────────────────────────────────────────

--- Register a strategy. Accepts either a Strategy table or (name, fn) legacy form.
--- Throws if called after lock().
---@param strategy_or_name Strategy|string  Strategy table, or legacy name string
---@param fn?              fun(bufnr: integer): string[]  resolver fn (legacy form only)
function M.register(strategy_or_name, fn)
  if _locked then
    error("strategy registry is locked — cannot register after bootstrap()", 2)
  end
  if type(strategy_or_name) == "string" then
    -- Legacy form: register(name, fn)
    local name = strategy_or_name
    assert(type(name) == "string" and name ~= "", "strategy name must be a non-empty string")
    assert(type(fn) == "function", "strategy resolver must be a function")
    _registry[name] = {
      name = name,
      applies = function(tool) return tool == name end,
      resolve = fn,
      priority = 50,
    }
  else
    -- New form: register(Strategy)
    local s = strategy_or_name
    assert(type(s) == "table", "strategy must be a table")
    assert(type(s.name) == "string" and s.name ~= "", "strategy.name must be a non-empty string")
    assert(type(s.resolve) == "function", "strategy.resolve must be a function")
    _registry[s.name] = s
  end
end

-- ── Read API ──────────────────────────────────────────────────────────────────

---@param name string
---@return Strategy|nil
function M.get(name)
  if not _bootstrapped then
    M.bootstrap()
  end
  return _registry[name]
end

--- Multi-dispatch: resolve a strategy for a given kind/name.
---@param _kind string   e.g. "formatter" (reserved for future multi-dispatch)
---@param name  string   strategy name
---@return Strategy|nil
function M.resolve(_kind, name) return M.get(name) end

---@return string[]
function M.list()
  if not _bootstrapped then
    M.bootstrap()
  end
  -- OPT-C (2026-06-23): pure Lua instead of vim.tbl_keys (INV-9 purity)
  local names = {}
  for k in pairs(_registry) do
    names[#names + 1] = k
  end
  table.sort(names)
  return names
end

-- ── Bootstrap built-ins ───────────────────────────────────────────────────────

--- Register all built-in strategies. Idempotent.
--- Locks the registry after bootstrap so no further registrations are accepted.
function M.bootstrap()
  if _bootstrapped then
    return
  end
  _bootstrapped = true
  require("toolchain.strategy.builtin").bootstrap(M)
  M.lock()
end

--- Lock the registry — subsequent register() calls will error.
--- Called automatically by bootstrap(); can also be called explicitly.
function M.lock() _locked = true end

return M