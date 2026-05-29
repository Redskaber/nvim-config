-- lua/runtime/adapters/registry.lua
-- AdapterRegistry: register codegen backends; codegen emits via registry.emit_all(ir).

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

-- Built-in adapters (register = extend, never modify codegen.lua)
M.register("runtime.adapters.lsp", { priority = 10 })
M.register("runtime.adapters.mason", { priority = 20 })
M.register("runtime.adapters.treesitter", { priority = 30 })
M.register("runtime.adapters.conform", { priority = 40 })
M.register("runtime.adapters.lint", { priority = 50 })

return M
