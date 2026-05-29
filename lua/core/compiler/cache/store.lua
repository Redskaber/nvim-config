-- lua/core/compiler/cache/store.lua
-- Layer 1 compiler: JSON persistence via injectable ports.
-- Responsibilities: read, write, remove, ensure_dir.

local ports = require("core.compiler.ports")

local M = {}

local function cache_dir()
  return ports.cache_dir()
end

function M.tier_path(tier)
  return cache_dir() .. "/" .. tier .. "_cache.json"
end

---@return table<string, string>
function M.tier_files()
  return {
    ast = M.tier_path("ast"),
    spec = M.tier_path("spec"),
  }
end

-- Backward-compat alias
M.TIER_FILES = setmetatable({}, {
  __index = function(_, tier)
    return M.tier_path(tier)
  end,
})

local function ensure_dir()
  ports.ensure_cache_dir(cache_dir())
end

---@param path string
---@return table|nil
---@return string|nil
function M.read(path)
  local f = io.open(path, "r")
  if not f then
    return nil, "file not found: " .. path
  end
  local raw = f:read("*a")
  f:close()
  if not raw or raw == "" then
    return nil, "empty file"
  end
  local ok, data = pcall(ports.json_decode, raw)
  if not ok then
    return nil, "JSON decode error: " .. tostring(data)
  end
  return data, nil
end

---@param path string
---@param data table
---@return boolean
---@return string|nil
function M.write(path, data)
  ensure_dir()
  local ok, encoded = pcall(ports.json_encode, data)
  if not ok then
    return false, "JSON encode error: " .. tostring(encoded)
  end
  local f = io.open(path, "w")
  if not f then
    return false, "cannot open for write: " .. path
  end
  f:write(encoded)
  f:close()
  return true, nil
end

---@param path string
function M.remove(path)
  os.remove(path)
end

return M
