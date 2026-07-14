-- lua/core/compiler/cache/store.lua
-- Layer 1 compiler: JSON persistence via injectable ports.
-- Responsibilities: read, write, remove, ensure_dir.

local ports = require("core.compiler.ports")

local M = {}

local function cache_dir() return ports.cache_dir() end

function M.tier_path(tier) return cache_dir() .. "/" .. tier .. "_cache.json" end

---@return table<string, string>
function M.tier_files()
  return {
    ast = M.tier_path("ast"),
    spec = M.tier_path("spec"),
  }
end

-- Backward-compat alias
M.TIER_FILES = setmetatable({}, {
  __index = function(_, tier) return M.tier_path(tier) end,
})

local function ensure_dir() ports.ensure_cache_dir(cache_dir()) end

---@param path string
---@return table|nil
---@return string|nil
function M.read(path)
  local raw = ports.read_file(path)
  if not raw then
    return nil, "file not found: " .. path
  end
  if raw == "" then
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
-- Old code wrote directly to path — if nvim crashed mid-write, the cache
-- file was truncated/corrupted, causing JSON decode failures on next load.
-- New flow: write to path..".tmp", close, then os.rename (atomic on POSIX).
-- On crash, only the .tmp file is orphaned; original cache stays intact.
function M.write(path, data)
  ensure_dir()
  local ok, encoded = pcall(ports.json_encode, data)
  if not ok then
    return false, "JSON encode error: " .. tostring(encoded)
  end
  local tmp_path = path .. ".tmp"
  local f = io.open(tmp_path, "w")
  if not f then
    return false, "cannot open for write: " .. tmp_path
  end
  local write_ok, write_err = f:write(encoded)
  f:close()
  if not write_ok then
    -- Clean up orphaned tmp file
    os.remove(tmp_path)
    return false, "write failed: " .. tostring(write_err)
  end
  -- os.rename is atomic on POSIX (rename(2)); on Windows it may fail if
  -- destination exists, but we already overwrote via "w" above so tmp is fresh.
  local rename_ok, rename_err = os.rename(tmp_path, path)
  if not rename_ok then
    os.remove(tmp_path)
    return false, "rename failed: " .. tostring(rename_err)
  end
  return true, nil
end

---@param path string
function M.remove(path) os.remove(path) end

return M

