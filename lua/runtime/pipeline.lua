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

local state_machine = {
  state = STATES.IDLE,
  timestamps = {},
}

function state_machine.transition(next)
  local allowed = TRANSITIONS[state_machine.state]
  if allowed and allowed[next] then
    state_machine.state = next
    state_machine.timestamps[next] = os.clock()
    return true
  end
  -- illegal transition → error state
  vim.notify(string.format("[pipeline] illegal transition: %s → %s", state_machine.state, next), vim.log.levels.ERROR)
  state_machine.state = STATES.ERROR
  state_machine.timestamps[STATES.ERROR] = os.clock()
  return false
end

local function reset_state_machine()
  state_machine.state = STATES.IDLE
  state_machine.timestamps = {}
end
-- ── Stage helpers ────────────────────────────────────────────────────────────

--- Stage 1 – collect
---@param lang_modules string[]
---@return table  pipeline context
local function collect(lang_modules)
  if not state_machine.transition(STATES.COLLECTING) then
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
---@param ctx table
---@return table
local function normalize(ctx)
  if not state_machine.transition(STATES.NORMALIZING) then
    return ctx
  end
  -- Future: walk ctx.caps and apply naming conventions
  return ctx
end

--- Stage 3 – resolve
---@param ctx table
---@return table
local function resolve(ctx)
  if not state_machine.transition(STATES.RESOLVING) then
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
---@return table
local function optimize(ctx)
  if not state_machine.transition(STATES.OPTIMIZING) then
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
  ctx.all_parsers_seen = parsers_seen

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
---@return table[]  flat list of lazy.nvim plugin specs
local function codegen(ctx)
  if not state_machine.transition(STATES.CODEGEN) then
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
  -- Reject re-entrant calls while pipeline is running
  if
    state_machine.state ~= STATES.IDLE
    and state_machine.state ~= STATES.DONE
    and state_machine.state ~= STATES.ERROR
  then
    vim.notify("[pipeline] run() called while pipeline is in state: " .. state_machine.state, vim.log.levels.WARN)
    return {}
  end

  reset_state_machine()

  local ok, ctx = pcall(collect, lang_modules)
  if not ok or state_machine.state == STATES.ERROR then
    vim.notify("[pipeline] collect failed: " .. tostring(ctx), vim.log.levels.ERROR)
    state_machine.state = STATES.ERROR
    return {}
  end

  ok, ctx = pcall(normalize, ctx)
  if not ok or state_machine.state == STATES.ERROR then
    vim.notify("[pipeline] normalize failed: " .. tostring(ctx), vim.log.levels.ERROR)
    state_machine.state = STATES.ERROR
    return {}
  end

  ok, ctx = pcall(resolve, ctx)
  if not ok or state_machine.state == STATES.ERROR then
    vim.notify("[pipeline] resolve failed: " .. tostring(ctx), vim.log.levels.ERROR)
    state_machine.state = STATES.ERROR
    return {}
  end

  ok, ctx = pcall(optimize, ctx)
  if not ok or state_machine.state == STATES.ERROR then
    vim.notify("[pipeline] optimize failed: " .. tostring(ctx), vim.log.levels.ERROR)
    state_machine.state = STATES.ERROR
    return {}
  end

  local specs
  ok, specs = pcall(codegen, ctx)
  if not ok or state_machine.state == STATES.ERROR then
    vim.notify("[pipeline] codegen failed: " .. tostring(specs), vim.log.levels.ERROR)
    state_machine.state = STATES.ERROR
    return {}
  end

  state_machine.transition(STATES.DONE)
  return specs
end

--- Dump intermediate context after each stage (debug capability).
--- Records per-stage elapsed time via os.clock().
---@param lang_modules string[]
---@param stop_after? "collect"|"normalize"|"resolve"|"optimize"
---@return table  the context at the requested stage, with _timings field
function M.debug_run(lang_modules, stop_after)
  reset_state_machine()

  local stage_fns = {
    {
      "collect",
      function(_)
        return collect(lang_modules)
      end,
    },
    { "normalize", normalize },
    { "resolve", resolve },
    { "optimize", optimize },
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
  return state_machine.state
end
return M
