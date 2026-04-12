-- lua/core/kernel/util.lua
-- Layer 0 kernel: stateless utility functions.
-- No vim API side-effects; safe to call from any layer.

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

--- Split a module path "foo.bar.baz" and return the last segment "baz".
---@param mod_path string
---@return string
function M.basename(mod_path)
  return mod_path:match("([^.]+)$") or mod_path
end

return M
