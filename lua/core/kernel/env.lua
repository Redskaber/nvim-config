-- lua/core/kernel/env.lua
-- Layer 0 kernel: runtime environment FACTS only.
-- REFACTOR: lazy facts via register_fact(); decision logic in toolchain/rules.lua

local M = {}

local _facts = {}

--- Register a named environment fact (lazy, memoised on first access).
---@param name string
---@param fn fun(): any
function M.register_fact(name, fn)
  assert(type(name) == "string" and name ~= "", "fact name must be non-empty string")
  assert(type(fn) == "function", "fact fn must be a function")
  _facts[name] = fn
end

local function get_fact(name)
  local fn = _facts[name]
  if not fn then
    return nil
  end
  local ok, val = pcall(fn)
  if not ok then
    return nil
  end
  return val
end

-- Built-in facts (evaluated lazily on first read)
M.register_fact("is_nix", function() return vim.fn.executable("nix") == 1 end)

M.register_fact("is_ssh", function() return vim.env.SSH_CONNECTION ~= nil end)

M.register_fact("is_vscode", function() return vim.g.vscode ~= nil end)

M.register_fact("is_gui", function() return vim.fn.has("gui_running") == 1 end)

setmetatable(M, {
  __index = function(t, k)
    local val = get_fact(k)
    if val ~= nil then
      rawset(t, k, val)
      return val
    end
    return nil
  end,
})

--- Returns true if `cmd` is available in $PATH.
---@param cmd string
---@return boolean
function M.has(cmd) return vim.fn.executable(cmd) == 1 end

--- Returns true if nvim version >= 0.12
function M.is_nvim012()
  local v = vim.version()
  return v and v.major == 0 and v.minor >= 12
end

return M

