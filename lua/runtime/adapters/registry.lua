-- lua/runtime/adapters/registry.lua
-- AdapterRegistry: register codegen backends; codegen emits via registry.emit_all(ir).
-- P2: Uses externalized defaults from runtime.defaults.adapters

local M = {}

local _adapters = {}

---@param path string  module path e.g. "runtime.adapters.lsp"
---@param opts? { priority?: number }
function M.register(path, opts)
  assert(type(path) == "string" and path ~= "", "adapter path must be non-empty string")
  opts = opts or {}
  _adapters[#_adapters + 1] = { path = path, priority = opts.priority or #_adapters + 1 }
  table.sort(_adapters, function(a, b)
    return a.priority < b.priority
  end)
end

---@return string[]
function M.list()
  local out = {}
  for _, e in ipairs(_adapters) do
    out[#out + 1] = e.path
  end
  return out
end

--- Drive all registered adapters through the emitter.
---@param ir table
---@return table[]
function M.emit_all(ir)
  local emitter = require("runtime.emitter")
  return emitter.emit(ir, M.list())
end

-- Load and register default adapters
local defaults = require("runtime.defaults.adapters")
for _, entry in ipairs(defaults) do
  M.register(entry.path, { priority = entry.priority })
end

return M
