-- ~/.config/nvim/lua/core/pass.lua
-- Standard Pass interface (P0-2).
--
-- A Pass is a table with two mandatory fields:
--
--   name     : string   — unique identifier, used in error messages and timings
--   run      : (IR) -> IR  — pure transformation; returns a NEW IR (never mutates)
--   validate : (IR) -> CompileError[]  — pre-conditions check (may be nil = skip)
--
-- Passes are assembled into an explicit ordered list in runtime/pipeline.lua.
-- Any Pass can be run standalone for debugging (P0-2 supplement).

local ir_mod = require("core.ir")

local M = {}

---@class Pass
---@field name     string
---@field run      fun(ir: IR): IR
---@field validate fun(ir: IR): CompileError[]|nil

--- Assert that a table satisfies the Pass interface.
--- Throws a descriptive error if not.
---@param p any
function M.assert_valid(p)
  assert(type(p) == "table", "Pass must be a table, got " .. type(p))
  assert(type(p.name) == "string", "Pass.name must be a string")
  assert(type(p.run) == "function", "Pass.run must be a function")
  -- validate is optional but, if present, must be a function
  if p.validate ~= nil then
    assert(type(p.validate) == "function", "Pass.validate must be a function or nil")
  end
end

--- Run a single Pass with pre-condition validation.
--- Returns (new_ir, CompileError[]).  The input IR is never mutated.
---@param pass Pass
---@param ir   IR
---@return IR, CompileError[]
function M.run_pass(pass, ir)
  -- Optional pre-condition validation
  local pre_errors = {}
  if pass.validate then
    local ok, result = pcall(pass.validate, ir)
    if not ok then
      pre_errors[#pre_errors + 1] = ir_mod.error(pass.name, "validate", tostring(result))
    elseif type(result) == "table" then
      vim.list_extend(pre_errors, result)
    end
  end

  if #pre_errors > 0 then
    -- Pre-conditions failed; propagate errors but keep IR unchanged.
    local acc = ir
    for _, e in ipairs(pre_errors) do
      acc = ir_mod.append_error(acc, e)
    end
    return acc, pre_errors
  end

  -- Execute the transformation in a protected call
  local ok, next_ir = pcall(pass.run, ir)
  if not ok then
    local err = ir_mod.error(pass.name, "run", tostring(next_ir))
    return ir_mod.append_error(ir, err), { err }
  end

  if type(next_ir) ~= "table" then
    local err = ir_mod.error(pass.name, "run", "Pass.run returned " .. type(next_ir) .. " instead of IR table")
    return ir_mod.append_error(ir, err), { err }
  end

  return next_ir, {}
end

return M
