-- lua/toolchain/strategy/conflict.lua
-- P4: Strategy conflict detection and prioritization.

local util = require("core.kernel.util")

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
    local ok, result = pcall(strategy.applies, strategy, tool)
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
      local diag_msg = ("Multiple strategies for tool '%s' have the same highest priority: %s"):format(
        tool,
        table.concat(
          vim.tbl_map(function(s)
            return s.name
          end, highest_priority_strategies),
          ", "
        )
      )
      return {
        tool = tool,
        winner = nil,
        resolution = M.RESOLUTION.AMBIGUOUS,
        diag = require("core.compiler.ir").diag("strategy", tool, diag_msg, "warn"),
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
      for _, strategy in ipairs(sorted_strategies) do
        local ok, res = pcall(strategy.resolve, strategy, ctx)
        if ok then
          table.insert(results, res)
        else
          -- Log error, but continue with other strategies
          require("core.compiler.ir").diag(
            "strategy",
            strategy.name,
            ("Strategy '%s' failed to resolve for tool '%s': %s"):format(strategy.name, tool, tostring(res)),
            "warn"
          )
        end
      end
      -- Merge or combine results from individual strategies. This is a simplified merge.
      -- A real implementation might need a more sophisticated merge logic.
      return util.merge_recursive({}, unpack(results))
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
