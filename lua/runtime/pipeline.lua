-- ~/.config/nvim/lua/runtime/pipeline.lua
-- Compiler kernel: five-phase compilation pipeline.
--
-- State machine (TODO-1.2) — 8 canonical states:
--   IDLE → COLLECTING → NORMALIZING → RESOLVING → OPTIMIZING → CODEGEN → DONE
--                                                                       ↘ ERROR
--
-- Each Phase declares input_state / output_state; the runner validates every
-- transition before execution.  Illegal transitions always go to ERROR.
--
-- CompilerContext (TODO-1.1) flows through each Phase:
--   { ir, stage, diagnostics, cache_key, timings }
--
-- Key invariants:
--   • Every Phase returns a NEW IR (copy-on-write via ir.with / ir.clone).
--   • The input IR is never mutated.
--   • Each run() / debug_run() gets its own independent state machine instance.
--   • Non-fatal errors are accumulated in IR.diagnostics; pipeline continues.
--   • Fatal errors (codegen pre-condition failure) abort and set ERROR state.

local M = {}

local ir_mod = require("core.ir")
local pass_mod = require("core.pass")

-- ── Phases (loaded once; stateless) ──────────────────────────────────────────

local PHASES = {
  require("runtime.passes.collect"),
  require("runtime.passes.normalize"),
  require("runtime.passes.resolve"),
  require("runtime.passes.optimize"),
}
local CODEGEN = require("runtime.passes.codegen")

-- Validate all phases at load time (fail loud on misconfiguration)
for _, p in ipairs(PHASES) do
  pass_mod.assert_valid(p)
end

-- ── State machine ─────────────────────────────────────────────────────────────

local STATES = {
  IDLE = "idle",
  COLLECTING = "collecting",
  NORMALIZING = "normalizing",
  RESOLVING = "resolving",
  OPTIMIZING = "optimizing",
  CODEGEN = "codegen",
  DONE = "done",
  ERROR = "error",
}

-- Allowed state transitions (adjacency map)
local TRANSITIONS = {
  idle = { collecting = true },
  collecting = { normalizing = true, error = true },
  normalizing = { resolving = true, error = true },
  resolving = { optimizing = true, error = true },
  optimizing = { codegen = true, error = true },
  codegen = { done = true, error = true },
}

---@return table  state machine instance
local function new_sm()
  local sm = { state = STATES.IDLE, timestamps = {} }

  function sm.transition(next_state)
    local allowed = TRANSITIONS[sm.state]
    if allowed and allowed[next_state] then
      sm.state = next_state
      sm.timestamps[next_state] = os.clock()
      return true
    end
    vim.notify(("[pipeline] illegal transition: %s → %s"):format(sm.state, next_state), vim.log.levels.ERROR)
    sm.state = STATES.ERROR
    return false
  end

  function sm.fail()
    sm.state = STATES.ERROR
  end

  return sm
end

-- Phase name → SM state (for advancing after each pass).
-- Maps each phase's completion to the *entry* state of the next phase.
-- "optimize" completes at OPTIMIZING; the codegen block itself transitions to CODEGEN.
local PHASE_NEXT_SM = {
  collect = STATES.NORMALIZING,
  normalize = STATES.RESOLVING,
  resolve = STATES.OPTIMIZING,
  -- optimize intentionally omitted: codegen block owns the OPTIMIZING → CODEGEN transition
}

-- Track the most recent run() state machine for M.state()
local last_run_sm = new_sm()

-- ── Internal executor ─────────────────────────────────────────────────────────

--- Run phases up to (and including) `stop_after`; nil = run all + codegen.
---@param lang_modules string[]
---@param profile      string
---@param stop_after?  string   phase name to halt at
---@param sm           table    state machine instance
---@return IR, table[]|nil, table<string, number>
local function execute(lang_modules, profile, stop_after, sm)
  local ir = ir_mod.new(lang_modules, profile)
  local timings = {}

  -- Kick off state machine
  if not sm.transition(STATES.COLLECTING) then
    return ir, nil, timings
  end

  for _, phase in ipairs(PHASES) do
    local t0 = os.clock()
    local next_ir, errs = pass_mod.run_phase(phase, ir)
    timings[phase.name] = os.clock() - t0
    ir = next_ir

    -- Non-fatal errors: embedded in IR.diagnostics; pipeline continues.
    -- (Fatal errors are detected at codegen pre-condition time.)

    if stop_after == phase.name then
      return ir, nil, timings
    end

    -- Advance state machine to next phase's entry state
    local next_sm_state = PHASE_NEXT_SM[phase.name]
    if next_sm_state and not sm.transition(next_sm_state) then
      -- Illegal transition → ERROR state; abort
      return ir, nil, timings
    end

    -- If too many errors accumulated, surface them but keep going
    local counts = ir_mod.diag_counts(ir)
    if counts.errors > 0 and vim.g.ltos_debug then
      vim.notify(("[pipeline.%s] %d error(s) accumulated"):format(phase.name, counts.errors), vim.log.levels.DEBUG)
    end
  end

  -- ── Codegen (terminal phase) ──────────────────────────────────────────────
  local t0 = os.clock()
  local pre = CODEGEN.validate and CODEGEN.validate(ir) or {}
  local specs = {}

  if #pre == 0 then
    if not sm.transition(STATES.CODEGEN) then
      return ir, nil, timings
    end
    local ok, result = pcall(CODEGEN.build, ir)
    if ok then
      specs = result
    else
      vim.notify("[pipeline.codegen] build failed: " .. tostring(result), vim.log.levels.ERROR)
      sm.fail()
    end
  else
    -- Codegen pre-condition failures are fatal
    for _, d in ipairs(pre) do
      ir = ir_mod.append_diag(ir, d)
    end
    sm.fail()
  end
  timings.codegen = os.clock() - t0

  return ir, specs, timings
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Run the full pipeline; return LazySpec[].
---@param lang_modules string[]
---@param profile?     string
---@return table[]
function M.run(lang_modules, profile)
  local sm = new_sm()
  last_run_sm = sm

  local ir, specs, timings = execute(lang_modules, profile or "full", nil, sm)

  if sm.state ~= STATES.ERROR then
    sm.transition(STATES.DONE)
  end

  -- Persist timings for :LtosInfo
  vim.g.ltos_last_build_timings = timings

  -- Surface accumulated diagnostics
  local counts = ir_mod.diag_counts(ir)
  if counts.errors > 0 or counts.warns > 0 then
    vim.notify(
      ("[pipeline] build completed with %d error(s), %d warning(s):\n%s"):format(
        counts.errors,
        counts.warns,
        ir_mod.format_diagnostics(ir)
      ),
      counts.errors > 0 and vim.log.levels.WARN or vim.log.levels.INFO
    )
  end

  return specs or {}
end

--- Run up to `stop_after` stage; return IR snapshot (for :LtosDebug).
--- Resets capability registry to avoid accumulation across debug runs.
---@param lang_modules string[]
---@param stop_after?  "collect"|"normalize"|"resolve"|"optimize"
---@param profile?     string
---@return IR
function M.debug_run(lang_modules, stop_after, profile)
  local sm = new_sm()

  -- Isolated run: reset registry
  require("core.capability").reset()

  local ir, _, timings = execute(lang_modules, profile or "full", stop_after, sm)

  -- Attach timings as internal field for :LtosDebug display
  ir._timings = timings

  return ir
end

--- Return the state string of the most recent run() call.
---@return string
function M.state()
  return last_run_sm.state
end

--- Return per-phase timings from the most recent run() call (ms).
---@return table<string, number>|nil
function M.timings()
  return vim.g.ltos_last_build_timings
end

return M
