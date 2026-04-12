-- lua/core/kernel/util.lua
-- Layer 0 kernel: stateless utility functions.
-- No vim API side-effects; safe to call from any layer.
-- REFACTOR: added deep_merge, deep_equal, freeze

local M = {}

--- Deduplicate a list, preserving order of first occurrence.
---@param list any[]
---@return any[]
function M.dedup(list)
  local seen = {}
  local out = {}
  for _, v in ipairs(list) do
    if not seen[v] then
      seen[v] = true
      out[#out + 1] = v
    end
  end
  return out
end

--- Shallow-merge two tables (right wins on conflict).
---@param a table
---@param b table
---@return table
function M.merge(a, b)
  local out = {}
  for k, v in pairs(a) do
    out[k] = v
  end
  for k, v in pairs(b) do
    out[k] = v
  end
  return out
end

--- Deep-merge two tables recursively (right wins on scalar conflict).
--- Tables are merged recursively; non-table values from b override a.
---@param a table
---@param b table
---@return table
function M.deep_merge(a, b)
  local out = {}
  for k, v in pairs(a) do
    out[k] = (type(v) == "table") and M.deep_merge(v, {}) or v
  end
  for k, v in pairs(b) do
    if type(v) == "table" and type(out[k]) == "table" then
      out[k] = M.deep_merge(out[k], v)
    else
      out[k] = v
    end
  end
  return out
end

--- Structural equality check (no vim API dependency).
---@param a any
---@param b any
---@return boolean
function M.deep_equal(a, b)
  if type(a) ~= type(b) then
    return false
  end
  if type(a) ~= "table" then
    return a == b
  end
  for k, v in pairs(a) do
    if not M.deep_equal(v, b[k]) then
      return false
    end
  end
  for k in pairs(b) do
    if a[k] == nil then
      return false
    end
  end
  return true
end

--- Freeze a table in debug mode: raises on any write attempt.
--- No-op in production (returns table as-is).
---@param t table
---@param label? string
---@return table
function M.freeze(t, label)
  if not _G._ltos_debug_freeze then
    return t
  end
  return setmetatable({}, {
    __index = t,
    __newindex = function(_, k)
      error(
        ("[freeze] attempt to mutate frozen table%s at key %q"):format(
          label and (" (" .. label .. ")") or "",
          tostring(k)
        ),
        2
      )
    end,
    __pairs = function()
      return pairs(t)
    end,
    __len = function()
      return #t
    end,
  })
end

--- Split a module path "foo.bar.baz" and return the last segment "baz".
---@param mod_path string
---@return string
function M.basename(mod_path)
  return mod_path:match("([^.]+)$") or mod_path
end

-- ── Content hash (FNV-1a) ─────────────────────────────────────────────────────
-- v4.1: file content hash instead of mtime.
-- LuaJIT bit library used when available; pure-Lua fallback otherwise.

local _bit = (type(bit) == "table") and bit or nil ---@diagnostic disable-line: undefined-global

--- FNV-1a 32-bit hash (LuaJIT fast path).
---@param str string
---@return integer
local function fnv1a_jit(str)
  local b = bit ---@diagnostic disable-line: undefined-global
  local h = 2166136261
  for i = 1, #str do
    h = b.bxor(h, string.byte(str, i))
    h = b.band(h * 16777619, 0xFFFFFFFF)
  end
  return h
end

--- FNV-1a 32-bit hash (pure-Lua fallback).
---@param str string
---@return integer
local function fnv1a_lua(str)
  local h = 2166136261
  for i = 1, #str do
    h = (h * 16777619 + string.byte(str, i)) % (2 ^ 32)
  end
  return h
end

--- Hash a string using FNV-1a (auto-selects JIT or pure-Lua).
M.hash           = _bit and fnv1a_jit or fnv1a_lua

-- Expose individual implementations for testing
M.fnv1a          = fnv1a_jit
M.fnv1a_fallback = fnv1a_lua

--- Hash the contents of a file. Returns nil if file cannot be read.
---@param path string
---@return string|nil  8-char hex string
function M.file_content_hash(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  if not content then return nil end
  return string.format("%08x", M.hash(content))
end

return M
