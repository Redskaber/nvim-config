-- lua/modules/capability/graph.lua
-- P4: Capability dependency graph + topological sort (pure, deterministic).

local M = {}

local diagnostic = require("core.domain.diagnostic")
local util = require("core.kernel.util")

local function tbl_count(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n
end

---@class Graph
---@field nodes table<string, {mod_path: string, cap: table}>
---@field provides table<string, string[]>
---@field edges table<string, string[]>

---@param modules {mod_path: string, cap: table}[]
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

    if entry.cap.provides then
      for _, feature in ipairs(entry.cap.provides) do
        graph.provides[feature] = graph.provides[feature] or {}
        graph.provides[feature][#graph.provides[feature] + 1] = entry.mod_path
      end
    end
  end

  for _, entry in ipairs(modules) do
    local deps = entry.cap.depends or entry.cap.depends_on or {}
    for _, dep in ipairs(deps) do
      local targets = graph.provides[dep]
      if targets then
        for _, dep_mod in ipairs(targets) do
          if dep_mod ~= entry.mod_path then
            graph.edges[entry.mod_path][#graph.edges[entry.mod_path] + 1] = dep_mod
          end
        end
      elseif graph.nodes[dep] then
        graph.edges[entry.mod_path][#graph.edges[entry.mod_path] + 1] = dep
      end
    end
  end

  return graph
end

---@param g Graph
---@return {order: string[], cycles: string[][], diags: Diagnostic[]}
function M.topo_sort(g)
  local in_degree = {}
  local order = {}
  local diags = {}
  local cycles = {}

  for mod_path in pairs(g.nodes) do
    in_degree[mod_path] = 0
  end

  for mod_path, deps in pairs(g.edges) do
    for _, dep in ipairs(deps) do
      if g.nodes[dep] then
        in_degree[mod_path] = (in_degree[mod_path] or 0) + 1
      end
    end
  end

  local queue = {}
  for mod_path, deg in pairs(in_degree) do
    if deg == 0 then
      queue[#queue + 1] = mod_path
    end
  end
  table.sort(queue)

  local qi = 1
  while qi <= #queue do
    local node = queue[qi]
    qi = qi + 1
    order[#order + 1] = node

    for mod_path, deps in pairs(g.edges) do
      for _, dep in ipairs(deps) do
        if dep == node and g.nodes[mod_path] then
          in_degree[mod_path] = in_degree[mod_path] - 1
          if in_degree[mod_path] == 0 then
            queue[#queue + 1] = mod_path
          end
        end
      end
    end
  end

  if #order < tbl_count(g.nodes) then
    local cycle_members = {}
    for mod_path, deg in pairs(in_degree) do
      if deg > 0 then
        cycle_members[#cycle_members + 1] = mod_path
      end
    end
    table.sort(cycle_members)
    if #cycle_members > 0 then
      cycles[#cycles + 1] = cycle_members
      diags[#diags + 1] = diagnostic.new(
        "graph",
        "topo_sort",
        ("Detected dependency cycle involving: %s"):format(table.concat(cycle_members, ", ")),
        "error"
      )
    end
    for mod_path in pairs(g.nodes) do
      local found = false
      for _, o in ipairs(order) do
        if o == mod_path then
          found = true
          break
        end
      end
      if not found then
        order[#order + 1] = mod_path
      end
    end
    table.sort(order)
  end

  return { order = order, cycles = cycles, diags = diags }
end

---@param g Graph
---@return {missing: table<string, string[]>, diags: Diagnostic[]}
function M.validate_deps(g)
  local missing = {}
  local diags = {}

  for mod_path, entry in pairs(g.nodes) do
    local deps = entry.cap.depends or entry.cap.depends_on or {}
    for _, dep in ipairs(deps) do
      local satisfied = g.provides[dep] ~= nil or g.nodes[dep] ~= nil
      if not satisfied then
        missing[mod_path] = missing[mod_path] or {}
        missing[mod_path][#missing[mod_path] + 1] = dep
        diags[#diags + 1] = diagnostic.new(
          "graph",
          mod_path,
          ("Missing dependency '%s' for module '%s'"):format(dep, mod_path),
          "warn"
        )
      end
    end
  end

  return { missing = missing, diags = diags }
end

---@param modules {mod_path: string, cap: table}[]
---@return string[]
---@return Diagnostic[]
function M.sort(modules)
  local g = M.build(modules)
  local topo_res = M.topo_sort(g)
  local dep_res = M.validate_deps(g)
  local all_diags = util.list_extend(util.deep_copy(topo_res.diags), dep_res.diags)
  return topo_res.order, all_diags
end

return M