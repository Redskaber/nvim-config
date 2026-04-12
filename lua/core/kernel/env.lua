-- lua/core/kernel/env.lua
-- Layer 0 kernel: runtime environment detection.
-- All results are memoised at module-load time — call freely.

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

--- Returns true when a binary should be managed externally (Nix host + binary present).
---@param cmd string
---@return boolean
function M.prefer_system(cmd)
  return M.is_nix and M.has(cmd)
end

return M
