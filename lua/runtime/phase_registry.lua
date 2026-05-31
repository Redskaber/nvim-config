-- lua/runtime/phase_registry.lua
-- PhaseRegistry: register compile phases, single source of truth for phase order.
-- P2: replaces hardcoded PHASES in pipeline.lua.

local M = {}

local _phases = {}
local _codegen = nil

--- Register a phase with optional priority (lower runs first).
---@param phase table Phase object
---@param opts? { priority?: number }
function M.register(phase, opts)
  opts = opts or {}
  _phases[#_phases + 1] = {
    phase = phase,
    priority = opts.priority or #_phases + 1,
  }
  table.sort(_phases, function(a, b)
    return a.priority < b.priority
  end)
end

--- Register the codegen phase (special-cased last step).
---@param phase table Phase object
function M.register_codegen(phase)
  _codegen = phase
end

--- Get all registered phases in order.
---@return table[]
function M.list()
  local out = {}
  for _, entry in ipairs(_phases) do
    out[#out + 1] = entry.phase
  end
  return out
end

--- Get the codegen phase.
---@return table|nil
function M.codegen()
  return _codegen
end

--- Get phase order names for debugging/state machine.
---@return string[]
function M.phase_order()
  local out = {}
  for _, entry in ipairs(_phases) do
    out[#out + 1] = entry.phase.name
  end
  if _codegen then
    out[#out + 1] = _codegen.name
  end
  return out
end

return M
