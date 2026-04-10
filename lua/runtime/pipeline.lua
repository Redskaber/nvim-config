-- ~/.config/nvim/lua/runtime/pipeline.lua
-- Five-stage compilation pipeline:
--   collect → normalize → resolve → optimize → codegen
--
-- Each stage is a pure function: (ctx) → ctx.
-- Intermediate context can be dumped for debugging.

local M = {}

-- ── Stage helpers ────────────────────────────────────────────────────────────

--- Stage 1 – collect
-- Load every lang module (pure return, no side-effects).
-- Each module must `return <Capability table>` — nothing else.
---@param lang_modules string[]
---@return table  pipeline context
local function collect(lang_modules)
  local registry = require("core.capability")
  for _, mod in ipairs(lang_modules) do
    local ok, result = pcall(require, mod)
    if not ok then
      vim.notify("[pipeline.collect] failed to load " .. mod .. ": " .. tostring(result), vim.log.levels.WARN)
    elseif type(result) == "table" then
      -- derive lang key from module path: "modules.lang.rust" → "rust"
      local name = mod:match("([^.]+)$") or mod
      registry.add(name, result)
    else
      vim.notify("[pipeline.collect] " .. mod .. " did not return a table; skipping", vim.log.levels.WARN)
    end
  end
  return { caps = registry.all() }
end

--- Stage 2 – normalize
-- Standardise tool names (lsp server, formatter, linter) to canonical forms.
-- Currently a no-op placeholder; extend here when P2-1 naming rules land.
---@param ctx table
---@return table
local function normalize(ctx)
  -- Future: walk ctx.caps and apply naming conventions
  return ctx
end

--- Stage 3 – resolve
-- Annotate each tool with its resolved source ("system" | "mason") using
-- toolchain rules. Stores ctx.resolved = { lsp={}, tools={} }.
---@param ctx table
---@return table
local function resolve(ctx)
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
            if tool:sub(1, 2) ~= "__" then -- skip sentinels
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
-- Deduplicate parsers, tools, merge identical server configs.
---@param ctx table
---@return table
local function optimize(ctx)
  local util = require("core.util")

  -- Deduplicate treesitter parsers across all capabilities
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

  -- Merge duplicate LSP server entries across lang modules (idempotent)
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
-- Dispatch to each adapter (pure functions: IR → lazy spec).
---@param ctx table
---@return table[]  flat list of lazy.nvim plugin specs
local function codegen(ctx)
  local adapters = {
    require("runtime.adapters.lsp"),
    require("runtime.adapters.mason"),
    require("runtime.adapters.treesitter"),
    require("runtime.adapters.conform"),
    require("runtime.adapters.lint"),
  }

  local specs = {}
  for _, adapter in ipairs(adapters) do
    for _, spec in ipairs(adapter.build(ctx)) do
      specs[#specs + 1] = spec
    end
  end
  return specs
end

-- ── Public API ───────────────────────────────────────────────────────────────

--- Run the full pipeline and return lazy.nvim plugin specs.
---@param lang_modules string[]
---@return table[]
function M.run(lang_modules)
  local ctx = collect(lang_modules)
  ctx = normalize(ctx)
  ctx = resolve(ctx)
  ctx = optimize(ctx)
  return codegen(ctx)
end

--- Dump intermediate context after each stage (P2-2 debug capability).
---@param lang_modules string[]
---@param stop_after? "collect"|"normalize"|"resolve"|"optimize"
---@return table  the context at the requested stage
function M.debug_run(lang_modules, stop_after)
  local stages = {
    {
      "collect",
      function(c)
        return collect(lang_modules)
      end,
    },
    { "normalize", normalize },
    { "resolve", resolve },
    { "optimize", optimize },
  }
  local ctx = {}
  for _, stage in ipairs(stages) do
    local name, fn = stage[1], stage[2]
    ctx = fn(ctx)
    if name == stop_after then
      break
    end
  end
  return ctx
end

return M
