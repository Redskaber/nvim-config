-- ~/.config/nvim/lua/runtime/pipeline.lua
-- Five-stage compilation pipeline with standard Pass interface (P0-2).
--
--   collect → normalize → resolve → optimize → codegen
--
-- Key invariants (P0-3):
--   • Every Pass returns a NEW IR; the input is never mutated.
--   • IR.clone() / IR.with() are used for copy-on-write semantics.
--   • Each run() / debug_run() call gets its own independent state machine.
--   • No module-level mutable state except `last_run_sm` (for M.state()).
--
-- Pass interface (P0-2):
--   { name, validate?(IR)->CompileError[], run(IR)->IR }

local M = {}

local ir_mod = require("core.ir")
local pass_mod = require("core.pass")

-- ── State Machine ────────────────────────────────────────────────────────────

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
  function sm.transition(next)
    local allowed = TRANSITIONS[sm.state]
    if allowed and allowed[next] then
      sm.state = next
      sm.timestamps[next] = os.clock()
      return true
    end
    vim.notify(("[pipeline] illegal transition: %s → %s"):format(sm.state, next), vim.log.levels.ERROR)
    sm.state = STATES.ERROR
    return false
  end
  return sm
end

-- Track the most recent run() state machine for M.state().
local last_run_sm = new_sm()

-- ── Pass definitions ─────────────────────────────────────────────────────────

--- Pass 1 – collect
--- Loads each lang module, validates via schema, builds capability registry,
--- and returns a snapshot into IR.caps.  IR is constructed with ir.new().
local collect_pass = {
  name = "collect",

  ---@param ir IR
  ---@return IR
  run = function(ir)
    local registry = require("core.capability")
    local lang_modules = ir.meta.lang_modules or {}

    local next_ir = ir_mod.clone(ir)
    next_ir.caps = {}

    for _, mod in ipairs(lang_modules) do
      local ok, result = pcall(require, mod)
      if not ok then
        local err = ir_mod.error("collect", mod, "failed to load: " .. tostring(result))
        next_ir = ir_mod.append_error(next_ir, err)
        vim.notify("[pipeline.collect] " .. err.message, vim.log.levels.WARN)
      elseif type(result) == "table" then
        local name = mod:match("([^.]+)$") or mod
        local add_ok, add_err = pcall(registry.add, name, result)
        if not add_ok then
          local err = ir_mod.error("collect", mod, "schema validation failed: " .. tostring(add_err))
          next_ir = ir_mod.append_error(next_ir, err)
          vim.notify("[pipeline.collect] " .. err.message, vim.log.levels.WARN)
        end
      else
        local err = ir_mod.error("collect", mod, "module did not return a table; skipping")
        next_ir = ir_mod.append_error(next_ir, err)
        vim.notify("[pipeline.collect] " .. err.message, vim.log.levels.WARN)
      end
    end

    -- Snapshot registry into IR (deep-copy → registry is independent)
    next_ir.caps = registry.snapshot()
    return next_ir
  end,
}

--- Pass 2 – normalize
--- Resolves FormatterNode.strategy → FormatterNode.fn via the strategy registry.
--- Operates entirely on deep-copies; the shared registry is never mutated.
local normalize_pass = {
  name = "normalize",

  validate = function(ir)
    return ir_mod.validate(ir, "normalize")
  end,

  ---@param ir IR
  ---@return IR
  run = function(ir)
    local strategies = require("toolchain.strategies")
    local next_caps = {}

    for lang, cap in pairs(ir.caps) do
      if cap.formatters then
        local patched_formatters = {}
        local cap_patched = false

        for ft, fmts in pairs(cap.formatters) do
          -- fmts is always a list (raw functions rejected by schema)
          local patched_list = nil -- lazy-init on first mutation

          for i, v in ipairs(fmts) do
            if type(v) == "table" and v.kind == "formatter" and v.strategy and not v.fn then
              if not patched_list then
                patched_list = vim.deepcopy(fmts)
              end
              local strat = strategies.get(v.strategy)
              if strat then
                patched_list[i].fn = strat.resolve
              else
                vim.notify("[pipeline.normalize] unknown formatter strategy: " .. v.strategy, vim.log.levels.WARN)
                patched_list[i].fn = function()
                  return {}
                end
              end
              cap_patched = true
            end
          end

          patched_formatters[ft] = patched_list or fmts -- share original if unchanged
        end

        if cap_patched then
          -- Shallow-copy cap, replacing only the formatters field
          local new_cap = {}
          for k, v in pairs(cap) do
            new_cap[k] = v
          end
          new_cap.formatters = patched_formatters
          next_caps[lang] = new_cap
        else
          next_caps[lang] = cap
        end
      else
        next_caps[lang] = cap
      end
    end

    return ir_mod.with(ir, { caps = next_caps })
  end,
}

--- Pass 3 – resolve
--- Decides use_mason for every LSP server and tool; writes IR.resolved.
local resolve_pass = {
  name = "resolve",

  validate = function(ir)
    return ir_mod.validate(ir, "resolve")
  end,

  ---@param ir IR
  ---@return IR
  run = function(ir)
    local rules = require("toolchain.rules")
    local resolved = { lsp = {}, tools = {} }

    for _, cap in pairs(ir.caps) do
      if cap.lsp then
        for server, cfg in pairs(cap.lsp) do
          resolved.lsp[server] = rules.use_mason(server) and (cfg.mason ~= false)
        end
      end

      local function mark_tools(tbl)
        if not tbl then
          return
        end
        for _, list in pairs(tbl) do
          if type(list) == "table" then
            for _, item in ipairs(list) do
              -- Only plain strings are tool names; FormatterNodes have .kind
              if type(item) == "string" then
                resolved.tools[item] = rules.use_mason(item)
              end
            end
          end
        end
      end

      mark_tools(cap.formatters)
      mark_tools(cap.linters)

      if cap.mason then
        for _, t in ipairs(cap.mason) do
          resolved.tools[t] = rules.use_mason(t)
        end
      end
    end

    return ir_mod.with(ir, { resolved = resolved })
  end,
}

--- Pass 4 – optimize
--- Deduplicates treesitter parsers; merges LSP configs.
local optimize_pass = {
  name = "optimize",

  validate = function(ir)
    return ir_mod.validate(ir, "optimize")
  end,

  ---@param ir IR
  ---@return IR
  run = function(ir)
    local util = require("core.util")

    -- Deduplicate treesitter parsers
    local all_parsers = {}
    for _, cap in pairs(ir.caps) do
      if cap.treesitter then
        vim.list_extend(all_parsers, cap.treesitter)
      end
    end

    -- Merge LSP configs (later overrides earlier on conflict)
    local merged_lsp = {}
    for _, cap in pairs(ir.caps) do
      if cap.lsp then
        for server, cfg in pairs(cap.lsp) do
          merged_lsp[server] = merged_lsp[server] and vim.tbl_deep_extend("force", merged_lsp[server], cfg)
            or vim.deepcopy(cfg)
        end
      end
    end

    return ir_mod.with(ir, {
      all_parsers = util.dedup(all_parsers),
      merged_lsp = merged_lsp,
    })
  end,
}

--- Pass 5 – codegen (terminal: produces LazySpec[], not a new IR)
--- This pass is special: it calls into adapters and returns spec[], not IR.
--- The pipeline runner handles this distinction.
local codegen_pass = {
  name = "codegen",

  validate = function(ir)
    return ir_mod.validate(ir, "codegen")
  end,

  ---@param ir IR
  ---@return table[]  LazySpec list
  build = function(ir)
    local adapters = {
      require("runtime.adapters.lsp"),
      require("runtime.adapters.mason"),
      require("runtime.adapters.treesitter"),
      require("runtime.adapters.conform"),
      require("runtime.adapters.lint"),
    }

    local specs = {}
    for _, adapter in ipairs(adapters) do
      local ok, result = pcall(adapter.build, ir)
      if ok then
        for _, spec in ipairs(result) do
          specs[#specs + 1] = spec
        end
      else
        vim.notify(
          "[pipeline.codegen] adapter " .. tostring(adapter) .. " failed: " .. tostring(result),
          vim.log.levels.WARN
        )
      end
    end
    return specs
  end,
}

-- Ordered pass list (all transforming passes; codegen is separate)
local PASSES = { collect_pass, normalize_pass, resolve_pass, optimize_pass }

-- ── Internal runner ───────────────────────────────────────────────────────────

local STAGE_TO_SM = {
  collect = STATES.COLLECTING,
  normalize = STATES.NORMALIZING,
  resolve = STATES.RESOLVING,
  optimize = STATES.OPTIMIZING,
  codegen = STATES.CODEGEN,
}

--- Run passes up to (and including) `stop_after` (nil = all + codegen).
---@param lang_modules string[]
---@param profile      string
---@param stop_after?  string
---@param sm           table
---@return IR, table[]|nil, table<string, number>
local function execute(lang_modules, profile, stop_after, sm)
  local ir = ir_mod.new(lang_modules, profile)
  local timings = {}

  sm.transition(STATES.COLLECTING)

  for _, pass in ipairs(PASSES) do
    local t0 = os.clock()
    local next_ir, errs = pass_mod.run_pass(pass, ir)
    timings[pass.name] = os.clock() - t0

    ir = next_ir

    if #errs > 0 and not stop_after then
      -- Non-fatal: continue; errors are embedded in IR
    end

    -- Advance state machine
    local next_sm_state = STAGE_TO_SM[pass.name]
    if next_sm_state then
      -- State is already set by transition(); advance to next
      local sm_steps = { "collecting", "normalizing", "resolving", "optimizing" }
      for i, s in ipairs(sm_steps) do
        if s == next_sm_state then
          if sm_steps[i + 1] then
            sm.transition(sm_steps[i + 1])
          end
          break
        end
      end
    end

    if stop_after == pass.name then
      return ir, nil, timings
    end
  end

  -- Codegen
  local t0 = os.clock()
  local pre = codegen_pass.validate and codegen_pass.validate(ir) or {}
  local specs = {}
  if #pre == 0 then
    sm.transition(STATES.CODEGEN)
    local ok, result = pcall(codegen_pass.build, ir)
    if ok then
      specs = result
    else
      vim.notify("[pipeline.codegen] failed: " .. tostring(result), vim.log.levels.ERROR)
      sm.state = STATES.ERROR
    end
  else
    for _, e in ipairs(pre) do
      ir = ir_mod.append_error(ir, e)
    end
    sm.state = STATES.ERROR
  end
  timings.codegen = os.clock() - t0

  return ir, specs, timings
end

-- ── Public API ───────────────────────────────────────────────────────────────

--- Run the full pipeline and return lazy.nvim plugin specs.
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

  -- Report accumulated errors in a single WARN
  if ir.errors and #ir.errors > 0 then
    vim.notify(
      ("[pipeline] build completed with %d error(s):\n%s"):format(#ir.errors, ir_mod.format_errors(ir)),
      vim.log.levels.WARN
    )
  end

  return specs or {}
end

--- Run the pipeline up to `stop_after` stage and return the IR snapshot.
--- The capability registry is reset before this run to avoid accumulation.
---@param lang_modules string[]
---@param stop_after?  "collect"|"normalize"|"resolve"|"optimize"
---@param profile?     string
---@return IR
function M.debug_run(lang_modules, stop_after, profile)
  local sm = new_sm()

  -- Reset registry to avoid accumulation across debug runs
  require("core.capability").reset()

  local ir, _, timings = execute(lang_modules, profile or "full", stop_after, sm)

  -- Attach timings to IR for :LtosDebug display
  ir._timings = timings

  return ir
end

--- Return the state string of the most recent run() call (for :LtosInfo).
---@return string
function M.state()
  return last_run_sm.state
end

return M
