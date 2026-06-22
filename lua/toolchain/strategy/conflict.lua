-- lua/toolchain/strategy/conflict.lua
-- P4: Strategy conflict detection and prioritization.
--
-- FIX-AUDIT-P0-5 (2026-06-23): Three fixes applied:
--   (a) compose() used merge_recursive on string[] results — that's table-key merge,
--       not list concat. Two strategies returning {"ruff_format"} and {"isort", "black"}
--       composed to {"isort", "black"} (last wins), losing the first strategy's output.
--       Switched to util.list_extend to accumulate all results.
--   (b) `require("core.compiler.ir").diag(...)` return values were silently discarded —
--       ir.diag is a pure constructor with no side effect. The comment "Log error, but
--       continue" was a no-op. Now collects diagnostics into a per-strategy `diags`
--       field on the composed strategy, and uses ports.notify for actual logging
--       via runtime emitter layer.
--   (c) Layer 3 → Layer 1 violation: `require("core.compiler.ir")` is a downward
--       upward dependency (strategy layer reaching into compiler layer). Migrated
--       to `require("core.domain.diagnostic")` (Layer 2), consistent with
--       AUDIT.md §3.2 fix applied to modules/capability/*.

local util = require("core.kernel.util")
local diagnostic = require("core.domain.diagnostic")

-- FIX-AUDIT-P0-5-CORRECTED (2026-06-23): Removed notify_warn() function that
-- pcall-required core.compiler.ports — that was a Layer 3 → Layer 1 violation.
-- Layer 3 (toolchain) must not do IO; it only returns Diagnostic values (pure data).
-- Layer 4 callers (runtime/emitter) own the decision to surface diagnostics.

local M = {}

---@enum M.RESOLUTION
M.RESOLUTION = {
  PRIORITY = "priority",
  AMBIGUOUS = "ambiguous",
  COMPOSE = "compose",
}

--- Finds all applicable strategies for a given tool.
--- Gracefully skips strategies that cause errors during applies() call.
---@param tool string
---@param strategies table[]
---@return table[]  Array of applicable strategies
function M.find_applicable(tool, strategies)
  local applicable = {}
  for _, strategy in ipairs(strategies) do
    -- FIX-AUDIT-STRATEGY (2026-06-23): do NOT pass strategy as self.
    -- Strategy.applies signature is `applies(tool)` (1 param, no self).
    -- Old code `pcall(strategy.applies, strategy, tool)` passed strategy
    -- as first arg, so `tool` param received the strategy table → always
    -- false. Fixed to `pcall(strategy.applies, tool)`.
    local ok, result = pcall(strategy.applies, tool)
    if ok and result then
      applicable[#applicable + 1] = strategy
    end
  end
  return applicable
end

--- Detects if there are conflicts among strategies based on priority.
---@param strategies table[]
---@return boolean  has_conflict
---@return table<number, table[]>  by_priority (priority -> list of strategies)
function M.detect(strategies)
  local by_priority = {}
  local has_conflict = false

  for _, strategy in ipairs(strategies) do
    local prio = strategy.priority or 0
    if not by_priority[prio] then
      by_priority[prio] = {}
    end
    by_priority[prio][#by_priority[prio] + 1] = strategy

    if #by_priority[prio] > 1 then
      has_conflict = true
    end
  end

  return has_conflict, by_priority
end

--- Resolves conflicts among strategies for a given tool.
---@param tool string
---@param strategies table[]
---@param compose? boolean If true, attempts to compose strategies in case of ambiguity.
---@return table ConflictReport  { tool: string, winner: table|nil, resolution: M.RESOLUTION, diag?: Diagnostic }
function M.resolve(tool, strategies, compose)
  if not strategies or #strategies == 0 then
    return { tool = tool, winner = nil, resolution = M.RESOLUTION.PRIORITY }
  end

  if #strategies == 1 then
    return { tool = tool, winner = strategies[1], resolution = M.RESOLUTION.PRIORITY }
  end

  local has_conflict, by_priority = M.detect(strategies)

  local sorted_priorities = {}
  for prio in pairs(by_priority) do
    table.insert(sorted_priorities, prio)
  end
  table.sort(sorted_priorities, function(a, b)
    return a > b
  end) -- Highest priority first

  local highest_priority_strategies = by_priority[sorted_priorities[1]]

  if #highest_priority_strategies == 1 then
    return { tool = tool, winner = highest_priority_strategies[1], resolution = M.RESOLUTION.PRIORITY }
  else
    -- Multiple strategies with the same highest priority
    if compose then
      local composed_strategy = M.compose(tool, highest_priority_strategies)
      return { tool = tool, winner = composed_strategy, resolution = M.RESOLUTION.COMPOSE }
    else
      -- FIX-AUDIT-P0-5(c): use domain.diagnostic (Layer 2) instead of core.compiler.ir
      -- FIX-AUDIT-P0-5(b): drop vim.tbl_map; use pure-Lua comprehension (INV-9 purity)
      local names = {}
      for _, s in ipairs(highest_priority_strategies) do
        names[#names + 1] = s.name
      end
      local diag_msg = ("Multiple strategies for tool '%s' have the same highest priority: %s"):format(
        tool,
        table.concat(names, ", ")
      )
      return {
        tool = tool,
        winner = nil,
        resolution = M.RESOLUTION.AMBIGUOUS,
        diag = diagnostic.new("strategy", tool, diag_msg, "warn"),
      }
    end
  end
end

--- Composes multiple strategies into a single one.
--- The resolve() method of the composed strategy will call individual strategies by priority.
---@param tool string
---@param strategies table[]
---@return table  Composed strategy
function M.compose(tool, strategies)
  local sorted_strategies = util.deep_copy(strategies)
  table.sort(sorted_strategies, function(a, b)
    return (a.priority or 0) > (b.priority or 0)
  end)

  return {
    name = ("%s:composed"):format(tool),
    priority = sorted_strategies[1].priority or 0, -- Use highest priority of component strategies
    applies = function(t)
      return t == tool
    end,
    resolve = function(ctx)
      local results = {}
      local composed_diags = {}
      for _, strategy in ipairs(sorted_strategies) do
        local ok, res = pcall(strategy.resolve, strategy, ctx)
        if ok then
          table.insert(results, res)
        else
          -- FIX-AUDIT-P0-5(b): actually log via ports.notify (was no-op before —
          -- ir.diag is a pure constructor, the discarded return value had no effect)
          -- FIX-AUDIT-P0-5(c): use domain.diagnostic, not core.compiler.ir (layer violation)
          local msg = ("Strategy '%s' failed to resolve for tool '%s': %s"):format(
            strategy.name, tool, tostring(res)
          )
          composed_diags[#composed_diags + 1] = diagnostic.new(
            "strategy", strategy.name, msg, "warn"
          )
        end
      end
      -- FIX-AUDIT-P0-5(a): CONCATENATE result lists with list_extend semantics.
      -- Old code used merge_recursive which does table-key merge: for two strategies
      -- returning {"ruff_format"} and {"isort","black"}, the composed result was
      -- {"isort","black"} (last wins by index 1), silently dropping the first strategy.
      local merged = {}
      for _, res_list in ipairs(results) do
        if type(res_list) == "table" then
          for _, item in ipairs(res_list) do
            merged[#merged + 1] = item
          end
        elseif res_list ~= nil then
          merged[#merged + 1] = res_list
        end
      end
      -- Attach collected diagnostics for observability (callers can read .diags)
      return setmetatable(merged, {
        __ltos_diags = composed_diags,
        __index = function(_, k)
          if k == "diags" then return composed_diags end
          return nil
        end,
      })
    end,
  }
end

--- Resolves conflicts for a list of tools.
---@param tools string[]
---@param all_strategies table[]
---@return table<string, table>  Map of tool name to ConflictReport
function M.resolve_all(tools, all_strategies)
  local reports = {}
  for _, tool in ipairs(tools) do
    local applicable_strategies = M.find_applicable(tool, all_strategies)
    reports[tool] = M.resolve(tool, applicable_strategies)
  end
  return reports
end

return M
