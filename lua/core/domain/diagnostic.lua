-- lua/core/domain/diagnostic.lua
-- Layer 2 domain: Diagnostic value type (pure, no vim API).
--
-- Extracted from core/compiler/ir.lua to resolve layer boundary violation:
-- modules/capability/* (Layer 2) was requiring core.compiler.ir (Layer 1).
-- Now both compiler and domain layers can use this shared Diagnostic type.

local M = {}
local util = require("core.kernel.util")

---@class Diagnostic
---@field code     string   machine-readable error code  e.g. "E001"
---@field stage    string   pipeline stage or context
---@field node     string   lang module or AST node identifier
---@field message  string
---@field severity "error"|"warn"|"info"

--- Deterministic diagnostic code (pure, idempotent across runs).
---@param stage    string
---@param node     string
---@param message  string
---@param severity string
---@return string
local function diag_code(stage, node, message, severity)
  local prefix = (severity == "error") and "E" or (severity == "warn") and "W" or "I"
  local h = util.hash(("%s:%s:%s"):format(stage, node, message))
  return prefix .. string.format("%04x", h % 0x10000)
end

--- Creates a new Diagnostic.
---@param stage    string           Pipeline stage or context identifier.
---@param node     string           Module or node identifier.
---@param message  string           Human-readable message.
---@param severity? "error"|"warn"|"info"  Defaults to "error".
---@return Diagnostic
function M.new(stage, node, message, severity)
  severity = severity or "error"
  return {
    code = diag_code(stage, node, message, severity),
    stage = stage,
    node = node,
    message = message,
    severity = severity,
  }
end

--- Backward-compat alias for new().
M.diag = M.new

--- Format a diagnostic as a human-readable string.
---@param d Diagnostic
---@return string
function M.format(d)
  return ("[%s][%s] %s: %s"):format(d.severity or "error", d.stage or "?", d.node or "?", d.message or "?")
end

return M
