-- lua/core/kernel/env.lua
-- Layer 0 kernel: runtime environment FACTS only.
-- REFACTOR: removed prefer_system() — decision logic moved to toolchain/rules.lua
-- All results are memoised at module-load time.

local M = {}

M.is_nix = vim.fn.executable("nix") == 1
M.is_ssh = vim.env.SSH_CONNECTION ~= nil
M.is_vscode = vim.g.vscode ~= nil
M.is_gui = vim.fn.has("gui_running") == 1

--- Returns true if `cmd` is available in $PATH.
---@param cmd string
---@return boolean
function M.has(cmd)
  return vim.fn.executable(cmd) == 1
end

--- Returns true if nvim version >= 0.12
function M.is_nvim012()
  local v = vim.version()
  return v and v.major == 0 and v.minor >= 12
end

return M
