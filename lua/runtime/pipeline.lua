-- lua/runtime/pipeline.lua
-- REFACTOR:
--   • debug_run() no longer calls cap_mod.reset() — global state eliminated.
--   • Each run gets a fresh IR via ir_mod.new(); collect pass uses cap_mod.new() internally.
--   • _G._ltos_debug_freeze activated in debug_run for mutation detection.
-- P2: Uses PhaseRegistry instead of hardcoded phases.

local M = {}

-- module-level storage for last build timings.
-- Replaces vim.g.ltos_last_build_timings — pipeline no longer writes vim.g.
-- M.timings() returns this value.
local _last_build_timings = {}

local ir_mod = require("core.compiler.ir")
local pass_mod = require("core.compiler.pass")
local phase_registry = require("runtime.phase_registry")
local ports = require("core.compiler.ports") -- OPT-J: for notify
local util = require("core.kernel.util")

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

-- REVERTED to require-time register_default_phases(). Original P1-2b fix broke
-- the test suite's module-reload pattern: tests do
--   package.loaded["runtime.pipeline"] = nil; require("runtime.pipeline")
-- to reset state, which relies on require-time side effect to re-register
-- default phases. Also phase_registry.register() does NOT deduplicate (appends
-- to array), so setup() with _setup_done flag would leave phases empty after
-- pr._reset() (called in 11+ test cases).
-- Design decision: pipeline.lua is the ORCHESTRATOR (Layer 4), not a pluggable
-- registry (like cap_registry/adapter_registry which ARE P6-C2 targets).
-- Require-time initialization is acceptable for the orchestrator.
-- check_layer_boundaries.sh rule 7c excludes pipeline.lua for this reason.
register_default_phases()

local function PHASES() return phase_registry.list() end
local function CODEGEN() return phase_registry.codegen() end

-- FIX-P2-3 (2026-06-26): M.PHASE_ORDER is now a PLAIN TABLE that stays in
-- sync with the phase registry via a listener callback.
--
-- Previous attempt used a metatable proxy (__index/__len/__pairs/__ipairs),
-- but LuaJIT's `#` operator and `ipairs()` do not reliably honour __len /
-- __ipairs on proxy tables, which broke 9 tests that do:
--   `for i, p in ipairs(pipeline.PHASE_ORDER) do ... end`
--   `#pipeline.PHASE_ORDER >= 8`
--   `pipeline.PHASE_ORDER[#pipeline.PHASE_ORDER]`
--
-- The new approach: M.PHASE_ORDER is a real table (so # and ipairs work
-- natively), and its contents are repopulated whenever the phase registry
-- mutates (register / register_codegen / _reset). The listener is attached
-- AFTER register_default_phases() so the initial population happens via
-- the same code path as all subsequent updates.
M.PHASE_ORDER = {}

--- Refresh M.PHASE_ORDER from the current registry state.
--- Called as a phase_registry listener on every mutation, and once
--- explicitly here to populate the initial value.
local function refresh_phase_order()
  -- Wipe and repopulate the existing table in-place so that any external
  -- reference to M.PHASE_ORDER (e.g. tests holding a local alias) sees
  -- the updated contents — the table identity stays stable.
  for i = #M.PHASE_ORDER, 1, -1 do
    M.PHASE_ORDER[i] = nil
  end
  for _, name in ipairs(phase_registry.phase_order()) do
    M.PHASE_ORDER[#M.PHASE_ORDER + 1] = name
  end
end

-- Initial population + attach listener so future register() calls
-- automatically refresh M.PHASE_ORDER. This closes P2-3 (stale snapshot)
-- without resorting to a metatable proxy (which broke ipairs/# in LuaJIT).
refresh_phase_order()
phase_registry.add_listener(refresh_phase_order)

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

-- FIX-P2-2 (2026-06-26): SM transitions are now derived from each Phase's
-- `output_state` field, eliminating the hardcoded PHASE_NEXT_SM table that
-- was previously decoupled from Phase metadata.
--
-- Rule:
--   • If phase.output_state == phase.input_state → side phase, no SM transition
--     (e.g. collect_ext, cap_resolve stay in the same state)
--   • If phase.output_state ~= phase.input_state → sm.transition(output_state)
--     (e.g. normalize: collecting → normalizing)
--
-- This makes Phase.input_state / output_state the single source of truth for
-- SM behaviour. Previously PHASE_NEXT_SM was a separate table that had to be
-- kept in sync manually, and its values did not always match the next phase's
-- declared input_state (e.g. collect_ext.input_state="collecting" but SM was
-- already advanced to "normalizing" by PHASE_NEXT_SM["collect"]).
--
-- The TRANSITIONS table below already permits every output_state → next_state
-- edge used by the 8 default phases; no change needed there.
local TRANSITIONS = {
  idle = { collecting = true },
  collecting = { normalizing = true, error = true },
  normalizing = { canonicalizing = true, error = true },
  canonicalizing = { resolving = true, error = true },
  resolving = { optimizing = true, error = true },
  optimizing = { codegen = true, error = true },
  codegen = { done = true, error = true },
}

--- Derive the next SM state from a phase's declared output_state.
--- Returns nil when no transition is needed:
---   • side phase: output_state == input_state (e.g. collect_ext, cap_resolve)
---   • no-op: output_state == current SM state (e.g. collect — SM already
---     transitioned to COLLECTING before the loop, so collect.output_state
---     "collecting" matches current state)
---@param phase Phase
---@param current_state string  current SM state
---@return string|nil
local function next_sm_state_for(phase, current_state)
  if phase.output_state == phase.input_state then
    return nil -- side phase: stays in current SM state
  end
  if phase.output_state == current_state then
    return nil -- no-op: SM already in the target state
  end
  return phase.output_state
end

local function new_sm()
  local sm = { state = STATES.IDLE, timestamps = {} }

  function sm.transition(next_state)
    local allowed = TRANSITIONS[sm.state]
    if allowed and allowed[next_state] then
      sm.state = next_state
      sm.timestamps[next_state] = os.clock()
      return true
    end
    ports.notify(
      vim.log.levels.ERROR,
      ("[pipeline] illegal transition: %s → %s"):format(sm.state, next_state)
    ) -- OPT-J
    sm.state = STATES.ERROR
    return false
  end

  function sm.fail() sm.state = STATES.ERROR end

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
  -- FIX-DEPLOY-TEST (2026-06-23): auto-inject build_request when not passed.
  -- This ensures ir.meta.build_request is always populated after pipeline.run(),
  -- which full_pipeline_spec tests expect. Previously build_request was only
  -- injected when explicitly passed as 5th arg.
  if not build_request then
    local ok, br_mod = pcall(require, "runtime.build_request")
    if ok and br_mod and br_mod.from_vim then
      build_request = br_mod.from_vim(profile or "full", lang_modules)
    end
  end
  if build_request then
    meta_patch.build_request = build_request
  end
  if next(meta_patch) ~= nil then
    ir = ir_mod.with(ir, { meta = util.merge(ir.meta or {}, meta_patch) })
  end
  -- OPT-G: extract debug flags from build_request (not vim.g)
  local dbg = (build_request and build_request.debug) or {}
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
    if dbg.enabled or dbg.cache then
      ports.notify(vim.log.levels.DEBUG, "[pipeline] AST cache hit — collect/collect_ext skipped") -- OPT-J
    end
    -- Honor stop_after="collect" even when skipping the phase
    if stop_after == "collect" then
      return ir, nil, timings
    end
    -- FIX-P2-2: SM is already in COLLECTING (transitioned above before the
    -- cache-hit branch). The old code advanced SM to NORMALIZING via
    -- PHASE_NEXT_SM["collect"], but that was inconsistent with
    -- collect_ext.input_state="collecting". New behaviour: leave SM in
    -- COLLECTING; the next non-skipped phase (normalize) will transition
    -- SM to NORMALIZING via its own output_state.
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

    -- FIX-P2-2: derive next SM state from the phase's declared output_state.
    -- Side phases (output_state == input_state) and no-ops (output_state ==
    -- current SM state) return nil → no transition.
    local next_sm_state = next_sm_state_for(phase, sm.state)
    if next_sm_state and not sm.transition(next_sm_state) then
      return ir, nil, timings
    end

    local counts = ir_mod.diag_counts(ir)
    if counts.errors > 0 and dbg.enabled then
      ports.notify(
        vim.log.levels.DEBUG,
        ("[pipeline.%s] %d error(s)"):format(phase.name, counts.errors)
      ) -- OPT-J
    end
    if dbg.perf then
      ports.notify(
        vim.log.levels.DEBUG,
        ("[pipeline.perf] %s=%.3fms"):format(phase.name, (timings[phase.name] or 0) * 1000)
      ) -- OPT-J
    end
    ::continue::
  end

  -- Codegen
  local t0 = os.clock()
  local pre = codegen.validate and codegen.validate(ir) or {}
  local specs = {}

  if #pre == 0 then
    -- FIX-P2-2: derive codegen SM transition from codegen.output_state,
    -- consistent with the main loop. codegen.output_state="codegen",
    -- current state="optimizing" → transition to "codegen".
    local cg_next = next_sm_state_for(codegen, sm.state)
    if cg_next and not sm.transition(cg_next) then
      return ir, nil, timings
    end
    local ok, result = pcall(codegen.build, ir)
    if ok then
      specs = result
    else
      ports.notify(vim.log.levels.ERROR, "[pipeline.codegen] build failed: " .. tostring(result)) -- OPT-J
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

  local ir, specs, timings =
    execute(lang_modules, profile or "full", nil, sm, cached_caps, ast_seed, build_request)

  if sm.state ~= STATES.ERROR then
    sm.transition(STATES.DONE)
  end

  -- OPT-G: store in module var instead of vim.g
  _last_build_timings = timings

  local counts = ir_mod.diag_counts(ir)
  if counts.errors > 0 or counts.warns > 0 then
    ports.notify(
      counts.errors > 0 and vim.log.levels.WARN or vim.log.levels.INFO,
      ("[pipeline] %d error(s), %d warning(s):\n%s"):format(
        counts.errors,
        counts.warns,
        ir_mod.format_diagnostics(ir)
      )
    ) -- OPT-J
  end

  -- OPT-G: read debug flags from IR meta (set by execute via build_request)
  local run_dbg = (ir.meta and ir.meta.build_request and ir.meta.build_request.debug) or {}
  if run_dbg.trace then
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
      ports.notify(vim.log.levels.DEBUG, "[ltos:trace] " .. encoded) -- OPT-J
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

  local ir, specs, timings =
    execute(lang_modules, profile or "full", stop_after, sm, nil, nil, build_request)

  _G._ltos_debug_freeze = false

  ir._timings = timings
  if specs then
    ir._specs = specs
  end
  return ir, specs
end

---@return string
function M.state() return last_run_sm.state end

---@return table<string, number>|nil
function M.timings()
  -- OPT-G: return module-level var instead of vim.g
  -- FIX-POLISH-2 (2026-06-26): return a shallow copy so callers cannot
  -- mutate the internal _last_build_timings table. Mirrors the P1-11
  -- pattern in modules/capability/registry.lua get_by_type().
  local copy = {}
  for k, v in pairs(_last_build_timings) do
    copy[k] = v
  end
  return copy
end

return M