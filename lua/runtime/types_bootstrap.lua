-- lua/runtime/types_bootstrap.lua
-- Layer 4: Wire domain layer implementations into compiler abstract types.
--
-- This module configures the abstract type interfaces in core.compiler.types
-- with concrete implementations from the domain layer (core.domain.*).
--
-- Design principles:
-- 1. Compiler layer (L1) depends on abstractions (core.compiler.types)
-- 2. Domain layer (L2) provides concrete implementations
-- 3. Runtime layer (L4) wires them together via dependency injection
-- 4. This maintains strict layer boundaries while allowing type sharing

local M = {}
local _done = false

function M.setup()
  if _done then
    return
  end
  _done = true

  -- Get concrete implementations from domain layer
  local diagnostic = require("core.domain.diagnostic")
  local cap_types = require("core.domain.cap_types")

  -- Configure abstract type interfaces in compiler layer
  local types = require("core.compiler.types")
  types.configure({
    diagnostic_factory = {
      new = diagnostic.new,
      diag = diagnostic.diag,
      format = diagnostic.format,
    },
    cap_types = cap_types,
  })
end

return M