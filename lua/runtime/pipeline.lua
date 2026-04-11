-- ~/.config/nvim/lua/runtime/pipeline.lua
-- Five-stage compilation pipeline:
--   collect → normalize → resolve → optimize → codegen
--
-- Each stage is a pure function: (ctx) → ctx.
-- Intermediate context can be dumped for debugging.

local M = {}

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

--- Factory: creates an independent state machine instance.
---@return table
local function new_state_machine()
  local sm = { state = STATES.IDLE, timestamps = {} }
  function sm.transition(next)
    local allowed = TRANSITIONS[sm.state]
    if allowed and allowed[next] then
      sm.state = next
      sm.timestamps[next] = os.clock()
      return true
    end
    -- illegal transition → error state
    vim.notify(string.format("[pipeline] illegal transition: %s → %s", sm.state, next), vim.log.levels.ERROR)
    sm.state = STATES.ERROR
    sm.timestamps[STATES.ERROR] = os.clock()
    return false
  end

  return sm
end
-- Holds the state machine from the most recent run() call (for M.state()).
local last_run_sm = new_state_machine()
-- ── Stage helpers ────────────────────────────────────────────────────────────

--- Stage 1 – collect
---@param lang_modules string[]
---@param sm table  state machine instance
---@return table  pipeline context
local function collect(lang_modules, sm)
  if not sm.transition(STATES.COLLECTING) then
    return {}
  end
  local registry = require("core.capability")
  local ir = { caps = {}, errors = {} }
  for _, mod in ipairs(lang_modules) do
    local ok, result = pcall(require, mod)
    if not ok then
      vim.notify("[pipeline.collect] failed to load " .. mod .. ": " .. tostring(result), vim.log.levels.WARN)
      ir.errors[#ir.errors + 1] = "failed to load " .. mod .. ": " .. tostring(result)
    elseif type(result) == "table" then
      local name = mod:match("([^.]+)$") or mod
      registry.add(name, result)
    else
      vim.notify("[pipeline.collect] " .. mod .. " did not return a table; skipping", vim.log.levels.WARN)
      ir.errors[#ir.errors + 1] = mod .. " did not return a table"
    end
  end
  ir.caps = registry.all()
  return ir
end

--- Stage 2 – normalize
--- Resolves FormatterNode.strategy → FormatterNode.fn so downstream stages
--- and adapters never need to touch the strategies registry.
---@param ctx table
---@param sm table  state machine instance
---@return table
local function normalize(ctx, sm)
  if not sm.transition(STATES.NORMALIZING) then
    return ctx
  end
  local strategies = require("toolchain.strategies")
  for _, cap in pairs(ctx.caps) do
    if cap.formatters then
      for _, fmts in pairs(cap.formatters) do
        if type(fmts) == "table" then
          for _, v in ipairs(fmts) do
            if type(v) == "table" and v.kind == "formatter" and v.strategy and not v.fn then
              local strat = strategies.get(v.strategy)
              if strat then
                v.fn = strat.resolve
              else
                vim.notify("[pipeline.normalize] unknown formatter strategy: " .. v.strategy, vim.log.levels.WARN)
                v.fn = function()
                  return {}
                end
              end
            end
          end
        end
      end
    end
  end
  return ctx
end

--- Stage 3 – resolve
---@param ctx table
---@param sm table  state machine instance
---@return table
local function resolve(ctx, sm)
  if not sm.transition(STATES.RESOLVING) then
    return ctx
  end
  local rules = require("toolchain.rules")
  local resolved = { lsp = {}, tools = {} }

  for _, cap in pairs(ctx.caps) do
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
          for _, tool in ipairs(list) do
            if type(tool) == "string" and tool:sub(1, 2) ~= "__" then
              resolved.tools[tool] = rules.use_mason(tool)
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

  ctx.resolved = resolved
  return ctx
end

--- Stage 4 – optimize
---@param ctx table
---@param sm table  state machine instance
---@return table
local function optimize(ctx, sm)
  if not sm.transition(STATES.OPTIMIZING) then
    return ctx
  end
  local util = require("core.util")

  local parsers_seen = {}
  for _, cap in pairs(ctx.caps) do
    if cap.treesitter then
      cap.treesitter = util.dedup(cap.treesitter)
      for _, p in ipairs(cap.treesitter) do
        parsers_seen[p] = true
      end
    end
  end
  local parsers_list = {}
  for p in pairs(parsers_seen) do
    parsers_list[#parsers_list + 1] = p
  end
  ctx.all_parsers = parsers_list

  local merged_lsp = {}
  for _, cap in pairs(ctx.caps) do
    if cap.lsp then
      for server, cfg in pairs(cap.lsp) do
        if merged_lsp[server] then
          merged_lsp[server] = vim.tbl_deep_extend("force", merged_lsp[server], cfg)
        else
          merged_lsp[server] = vim.deepcopy(cfg)
        end
      end
    end
  end
  ctx.merged_lsp = merged_lsp

  return ctx
end

--- Stage 5 – codegen
---@param ctx table
---@param sm table  state machine instance
---@return table[]  flat list of lazy.nvim plugin specs
local function codegen(ctx, sm)
  if not sm.transition(STATES.CODEGEN) then
    return {}
  end
  local adapters = {
    require("runtime.adapters.lsp"),
    require("runtime.adapters.mason"),
    require("runtime.adapters.treesitter"),
    require("runtime.adapters.conform"),
    require("runtime.adapters.lint"),
  }

  local specs = {}
  for _, adapter in ipairs(adapters) do
    local ok, result = pcall(adapter.build, ctx)
    if ok then
      for _, spec in ipairs(result) do
        specs[#specs + 1] = spec
      end
    else
      vim.notify("[pipeline.codegen] adapter failed: " .. tostring(result), vim.log.levels.WARN)
    end
  end
  return specs
end

-- ── Public API ───────────────────────────────────────────────────────────────

--- Run the full pipeline and return lazy.nvim plugin specs.
---@param lang_modules string[]
---@return table[]
function M.run(lang_modules)
  local sm = new_state_machine()
  last_run_sm = sm

  local timings = {}

  local function timed(name, fn, ...)
    local t0 = os.clock()
    local ok, result = pcall(fn, ...)
    timings[name] = os.clock() - t0
    return ok, result
  end

  local ok, ctx = timed("collect", collect, lang_modules, sm)
  if not ok or sm.state == STATES.ERROR then
    vim.notify("[pipeline] collect failed: " .. tostring(ctx), vim.log.levels.ERROR)
    sm.state = STATES.ERROR
    return {}
  end

  ok, ctx = timed("normalize", normalize, ctx, sm)
  if not ok or sm.state == STATES.ERROR then
    vim.notify("[pipeline] normalize failed: " .. tostring(ctx), vim.log.levels.ERROR)
    sm.state = STATES.ERROR
    return {}
  end

  ok, ctx = timed("resolve", resolve, ctx, sm)
  if not ok or sm.state == STATES.ERROR then
    vim.notify("[pipeline] resolve failed: " .. tostring(ctx), vim.log.levels.ERROR)
    sm.state = STATES.ERROR
    return {}
  end

  ok, ctx = timed("optimize", optimize, ctx, sm)
  if not ok or sm.state == STATES.ERROR then
    vim.notify("[pipeline] optimize failed: " .. tostring(ctx), vim.log.levels.ERROR)
    sm.state = STATES.ERROR
    return {}
  end

  local specs
  ok, specs = timed("codegen", codegen, ctx, sm)
  if not ok or sm.state == STATES.ERROR then
    vim.notify("[pipeline] codegen failed: " .. tostring(specs), vim.log.levels.ERROR)
    sm.state = STATES.ERROR
    return {}
  end

  sm.transition(STATES.DONE)

  -- Persist per-stage timings for :LtosInfo (Requirement 18.1)
  vim.g.ltos_last_build_timings = timings

  -- Summarise accumulated errors in a single WARN (Requirement 18.2)
  if ctx.errors and #ctx.errors > 0 then
    local seen = {}
    local unique = {}
    for _, msg in ipairs(ctx.errors) do
      if not seen[msg] then
        seen[msg] = true
        unique[#unique + 1] = msg
      end
    end
    vim.notify(
      "[pipeline] build completed with " .. #unique .. " error(s):\n" .. table.concat(unique, "\n"),
      vim.log.levels.WARN
    )
  end

  return specs
end

--- Dump intermediate context after each stage (debug capability).
--- Records per-stage elapsed time via os.clock().
---@param lang_modules string[]
---@param stop_after? "collect"|"normalize"|"resolve"|"optimize"
---@return table  the context at the requested stage, with _timings field
function M.debug_run(lang_modules, stop_after)
  local sm = new_state_machine()

  require("core.capability").reset()

  local stage_fns = {
    {
      "collect",
      function(_)
        return collect(lang_modules, sm)
      end,
    },
    {
      "normalize",
      function(c)
        return normalize(c, sm)
      end,
    },
    {
      "resolve",
      function(c)
        return resolve(c, sm)
      end,
    },
    {
      "optimize",
      function(c)
        return optimize(c, sm)
      end,
    },
  }

  local ctx = {}
  local timings = {}

  for _, entry in ipairs(stage_fns) do
    local name, fn = entry[1], entry[2]
    local t0 = os.clock()
    local ok, result = pcall(fn, ctx)
    local elapsed = os.clock() - t0
    timings[name] = elapsed

    if not ok then
      vim.notify("[pipeline.debug_run] " .. name .. " failed: " .. tostring(result), vim.log.levels.ERROR)
      ctx._timings = timings
      return ctx
    end

    ctx = result
    if name == stop_after then
      break
    end
  end
  ctx._timings = timings
  return ctx
end

--- Return the current state machine state (for :LtosInfo).
---@return string
function M.state()
  return last_run_sm.state
end
return M
