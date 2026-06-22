-- lua/core/compiler/ports.lua
-- Layer 1 compiler: injectable IO / host ports (no vim API in this file).
-- Configured once from runtime/ports_bootstrap.lua before cache use.

local M = {}

local _ports = {
  cache_dir = function()
    return ".cache/ltos"
  end,
  json_encode = function(t)
    error("compiler ports: json_encode not configured")
  end,
  json_decode = function(_s)
    error("compiler ports: json_decode not configured")
  end,
  resolve_runtime_file = function(_rel)
    return nil
  end,
  debug_cache = function()
    return false
  end,
  notify = function(_level, _msg)
    -- no-op until runtime configures
  end,
  ensure_cache_dir = function(dir)
    os.execute('mkdir -p "' .. dir:gsub('"', '\\"') .. '" 2>/dev/null')
  end,
}

---@class CompilerPorts
---@field cache_dir fun(): string
---@field json_encode fun(table): string
---@field json_decode fun(string): table
---@field resolve_runtime_file fun(string): string|nil
---@field debug_cache fun(): boolean
---@field notify fun(level: integer, msg: string)

--- Inject host implementations (call from Layer 4 bootstrap only).
---@param opts CompilerPorts
function M.configure(opts)
  for k, v in pairs(opts) do
    if type(v) == "function" then
      _ports[k] = v
    end
  end
end

function M.cache_dir()
  return _ports.cache_dir()
end

function M.json_encode(t)
  return _ports.json_encode(t)
end

function M.json_decode(s)
  return _ports.json_decode(s)
end

function M.resolve_runtime_file(rel)
  return _ports.resolve_runtime_file(rel)
end

function M.debug_cache()
  return _ports.debug_cache()
end

function M.notify(level, msg)
  _ports.notify(level, msg)
end

function M.ensure_cache_dir(dir)
  _ports.ensure_cache_dir(dir)
end

return M