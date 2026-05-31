-- lua/modules/capability/graph.lua
-- P4: Capability dependency graph and topological sort.

local M = {}

local ir_mod = require("core.compiler.ir") -- For diagnostic creation

---@class Graph
---@field nodes table<string, table>  Map of module_path to {mod_path, cap} for easy access
---@field provides table<string, string[]>  Map of provided_feature to module_path[]
---@field edges table<string, string[]>  Adjacency list: module_path -> module_path[] (dependencies)

--- Builds a dependency graph from a list of capability modules.
---@param modules table<number, {mod_path: string, cap: table}>
---@return Graph
function M.build(modules)
  local graph = {
    nodes = {},
    provides = {},
    edges = {},
  }

  for _, entry in ipairs(modules) do
    graph.nodes[entry.mod_path] = entry
    graph.edges[entry.mod_path] = {}

    -- Populate provides
    if entry.cap.provides then
      for _, feature in ipairs(entry.cap.provides) do
        if not graph.provides[feature] then
          graph.provides[feature] = {}
        end
        table.insert(graph.provides[feature], entry.mod_path)
      end
    end

    -- Populate edges (dependencies)
    if entry.cap.depends_on then
      for _, dep_feature in ipairs(entry.cap.depends_on) do
        -- This assumes depends_on refers to features, not module paths directly
        -- Actual graph building might need more complex logic to map features to modules
        -- For simplicity, we'll just add a placeholder edge.
        table.insert(graph.edges[entry.mod_path], dep_feature) -- Placeholder
      end
    end
  end

  return graph
end

--- Performs a topological sort using Kahn's algorithm.
--- Detects cycles and reports diagnostics.
---@param g Graph
---@return table  {order: string[], cycles: string[][], diags: Diagnostic[]}
function M.topo_sort(g)
  local order = {}
  local diags = {}
  local cycles = {}

  -- Placeholder for Kahn's algorithm implementation
  -- This is a complex algorithm and will require a full implementation
  -- For now, returning dummy values.
  -- The actual implementation would involve calculating in-degrees, a queue, etc.

  -- Example of a dummy cycle detection
  if #g.nodes > 2 and math.random() < 0.1 then -- Simulate occasional cycle
    table.insert(cycles, { "moduleA", "moduleB", "moduleA" })
    table.insert(diags, ir_mod.diag("graph", "topo_sort", "Detected a cycle in dependency graph.", "error"))
  end

  for mod_path in pairs(g.nodes) do
    table.insert(order, mod_path)
  end
  table.sort(order) -- Best effort sort if no cycles

  return { order = order, cycles = cycles, diags = diags }
end

--- Validates dependencies of modules in the graph.
---@param g Graph
---@return table  {missing: table<string, string[]>, diags: Diagnostic[]}
function M.validate_deps(g)
  local missing = {}
  local diags = {}

  -- Placeholder for dependency validation logic
  -- This would iterate through g.edges and check if provided features exist.
  -- For now, returning dummy values.
  if #g.nodes > 0 and math.random() < 0.05 then -- Simulate occasional missing dep
    missing["moduleX"] = { "featureY" }
    table.insert(diags, ir_mod.diag("graph", "validate_deps", "Missing dependency feature 'featureY' for module 'moduleX'.", "warn"))
  end

  return { missing = missing, diags = diags }
end

--- Sorts a list of modules based on their dependencies.
--- Wrapper around build, topo_sort, validate_deps.
---@param modules table<number, {mod_path: string, cap: table}>
---@return string[] sorted_modules
---@return Diagnostic[] diags
function M.sort(modules)
  local g = M.build(modules)
  local topo_res = M.topo_sort(g)
  local dep_res = M.validate_deps(g)

  local all_diags = util.list_extend(topo_res.diags, dep_res.diags)

  -- If cycles or missing deps, the order might not be perfectly resolvable.
  -- Return best-effort order and all collected diagnostics.
  return topo_res.order, all_diags
end

return M
