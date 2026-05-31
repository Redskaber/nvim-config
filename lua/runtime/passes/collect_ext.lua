-- lua/runtime/passes/collect_ext.lua
-- P3: Collects external capability modules and populates ir.ext_caps.

local M = {}

local ir_mod = require("core.compiler.ir")
local util = require("core.kernel.util")
local ports = require("core.compiler.ports")
local cap_schema = require("modules.capability.schema")
local ext_schema = require("core.domain.ext_schema")

local _registered_modules = {}

--- Register external capability modules to be collected (replaces list).
---@param modules string[]
function M.register(modules)
  assert(type(modules) == "table", "modules must be a table")
  _registered_modules = modules
end

---@return string[]
function M.registered()
  return _registered_modules
end

local function module_hash(mod_path)
  local path = ports.resolve_runtime_file(mod_path:gsub("%.", "/") .. ".lua")
  if not path then
    return "?"
  end
  return util.file_content_hash(path) or "?"
end

M.pass = {
  name = "collect_ext",
  input_state = "collecting",
  output_state = "collecting",

  ---@param ir IR
  ---@return IR
  run = function(ir)
    local next_ir = ir_mod.with(ir, { ext_caps = util.deep_copy(ir.ext_caps) })
    local module_hashes = util.deep_copy(ir.meta.module_hashes or {})
    local diagnostics = util.deep_copy(ir.diagnostics or {})

    for _, mod_path in ipairs(_registered_modules) do
      local ok, cap = pcall(require, mod_path)
      if not ok then
        diagnostics[#diagnostics + 1] = ir_mod.diag(
          next_ir.stage,
          mod_path,
          ("Failed to load capability module '%s': %s"):format(mod_path, cap)
        )
        goto continue
      end

      if cap.cap_type == "lang" then
        diagnostics[#diagnostics + 1] = ir_mod.diag(
          next_ir.stage,
          mod_path,
          ("cap_type 'lang' is reserved for lang modules; use modules/lang/* instead")
        )
        goto continue
      end

      local validation_res = cap_schema.validate(mod_path, cap)
      if not validation_res.ok then
        for _, diag_msg in ipairs(validation_res.diags) do
          diagnostics[#diagnostics + 1] = ir_mod.diag(next_ir.stage, mod_path, diag_msg)
        end
        goto continue
      end

      local ext_validation_res = ext_schema.validate(cap.cap_type, mod_path, cap)
      if not ext_validation_res.ok then
        for _, diag_msg in ipairs(ext_validation_res.diags) do
          diagnostics[#diagnostics + 1] = ir_mod.diag(next_ir.stage, mod_path, diag_msg)
        end
        goto continue
      end

      if #ext_validation_res.diags > 0 then
        for _, diag_msg in ipairs(ext_validation_res.diags) do
          diagnostics[#diagnostics + 1] = ir_mod.diag(next_ir.stage, mod_path, diag_msg, "warn")
        end
      end

      if not next_ir.ext_caps[cap.cap_type] then
        next_ir.ext_caps[cap.cap_type] = {}
      end
      next_ir.ext_caps[cap.cap_type][mod_path] = cap
      module_hashes[mod_path] = module_hash(mod_path)

      ::continue::
    end

    return ir_mod.with(next_ir, {
      diagnostics = diagnostics,
      meta = util.merge(next_ir.meta, { module_hashes = module_hashes }),
    })
  end,
}

-- Bootstrap default cap modules from data file (declarative scope control).
local cap_defaults = require("runtime.defaults.caps")
M.register(cap_defaults.modules)

return M
