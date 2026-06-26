-- lua/runtime/phase_registry.lua
-- PhaseRegistry: register compile phases, single source of truth for phase order.
-- P2: replaces hardcoded PHASES in pipeline.lua.
-- P6-D1: Supports declarative after/before ordering in addition to numeric priority.
--        after/before references are resolved via topological sort at list() time.
--
-- FIX-P2-3 (2026-06-26): Live-update support for pipeline.PHASE_ORDER.
-- Previously pipeline.PHASE_ORDER was a require-time snapshot, so any
-- phase registered AFTER pipeline.lua was first required would not appear
-- in pipeline.PHASE_ORDER (stale). Now register()/register_codegen()/
-- _reset() invoke all registered listeners, which lets pipeline.lua attach
-- a listener that repopulates M.PHASE_ORDER as a plain table.
-- We deliberately do NOT use a metatable proxy here — LuaJIT's ipairs()
-- and # operator do not reliably honour __ipairs/__len on proxy tables,
-- which broke 9 tests that do `for i,p in ipairs(PHASE_ORDER)` and
-- `#PHASE_ORDER >= 8`. A plain table populated on-change is fully
-- backward-compatible with all existing consumers.

local M = {}

local _phases = {} -- { phase, priority, after=[], before=[] }
local _codegen = nil
local _order_cache = nil -- invalidated on every register()
local _listeners = {} -- { fn, fn, ... } called on every registry mutation

--- Register a listener that fires whenever the registry mutates
--- (register / register_codegen / _reset). The listener receives no
--- arguments; it should re-read M.list() / M.phase_order() to refresh
--- its own cached state.
---@param fn function
function M.add_listener(fn)
  assert(type(fn) == "function", "listener must be a function")
  _listeners[#_listeners + 1] = fn
end

local function _notify()
  for _, fn in ipairs(_listeners) do
    -- pcall: a misbehaving listener must not break the registry.
    pcall(fn)
  end
end

--- Register a phase with optional priority (lower runs first).
---@param phase table Phase object
---@param opts? { priority?: number, after?: string[], before?: string[] }
function M.register(phase, opts)
  opts = opts or {}
  _phases[#_phases + 1] = {
    phase = phase,
    priority = opts.priority or #_phases + 1,
    after = opts.after or {},
    before = opts.before or {},
  }
  _order_cache = nil -- invalidate memoised order
  _notify()
end

--- Register the codegen phase (special-cased last step).
---@param phase table Phase object
function M.register_codegen(phase)
  _codegen = phase
  _order_cache = nil
  _notify()
end

-- ── Topological sort with priority tie-breaking ──────────────────────────────

local function topo_sort(entries)
  -- Build name → entry index map
  local by_name = {}
  for i, e in ipairs(entries) do
    by_name[e.phase.name] = i
  end

  -- Build adjacency: edge[i] = { j, j, ... } means i must come before j
  local n = #entries
  local in_degree = {}
  local adj = {}
  for i = 1, n do
    in_degree[i] = 0
    adj[i] = {}
  end

  for i, e in ipairs(entries) do
    -- after: self comes after named phases  →  named phase → self
    for _, dep_name in ipairs(e.after) do
      local j = by_name[dep_name]
      if j then
        adj[j][#adj[j] + 1] = i
        in_degree[i] = in_degree[i] + 1
      end
    end
    -- before: self comes before named phases  →  self → named phase
    for _, dep_name in ipairs(e.before) do
      local j = by_name[dep_name]
      if j then
        adj[i][#adj[i] + 1] = j
        in_degree[j] = in_degree[j] + 1
      end
    end
  end

  -- Kahn's algorithm; use priority for tie-breaking
  local ready = {}
  for i = 1, n do
    if in_degree[i] == 0 then
      ready[#ready + 1] = i
    end
  end

  local function pop_min()
    if #ready == 0 then
      return nil
    end
    local best_pos, best_prio = 1, entries[ready[1]].priority
    for k = 2, #ready do
      local p = entries[ready[k]].priority
      if p < best_prio then
        best_prio, best_pos = p, k
      end
    end
    local idx = ready[best_pos]
    table.remove(ready, best_pos)
    return idx
  end

  local order = {}
  while #ready > 0 do
    local i = pop_min()
    order[#order + 1] = entries[i].phase
    for _, j in ipairs(adj[i]) do
      in_degree[j] = in_degree[j] - 1
      if in_degree[j] == 0 then
        ready[#ready + 1] = j
      end
    end
  end

  if #order < n then
    -- Cycle detected — fall back to priority-only sort and emit a warning
    -- OPT-J (2026-06-23): use ports.notify instead of vim.notify (INV-3)
    local ports = require("core.compiler.ports")
    ports.notify(
      vim.log.levels.WARN,
      "[phase_registry] dependency cycle detected — falling back to priority order"
    )
    table.sort(entries, function(a, b) return a.priority < b.priority end)
    order = {}
    for _, e in ipairs(entries) do
      order[#order + 1] = e.phase
    end
  end

  return order
end

--- Get all registered phases in resolved order.
---@return table[]
function M.list()
  if _order_cache then
    return _order_cache
  end
  _order_cache = topo_sort(_phases)
  return _order_cache
end

--- Get the codegen phase.
---@return table|nil
function M.codegen() return _codegen end

--- Get phase order names for debugging/state machine.
---@return string[]
function M.phase_order()
  local out = {}
  for _, phase in ipairs(M.list()) do
    out[#out + 1] = phase.name
  end
  if _codegen then
    out[#out + 1] = _codegen.name
  end
  return out
end

--- Reset registry (testing only).
--- Also clears listeners so that re-requiring runtime.pipeline (which
--- re-attaches its listener) does not accumulate stale listeners across
--- test cases. Production code never calls _reset().
function M._reset()
  _phases = {}
  _codegen = nil
  _order_cache = nil
  _listeners = {}
end
return M