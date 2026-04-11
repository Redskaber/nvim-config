-- ~/.config/nvim/lua/runtime/pipeline.lua
-- Five-stage compilation pipeline:
--   collect → normalize → resolve → optimize → codegen
--
-- Each stage is a pure function: (ctx, sm) → ctx.
-- Intermediate context can be dumped for debugging.
--
-- normalize() no longer mutates the shared registry tables in-place.
-- FormatterNode.fn is injected into deep-copied cap entries so debug_run()
-- inspections and subsequent capability.reset() produce clean output.

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
    vim.notify(string.format("[pipeline] illegal transition: %s → %s", sm.state, next), vim.log.levels.ERROR)
    sm.state = STATES.ERROR
    sm.timestamps[STATES.ERROR] = os.clock()
    return false
  end
  return sm
end

-- State machine from the most recent run() call (for M.state()).
local last_run_sm = new_state_machine()

-- ── Stage helpers ────────────────────────────────────────────────────────────

--- Stage 1 – collect
---@param lang_modules string[]
---@param sm table
---@return table
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
--- Resolves FormatterNode.strategy → FormatterNode.fn.
---
--- operates on deep copies of each formatter list so the shared
--- registry tables in core/capability are never mutated.  This keeps debug_run()
--- inspections and subsequent registry.reset() free of injected function refs.
---
---@param ctx table
---@param sm table
---@return table
local function normalize(ctx, sm)
  if not sm.transition(STATES.NORMALIZING) then
    return ctx
  end
  local strategies = require("toolchain.strategies")

  -- Work on a shallow-copy of caps; each formatter list is deep-copied on demand.
  local patched_caps = {}
  for lang, cap in pairs(ctx.caps) do
    if cap.formatters then
      local patched_formatters = {}
      local needs_patch = false
      for ft, fmts in pairs(cap.formatters) do
        if type(fmts) == "table" then
          local patched_list = nil
          for i, v in ipairs(fmts) do
            if type(v) == "table" and v.kind == "formatter" and v.strategy and not v.fn then
              -- Lazy-init the copied list only when a node actually needs patching
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
            end
          end
          if patched_list then
            needs_patch = true
            patched_formatters[ft] = patched_list
          else
            patched_formatters[ft] = fmts -- unchanged — share original ref
          end
        else
          patched_formatters[ft] = fmts
        end
      end
      if needs_patch then
        -- Shallow-copy the cap, replacing only formatters
        local patched_cap = {}
        for k, v in pairs(cap) do
          patched_cap[k] = v
        end
        patched_cap.formatters = patched_formatters
        patched_caps[lang] = patched_cap
      end
    end
  end

  -- Merge patched caps into ctx (original registry untouched)
  if next(patched_caps) then
    local merged = {}
    for lang, cap in pairs(ctx.caps) do
      merged[lang] = patched_caps[lang] or cap
    end
    ctx.caps = merged
  end

  return ctx
end

--- Stage 3 – resolve
---@param ctx table
---@param sm table
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
---@param sm table
---@return table
local function optimize(ctx, sm)
  if not sm.transition(STATES.OPTIMIZING) then
    return ctx
  end
  local util = require("core.util")

  -- Collect and dedup treesitter parsers
  local all_parsers = {}
  for _, cap in pairs(ctx.caps) do
    if cap.treesitter then
      vim.list_extend(all_parsers, cap.treesitter)
    end
  end
  ctx.all_parsers = util.dedup(all_parsers)

  -- Merge LSP configs (later caps override earlier on conflict)
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
---@param sm table
---@return table[]
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

  -- Persist per-stage timings for :LtosInfo
  vim.g.ltos_last_build_timings = timings

  -- Summarise accumulated errors in a single WARN
  if ctx.errors and #ctx.errors > 0 then
    local seen, unique = {}, {}
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
---@param lang_modules string[]
---@param stop_after? "collect"|"normalize"|"resolve"|"optimize"
---@return table
function M.debug_run(lang_modules, stop_after)
  local sm = new_state_machine()

  -- FIX P0-2 (carried): reset registry before debug run to avoid accumulation
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
    timings[name] = os.clock() - t0

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

--- Return the state of the most recent run() call (for :LtosInfo).
---@return string
function M.state()
  return last_run_sm.state
end

return M
