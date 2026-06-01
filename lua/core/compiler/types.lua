-- lua/core/compiler/types.lua
-- Layer 1 compiler: Abstract type interfaces for dependency inversion.
--
-- This module provides abstract interfaces for types that are implemented
-- in lower layers (domain). The concrete implementations are injected
-- via the `types.configure()` function from Layer 4 (runtime).
--
-- Design principles:
-- 1. Compiler layer (L1) depends on abstractions, not concrete implementations
-- 2. Domain layer (L2) implements the abstractions
-- 3. Runtime layer (L4) wires the concrete implementations via dependency injection
-- 4. This maintains strict layer boundaries while allowing necessary type sharing

local M = {}

-- ── Abstract Diagnostic Interface ─────────────────────────────────────────────

---@class AbstractDiagnostic
---@field code     string   machine-readable error code  e.g. "E001"
---@field stage    string   pipeline stage or context
---@field node     string   lang module or AST node identifier
---@field message  string
---@field severity "error"|"warn"|"info"

--- Abstract Diagnostic factory interface
---@class DiagnosticFactory
---@field new fun(stage: string, node: string, message: string, severity?: "error"|"warn"|"info"): AbstractDiagnostic
---@field diag fun(stage: string, node: string, message: string, severity?: "error"|"warn"|"info"): AbstractDiagnostic
---@field format fun(d: AbstractDiagnostic): string

-- ── Abstract Capability Types Interface ───────────────────────────────────────

---@class AbstractCapTypes
---@field IMAGE string
---@field MEDIA string
---@field AI string
---@field KEYBIND string
---@field EDITOR string
---@field ALL string[]
---@field is_known fun(t: string): boolean
---@field as_set fun(): table<string, boolean>

-- ── Default implementations (stubs that throw errors) ────────────────────────

local _diagnostic_factory = {
  new = function(stage, node, message, severity)
    error("compiler types: diagnostic factory not configured", 2)
  end,
  diag = function(stage, node, message, severity)
    error("compiler types: diagnostic factory not configured", 2)
  end,
  format = function(d)
    error("compiler types: diagnostic factory not configured", 2)
  end,
}

local _cap_types = {
  IMAGE = "image",
  MEDIA = "media",
  AI = "ai",
  KEYBIND = "keybind",
  EDITOR = "editor",
  ALL = { "image", "media", "ai", "keybind", "editor" },
  is_known = function(t)
    error("compiler types: cap_types not configured", 2)
  end,
  as_set = function()
    error("compiler types: cap_types not configured", 2)
  end,
}

-- ── Configuration API (called from Layer 4) ──────────────────────────────────

--- Configure concrete implementations from domain layer
---@param opts { diagnostic_factory: DiagnosticFactory, cap_types: AbstractCapTypes }
function M.configure(opts)
  if opts.diagnostic_factory then
    for k, v in pairs(opts.diagnostic_factory) do
      if type(v) == "function" then
        _diagnostic_factory[k] = v
      else
        _diagnostic_factory[k] = v
      end
    end
  end

  if opts.cap_types then
    for k, v in pairs(opts.cap_types) do
      if type(v) == "function" then
        _cap_types[k] = v
      else
        _cap_types[k] = v
      end
    end
  end
end

-- ── Public API (used by compiler layer) ──────────────────────────────────────

--- Creates a new Diagnostic using the configured factory
---@param stage    string
---@param node     string
---@param message  string
---@param severity? "error"|"warn"|"info"
---@return AbstractDiagnostic
function M.diag(stage, node, message, severity)
  return _diagnostic_factory.diag(stage, node, message, severity)
end

--- Backward-compat alias for diag()
M.error = M.diag

--- Format a diagnostic as a human-readable string
---@param d AbstractDiagnostic
---@return string
function M.format_diagnostic(d)
  return _diagnostic_factory.format(d)
end

--- Get capability type constants
---@return AbstractCapTypes
function M.cap_types()
  return _cap_types
end

--- Check if a string is a known capability type
---@param t string
---@return boolean
function M.is_cap_type_known(t)
  return _cap_types.is_known(t)
end

--- Get all capability types as a set
---@return table<string, boolean>
function M.cap_types_set()
  return _cap_types.as_set()
end

return M
