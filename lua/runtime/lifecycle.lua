-- lua/runtime/lifecycle.lua
-- Layer 4: coarse-grained runtime lifecycle SM (independent of pipeline.lua SM).

local M = {}

M.STATES = {
  BOOT = "BOOT",
  SCHEMA_LOAD = "SCHEMA_LOAD",
  COMPILE = "COMPILE",
  EMIT = "EMIT",
  READY = "READY",
  HOT_RELOAD = "HOT_RELOAD",
  ERROR = "ERROR",
}

local TRANSITIONS = {
  [M.STATES.BOOT] = { [M.STATES.SCHEMA_LOAD] = true, [M.STATES.ERROR] = true },
  [M.STATES.SCHEMA_LOAD] = { [M.STATES.COMPILE] = true, [M.STATES.ERROR] = true },
  [M.STATES.COMPILE] = { [M.STATES.EMIT] = true, [M.STATES.ERROR] = true },
  [M.STATES.EMIT] = { [M.STATES.READY] = true, [M.STATES.ERROR] = true },
  [M.STATES.READY] = { [M.STATES.HOT_RELOAD] = true, [M.STATES.ERROR] = true },
  [M.STATES.HOT_RELOAD] = { [M.STATES.SCHEMA_LOAD] = true, [M.STATES.ERROR] = true },
  [M.STATES.ERROR] = {},
}

local _state = M.STATES.BOOT
local _timestamps = { [M.STATES.BOOT:lower()] = os.clock() }
local _observers = {}
local _last_fail_reason = nil

local function notify_observers(next_state, prev_state)
  for _, fn in ipairs(_observers) do
    pcall(fn, next_state, prev_state)
  end
end

---@return string
function M.state() return _state end

---@param next_state string
---@return boolean
function M.transition(next_state)
  local allowed = TRANSITIONS[_state]
  if allowed and allowed[next_state] then
    local prev = _state
    _state = next_state
    _timestamps[next_state:lower()] = os.clock()
    notify_observers(next_state, prev)
    return true
  end
  M.fail(("illegal transition: %s → %s"):format(_state, next_state))
  return false
end

---@param reason? string
function M.fail(reason)
  local prev = _state
  _last_fail_reason = reason
  _state = M.STATES.ERROR
  _timestamps[M.STATES.ERROR:lower()] = os.clock()
  notify_observers(M.STATES.ERROR, prev)
end

---@return boolean
function M.is_ready() return _state == M.STATES.READY end

---@return boolean
function M.is_error() return _state == M.STATES.ERROR end

---@param fn fun(new_state: string, prev_state: string)
function M.observe(fn) _observers[#_observers + 1] = fn end

---@return table<string, number>
function M.timestamps() return _timestamps end

---@param state string
---@return number|nil
function M.elapsed(state)
  local ts = _timestamps[state:lower()]
  if not ts then
    return nil
  end
  return os.clock() - ts
end

--- Last failure reason (testing / diagnostics).
---@return string|nil
function M.last_fail_reason() return _last_fail_reason end

--- Reset SM (testing only).
function M._reset()
  _state = M.STATES.BOOT
  _timestamps = { [M.STATES.BOOT:lower()] = os.clock() }
  _observers = {}
  _last_fail_reason = nil
end

return M