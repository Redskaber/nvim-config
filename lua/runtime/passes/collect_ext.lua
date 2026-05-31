-- lua/runtime/passes/collect_ext.lua
-- P3: Collects external capability modules and populates ir.ext_caps.

local M = {}

local ir_mod = require("core.compiler.ir")
local cap_schema = require("modules.capability.schema")
local ext_schema = require("core.domain.ext_schema")

local _registered_modules = {}

--- Register external capability modules to be collected.
--- This replaces the existing list, it does not append.
---@param modules string[]  List of module paths (e.g., "modules.cap.image")
function M.register(modules)
  assert(type(modules) == "table", "modules must be a table")
  _registered_modules = modules
end

--- Get the list of currently registered external capability modules.
---@return string[]
function M.registered()
  return _registered_modules
end

M.pass = {
  name = "collect_ext",
  input_state = "collecting",
  output_state = "collecting",

  --- Run the collect_ext pass.
  --- Populates ir.ext_caps from registered capability modules.
  ---@param ir IR
  ---@return IR
  run = function(ir)
    local next_ir = ir_mod.with(ir, { ext_caps = ir_mod.deep_copy(ir.ext_caps) })
    local module_hashes = ir_mod.deep_copy(ir.meta.module_hashes or {})
    local diagnostics = ir_mod.deep_copy(ir.diagnostics)

    for _, mod_path in ipairs(_registered_modules) do
      local ok, cap = pcall(require, mod_path)
      if not ok then
        table.insert(diagnostics, ir_mod.diag(
          next_ir.stage, mod_path, ("Failed to load capability module '%s': %s"):format(mod_path, cap)
        ))
        goto continue
      end

      -- Validate against general capability module schema (cap_type, version, etc.)
      local validation_res = cap_schema.validate(mod_path, cap)
      if not validation_res.ok then
        for _, diag_msg in ipairs(validation_res.diags) do
          table.insert(diagnostics, ir_mod.diag(next_ir.stage, mod_path, diag_msg))
        end
        goto continue
      end

      -- Validate against cap_type specific schema
      local ext_validation_res = ext_schema.validate(cap.cap_type, mod_path, cap)
      if not ext_validation_res.ok then
        for _, diag_msg in ipairs(ext_validation_res.diags) do
          table.insert(diagnostics, ir_mod.diag(next_ir.stage, mod_path, diag_msg))
        end
      -- For forward-compatibility, unknown cap_types are warnings, not errors
      elseif #ext_validation_res.diags > 0 then
        for _, diag_msg in ipairs(ext_validation_res.diags) do
          table.insert(diagnostics, ir_mod.diag(next_ir.stage, mod_path, diag_msg, "warn"))
        end
      end

      if not next_ir.ext_caps[cap.cap_type] then
        next_ir.ext_caps[cap.cap_type] = {}
      end
      next_ir.ext_caps[cap.cap_type][mod_path] = cap

      -- Update module hashes for cache invalidation
      module_hashes[mod_path] = os.time() -- Placeholder for actual file hash

      ::continue::
    end

    next_ir = ir_mod.with(next_ir, { diagnostics = diagnostics, meta = ir_mod.with(next_ir.meta, { module_hashes = module_hashes }) })
    return next_ir
  end,
}

return M
