-- ~/.config/nvim/lua/core/util.lua
-- Lightweight shared utilities. Keep this dependency-free.

local M = {}

--- Merge two option tables (right wins on key conflict).
---@param base table
---@param override table
---@return table
function M.merge(base, override)
  return vim.tbl_deep_extend("force", base, override)
end

--- Return a function that lazily requires `mod` and calls `mod[fn]`.
---@param mod string   module path
---@param fn  string   exported function name
---@return function
function M.lazy_require(mod, fn)
  return function(...)
    return require(mod)[fn](...)
  end
end

--- Map over a list, returning a new list.
---@generic T, U
---@param t T[]
---@param f fun(v: T): U
---@return U[]
function M.map(t, f)
  local out = {}
  for i, v in ipairs(t) do
    out[i] = f(v)
  end
  return out
end

--- Deduplicate a list (preserves first-seen order).
---@param list any[]
---@return any[]
function M.dedup(list)
  local seen, out = {}, {}
  for _, v in ipairs(list) do
    if not seen[v] then
      out[#out + 1] = v
      seen[v] = true
    end
  end
  return out
end

return M
