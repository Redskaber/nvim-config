-- lua/runtime/pipeline.lua
-- REFACTOR:
--   • debug_run() no longer calls cap_mod.reset() — global state eliminated.
--   • Each run gets a fresh IR via ir_mod.new(); collect pass uses cap_mod.new() internally.
--   • _G._ltos_debug_freeze activated in debug_run for mutation detection.

local M = {}

local ir_mod = require("core.compiler.ir")
local pass_mod = require("core.compiler.pass")

local PHASES = {
  require("runtime.passes.collect"),
  require("runtime.passes.normalize"),
  require("runtime.passes.resolve"),
  require("runtime.passes.optimize"),
}
local CODEGEN = require("runtime.passes.codegen")

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

local TRANSITIONS = {
  idle = { collecting = true },
  collecting = { normalizing = true, error = true },
  normalizing = { resolving = true, error = true },
  resolving = { optimizing = true, error = true },
  optimizing = { codegen = true, error = true },
  codegen = { done = true, error = true },
}

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

local PHASE_NEXT_SM = {
  collect = STATES.NORMALIZING,
  normalize = STATES.RESOLVING,
  resolve = STATES.OPTIMIZING,
}

local last_run_sm = new_sm()

-- ── Executor ─────────────────────────────────────────────────────────────────

---@param lang_modules string[]
---@param profile      string
---@param stop_after?  string
---@param sm           table
---@param cached_caps? table   pre-validated caps from AST tier (skips collect)
---@return IR, table[]|nil, table<string, number>
local function execute(lang_modules, profile, stop_after, sm, cached_caps)
  local ir = ir_mod.new(lang_modules, profile)
  local timings = {}

  if not sm.transition(STATES.COLLECTING) then
    return ir, nil, timings
  end

  -- AST tier fast-path: inject cached caps, skip collect phase (TODO-7.1)
  if cached_caps then
    ir = ir_mod.with(ir, { stage = "AST", caps = cached_caps })
    timings["collect"] = 0
    if vim.g.ltos_debug or vim.g.ltos_debug_cache then
      vim.notify("[pipeline] AST cache hit — collect phase skipped", vim.log.levels.DEBUG)
    end
    -- Advance SM past collecting state
    if not sm.transition(STATES.NORMALIZING) then
      return ir, nil, timings
    end
  end
  for _, phase in ipairs(PHASES) do
    -- Skip collect if AST cache was used (already advanced SM past collecting)
    if cached_caps and phase.name == "collect" then
      goto continue
    end
    local t0 = os.clock()
    local next_ir, _ = pass_mod.run_phase(phase, ir)
    timings[phase.name] = os.clock() - t0
    ir = next_ir

    if stop_after == phase.name then
      return ir, nil, timings
    end

    local next_sm_state = PHASE_NEXT_SM[phase.name]
    if next_sm_state and not sm.transition(next_sm_state) then
      return ir, nil, timings
    end

    local counts = ir_mod.diag_counts(ir)
    if counts.errors > 0 and vim.g.ltos_debug then
      vim.notify(("[pipeline.%s] %d error(s)"):format(phase.name, counts.errors), vim.log.levels.DEBUG)
    end
    if vim.g.ltos_debug_perf then
      vim.notify(
        ("[pipeline.perf] %s=%.3fms"):format(phase.name, (timings[phase.name] or 0) * 1000),
        vim.log.levels.DEBUG
      )
    end
    ::continue::
  end

  -- Codegen
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
    for _, d in ipairs(pre) do
      ir = ir_mod.append_diag(ir, d)
    end
    sm.fail()
  end
  timings.codegen = os.clock() - t0

  return ir, specs, timings
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Run a sub-set of phases against an existing IR (no SM involvement).
--- Useful for bootstrap sub-flows (formatter resolution, LSP merge).
---@param phases Phase[]
---@param ir     IR
---@return IR, Diagnostic[]
function M.run_sub(phases, ir)
  local all_diags = {}
  local cur = ir
  for _, phase in ipairs(phases) do
    pass_mod.assert_valid(phase)
    local next_ir, diags = pass_mod.run_phase(phase, cur)
    for _, d in ipairs(diags) do
      all_diags[#all_diags + 1] = d
    end
    cur = next_ir
  end
  return cur, all_diags
end
---@param lang_modules string[]
---@param profile?     string
---@param cached_caps? table   AST-tier cached caps for incremental rebuild
---@return table[]   specs
---@return IR        final IR (for AST cache persistence)
function M.run(lang_modules, profile, cached_caps)
  local sm = new_sm()
  last_run_sm = sm

  local ir, specs, timings = execute(lang_modules, profile or "full", nil, sm, cached_caps)

  if sm.state ~= STATES.ERROR then
    sm.transition(STATES.DONE)
  end

  vim.g.ltos_last_build_timings = timings

  local counts = ir_mod.diag_counts(ir)
  if counts.errors > 0 or counts.warns > 0 then
    vim.notify(
      ("[pipeline] %d error(s), %d warning(s):\n%s"):format(counts.errors, counts.warns, ir_mod.format_diagnostics(ir)),
      counts.errors > 0 and vim.log.levels.WARN or vim.log.levels.INFO
    )
  end

  -- TODO-0.3: structured debug output (JSON lines) when LTOS_DEBUG=trace
  if vim.g.ltos_debug_trace then
    local ok, encoded = pcall(vim.json.encode, {
      event = "pipeline.done",
      run_id = sm.timestamps and tostring(sm.timestamps.collecting) or "?",
      profile = profile or "full",
      modules = #lang_modules,
      specs = #(specs or {}),
      timings = timings,
      errors = counts.errors,
      warns = counts.warns,
    })
    if ok then
      vim.notify("[ltos:trace] " .. encoded, vim.log.levels.DEBUG)
    end
  end

  return specs or {}, ir
end

---@param lang_modules string[]
---@param stop_after?  "collect"|"normalize"|"resolve"|"optimize"
---@param profile?     string
---@return IR
function M.debug_run(lang_modules, stop_after, profile)
  local sm = new_sm()

  -- Enable freeze mode for mutation detection
  _G._ltos_debug_freeze = true

  local ir, _, timings = execute(lang_modules, profile or "full", stop_after, sm, nil)

  _G._ltos_debug_freeze = false

  ir._timings = timings
  return ir
end

---@return string
function M.state()
  return last_run_sm.state
end

---@return table<string, number>|nil
function M.timings()
  return vim.g.ltos_last_build_timings
end

return M
