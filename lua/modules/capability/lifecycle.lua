-- lua/modules/capability/lifecycle.lua
-- P4: Capability lifecycle management (pure value, COW).

local M = {}

local util = require("core.kernel.util")
-- FIX-AUDIT-P1-5 (2026-06-23): migrate to domain.diagnostic for consistent
-- Diagnostic shape. Old code used inline {severity, message} tables, which
-- is inconsistent with graph.lua (already migrated per AUDIT §3.2) and lacks
-- the `code`/`stage`/`node` fields used by downstream consumers.
local diagnostic = require("core.domain.diagnostic")

---@enum M.STATES
M.STATES = {
  DECLARED = "DECLARED",
  VALIDATED = "VALIDATED",
  RESOLVED = "RESOLVED",
  MATERIALIZED = "MATERIALIZED",
  RUNNING = "RUNNING",
  ERROR = "ERROR",
}

-- Legal forward transitions
local LEGAL_TRANSITIONS = {
  [M.STATES.DECLARED] = M.STATES.VALIDATED,
  [M.STATES.VALIDATED] = M.STATES.RESOLVED,
  [M.STATES.RESOLVED] = M.STATES.MATERIALIZED,
  [M.STATES.MATERIALIZED] = M.STATES.RUNNING,
  [M.STATES.RUNNING] = M.STATES.RUNNING, -- Self-transition for active state
  -- Any state can transition to ERROR
}

---@class LifecycleRecord
---@field state M.STATES
---@field id string
---@field history M.STATES[]
---@field timestamps table<M.STATES, number>
---@field diags table[]  Accumulated diagnostics/errors for this record

--- Creates a new LifecycleRecord.
---@param id string Unique identifier for the capability.
---@return LifecycleRecord
function M.new(id)
  local now = os.clock()
  return {
    state = M.STATES.DECLARED,
    id = id,
    history = { M.STATES.DECLARED },
    timestamps = { [M.STATES.DECLARED] = now },
    diags = {},
  }
end

--- Transitions a LifecycleRecord to a new state (Copy-on-Write).
---@param rec LifecycleRecord
---@param next_state M.STATES
---@param diag? table Optional diagnostic to add if transition fails or is an error state.
---@return LifecycleRecord  A new record if transition is valid, or the original if invalid/error.
function M.transition(rec, next_state, diag)
  -- FIX-AUDIT-P0-4 (2026-06-23): Operator-precedence bug.
  --   Old: `if A == ERROR or A == RUNNING and B ~= RUNNING then return rec end`
  --   Lua precedence `and` > `or` parses this as `(A == ERROR) or (A == RUNNING and B ~= RUNNING)`.
  --   When state=RUNNING and next_state=ERROR, the guard was true, so RUNNING→ERROR
  --   was wrongly rejected — contradicting the docstring "Any state can transition to ERROR"
  --   (file header line 25). Running capabilities could never be marked ERROR after a crash.
  --   Fix: explicitly exempt ERROR as a valid target from RUNNING.
  if
    rec.state == M.STATES.ERROR
    or (rec.state == M.STATES.RUNNING and next_state ~= M.STATES.RUNNING and next_state ~= M.STATES.ERROR)
  then
    -- Terminal states cannot transition, except RUNNING to itself or to ERROR
    return rec
  end

  local new_rec = util.deep_copy(rec)
  local current_time = os.clock()

  if next_state == M.STATES.ERROR then
    new_rec.state = M.STATES.ERROR
    table.insert(new_rec.history, M.STATES.ERROR)
    new_rec.timestamps[M.STATES.ERROR] = current_time
    if diag then
      table.insert(new_rec.diags, diag)
    end
    return new_rec
  end

  if
    LEGAL_TRANSITIONS[new_rec.state] == next_state
    or (new_rec.state == M.STATES.RUNNING and next_state == M.STATES.RUNNING)
  then
    new_rec.state = next_state
    table.insert(new_rec.history, next_state)
    new_rec.timestamps[next_state] = current_time
    if diag then
      table.insert(new_rec.diags, diag)
    end
  else
    -- Illegal transition, record an error and stay in current state or transition to ERROR
    -- FIX-AUDIT-P1-5: use domain.diagnostic for consistent shape (code/stage/node/message/severity)
    local error_diag = diagnostic.new(
      "lifecycle",
      rec.id,
      ("Illegal lifecycle transition for '%s': %s -> %s"):format(rec.id, rec.state, next_state),
      "error"
    )
    table.insert(new_rec.diags, error_diag)
    new_rec.state = M.STATES.ERROR
    table.insert(new_rec.history, M.STATES.ERROR)
    new_rec.timestamps[M.STATES.ERROR] = current_time
  end

  return new_rec
end

--- Checks if a LifecycleRecord is in a terminal state (RUNNING or ERROR).
---@param rec LifecycleRecord
---@return boolean
function M.is_terminal(rec)
  return rec.state == M.STATES.RUNNING or rec.state == M.STATES.ERROR
end

--- Checks if a LifecycleRecord is in the RUNNING state.
---@param rec LifecycleRecord
---@return boolean
function M.is_active(rec)
  return rec.state == M.STATES.RUNNING
end

---@class LifecycleManager
---@field records table<string, LifecycleRecord>

--- Creates a new LifecycleManager.
---@return LifecycleManager
function M.new_manager()
  return {
    records = {},
  }
end

--- Declares a new capability in the manager (Copy-on-Write).
---@param mgr LifecycleManager
---@param id string
---@return LifecycleManager  A new manager with the declared record.
function M.declare(mgr, id)
  local new_mgr = util.deep_copy(mgr)
  if not new_mgr.records[id] then
    new_mgr.records[id] = M.new(id)
  end
  return new_mgr
end

--- Advances the state of a capability in the manager (Copy-on-Write).
--- Automatically declares the record if it doesn't exist.
---@param mgr LifecycleManager
---@param id string
---@param next_state M.STATES
---@param diag? table
---@return LifecycleManager  A new manager with the updated record.
function M.advance(mgr, id, next_state, diag)
  local new_mgr = util.deep_copy(mgr)
  if not new_mgr.records[id] then
    new_mgr.records[id] = M.new(id)
  end
  new_mgr.records[id] = M.transition(new_mgr.records[id], next_state, diag)
  return new_mgr
end

--- Gets a LifecycleRecord by ID.
---@param mgr LifecycleManager
---@param id string
---@return LifecycleRecord|nil
function M.get(mgr, id)
  return mgr.records[id]
end

--- Gets all LifecycleRecords.
---@param mgr LifecycleManager
---@return table<string, LifecycleRecord>
function M.all(mgr)
  return mgr.records
end

--- Summarizes the counts of records by state.
---@param mgr LifecycleManager
---@return table<M.STATES, number>
function M.summary(mgr)
  local summary = {}
  for _, rec in pairs(mgr.records) do
    summary[rec.state] = (summary[rec.state] or 0) + 1
  end
  return summary
end

--- Collects all diagnostics from all records.
---@param mgr LifecycleManager
---@return table[]  Array of diagnostic tables.
function M.collect_diags(mgr)
  local all_diags = {}
  for _, rec in pairs(mgr.records) do
    for _, diag in ipairs(rec.diags) do
      table.insert(all_diags, diag)
    end
  end
  return all_diags
end

return M
