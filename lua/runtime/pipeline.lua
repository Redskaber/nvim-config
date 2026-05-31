-- lua/runtime/pipeline.lua
-- REFACTOR:
--   • debug_run() no longer calls cap_mod.reset() — global state eliminated.
--   • Each run gets a fresh IR via ir_mod.new(); collect pass uses cap_mod.new() internally.
--   • _G._ltos_debug_freeze activated in debug_run for mutation detection.
-- P2: Uses PhaseRegistry instead of hardcoded phases.

local M = {}

local ir_mod = require("core.compiler.ir")
local pass_mod = require("core.compiler.pass")
local util = require("core.kernel.util")
local phase_registry = require("runtime.phase_registry")

-- Load default phases and register them
--- Resolve a phase from a module path.
--- A pass module may export a Phase directly, or wrap it under `.pass`
--- (Phase Module Pattern: used by sub-passes like collect_ext, cap_resolve).
---@param mod_path string
---@return Phase
local function resolve_phase(mod_path)
  local mod = require(mod_path)
  -- Phase Module Pattern: module wraps phase under .pass
  if type(mod) == "table" and mod.pass ~= nil then
    return mod.pass
  end
  return mod
end

local function register_default_phases()
  local defaults = require("runtime.defaults.phases")
  for _, entry in ipairs(defaults.phases) do
    local phase = resolve_phase(entry.path)
    pass_mod.assert_valid(phase)
    phase_registry.register(phase, { priority = entry.priority })
  end
  local codegen = resolve_phase(defaults.codegen)
  pass_mod.assert_valid(codegen)
  phase_registry.register_codegen(codegen)
end

register_default_phases()

local function PHASES()
  return phase_registry.list()
end
local function CODEGEN()
  return phase_registry.codegen()
end

M.PHASE_ORDER = phase_registry.phase_order()

-- ── State machine ─────────────────────────────────────────────────────────────

local STATES = {
  IDLE = "idle",
  COLLECTING = "collecting",
  NORMALIZING = "normalizing",
  CANONICALIZING = "canonicalizing",
  RESOLVING = "resolving",
  OPTIMIZING = "optimizing",
  CODEGEN = "codegen",
  DONE = "done",
  ERROR = "error",
}

local TRANSITIONS = {
  idle = { collecting = true },
  collecting = { normalizing = true, error = true },
  normalizing = { canonicalizing = true, error = true },
  canonicalizing = { resolving = true, error = true },
  resolving = { optimizing = true, error = true },
  optimizing = { codegen = true, error = true },
  codegen = { done = true, error = true },
}

local PHASE_NEXT_SM = {
  collect = STATES.NORMALIZING,
  normalize = STATES.CANONICALIZING,
  canonicalize = STATES.RESOLVING,
  resolve = STATES.OPTIMIZING,
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

local last_run_sm = new_sm()

-- ── Executor ─────────────────────────────────────────────────────────────────

---@param lang_modules string[]
---@param profile      string
---@param stop_after?  string
---@param sm           table
---@param cached_caps? table
---@param ast_seed?    table
---@param build_request? BuildRequest
---@return IR, table[]|nil, table<string, number>
local function execute(lang_modules, profile, stop_after, sm, cached_caps, ast_seed, build_request)
  local ir = ir_mod.new(lang_modules, profile)
  local meta_patch = {}
  if ast_seed then
    meta_patch.ast_seed = ast_seed
  end
  if build_request then
    meta_patch.build_request = build_request
  end
  if next(meta_patch) ~= nil then
    ir = ir_mod.with(ir, { meta = util.merge(ir.meta or {}, meta_patch) })
  end
  local timings = {}

  local phases = PHASES()
  local codegen = CODEGEN()
  if not sm.transition(STATES.COLLECTING) then
    return ir, nil, timings
  end

  -- AST tier fast-path: inject cached caps, skip collect phase (TODO-7.1)
  if cached_caps then
    local ext_caps = (ast_seed and ast_seed.ext_caps) or ir.ext_caps
    ir = ir_mod.with(ir, { stage = "AST", caps = cached_caps, ext_caps = ext_caps })
    timings["collect"] = 0
    timings["collect_ext"] = 0
    if vim.g.ltos_debug or vim.g.ltos_debug_cache then
      vim.notify("[pipeline] AST cache hit — collect/collect_ext skipped", vim.log.levels.DEBUG)
    end
    -- Honor stop_after="collect" even when skipping the phase
    if stop_after == "collect" then
      return ir, nil, timings
    end
    -- Advance SM past collecting state
    local next_after_collect = PHASE_NEXT_SM["collect"]
    if next_after_collect and not sm.transition(next_after_collect) then
      return ir, nil, timings
    end
  end
  for _, phase in ipairs(phases) do
    if cached_caps and (phase.name == "collect" or phase.name == "collect_ext") then
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
  local pre = codegen.validate and codegen.validate(ir) or {}
  local specs = {}

  if #pre == 0 then
    if not sm.transition(STATES.CODEGEN) then
      return ir, nil, timings
    end
    local ok, result = pcall(codegen.build, ir)
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
---@param cached_caps? table
---@param ast_seed?    table
---@param build_request? BuildRequest
---@return table[]
---@return IR
function M.run(lang_modules, profile, cached_caps, ast_seed, build_request)
  local sm = new_sm()
  last_run_sm = sm

  local ir, specs, timings = execute(lang_modules, profile or "full", nil, sm, cached_caps, ast_seed, build_request)

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
---@param stop_after?  string
---@param profile?     string
---@param build_request? BuildRequest
---@return IR
---@return table[]|nil
function M.debug_run(lang_modules, stop_after, profile, build_request)
  local sm = new_sm()

  _G._ltos_debug_freeze = true

  local ir, specs, timings = execute(lang_modules, profile or "full", stop_after, sm, nil, nil, build_request)

  _G._ltos_debug_freeze = false

  ir._timings = timings
  if specs then
    ir._specs = specs
  end
  return ir, specs
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
