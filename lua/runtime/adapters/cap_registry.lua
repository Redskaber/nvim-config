-- lua/runtime/adapters/cap_registry.lua
-- CapAdapterRegistry: cap_type → adapter module (Layer 4, read-only IR consumers).
-- P6-C2: Default registration moved to explicit setup() — no require-time side effects.

local M = {}

local _adapters = {}
local _setup_done = false

---@param cap_type string
---@param adapter_path string
function M.register(cap_type, adapter_path)
  assert(type(cap_type) == "string" and cap_type ~= "", "cap_type must be non-empty string")
  assert(
    type(adapter_path) == "string" and adapter_path ~= "",
    "adapter_path must be non-empty string"
  )
  _adapters[cap_type] = adapter_path
end

---@param cap_type string
---@return table|nil
function M.get(cap_type)
  local path = _adapters[cap_type]
  if not path then
    return nil
  end
  return require(path)
end

---@return string[]
function M.list()
  local out = {}
  for cap_type in pairs(_adapters) do
    out[#out + 1] = cap_type
  end
  table.sort(out)
  return out
end

--- Reset registry (testing only).
function M._reset()
  _adapters = {}
  _setup_done = false
end

--- Bootstrap default cap adapters from defaults table.
--- Must be called explicitly by runtime/init.lua — never executes on require.
function M.setup()
  if _setup_done then
    return
  end
  _setup_done = true
  local defaults = require("runtime.defaults.cap_adapters")
  for _, entry in ipairs(defaults) do
    M.register(entry.cap_type, entry.path)
  end
end

return M
