-- lua/core/compiler/cache/store.lua
-- Layer 1 compiler: JSON persistence (the ONLY IO layer in the cache subsystem).
--
-- REFACTOR (TODO-2.3): extracted from cache.lua.
-- Responsibilities: read, write, remove, ensure_dir.
-- All functions return (value, err_string|nil) — no vim.notify here.

local M = {}

local CACHE_DIR = vim.fn.stdpath("cache") .. "/ltos"

M.TIER_FILES = {
  ast = CACHE_DIR .. "/ast_cache.json",
  spec = CACHE_DIR .. "/spec_cache.json",
}

local function ensure_dir()
  if vim.fn.isdirectory(CACHE_DIR) == 0 then
    vim.fn.mkdir(CACHE_DIR, "p")
  end
end

--- Read and JSON-decode a file.
---@param path string
---@return table|nil  data
---@return string|nil err
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
  local ok, data = pcall(vim.json.decode, raw)
  if not ok then
    return nil, "JSON decode error: " .. tostring(data)
  end
  return data, nil
end

--- JSON-encode and write data to a file.
---@param path string
---@param data table
---@return boolean  success
---@return string|nil err
function M.write(path, data)
  ensure_dir()
  local ok, encoded = pcall(vim.json.encode, data)
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

--- Remove a file (no-op if missing).
---@param path string
function M.remove(path)
  os.remove(path)
end

return M
