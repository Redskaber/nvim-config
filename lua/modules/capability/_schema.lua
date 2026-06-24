-- lua/modules/capability/schema.lua
-- P3: Schema validation for individual capability modules.

local M = {}

---@class ValidationResult
---@field ok boolean
---@field diags string[]

--- Validates a capability module's structure.
--- This is a generic schema validator for capability DSLs.
--- Specific cap_type validations are handled by core.domain.ext_schema.
---@param mod_name string
---@param cap table  The capability table returned by a module
---@return ValidationResult
function M.validate(mod_name, cap)
  local diags = {}
  local ok = true

  if type(cap) ~= "table" then
    ok = false
    table.insert(diags, ("Module '%s' must return a table."):format(mod_name))
    return { ok = ok, diags = diags }
  end

  if not cap.cap_type then
    ok = false
    table.insert(diags, ("Module '%s' is missing required field 'cap_type'."):format(mod_name))
  elseif type(cap.cap_type) ~= "string" then
    ok = false
    table.insert(diags, ("Field 'cap_type' in module '%s' must be a string."):format(mod_name))
  end

  if not cap.version then
    ok = false
    table.insert(diags, ("Module '%s' is missing required field 'version'."):format(mod_name))
  elseif type(cap.version) ~= "number" then
    ok = false
    table.insert(diags, ("Field 'version' in module '%s' must be a number."):format(mod_name))
  end

  -- Placeholder for image-specific validation
  if cap.cap_type == "image" then
    if cap.backends then
      for _, backend in ipairs(cap.backends) do
        if type(backend) ~= "string" then
          table.insert(
            diags,
            ("Image capability in module '%s': backend list contains non-string entry."):format(
              mod_name
            )
          )
          ok = false
        end
      end
    end
    if cap.plugins then
      for _, plugin in ipairs(cap.plugins) do
        if type(plugin) ~= "table" or type(plugin.name) ~= "string" then
          table.insert(
            diags,
            ("Image capability in module '%s': plugin entry must be a table with a 'name' string."):format(
              mod_name
            )
          )
          ok = false
        end
      end
    end
  end

  -- Placeholder for keybind-specific validation
  if cap.cap_type == "keybind" then
    if cap.bindings then
      for _, binding in ipairs(cap.bindings) do
        if type(binding) ~= "table" or not binding.lhs or not binding.rhs then
          table.insert(
            diags,
            ("Keybind capability in module '%s': binding entry must have 'lhs' and 'rhs'."):format(
              mod_name
            )
          )
          ok = false
        end
      end
    end
    if cap.preset then
      local presets = require("modules.capability.keybind_presets")
      if not presets.is_known(cap.preset) then
        table.insert(
          diags,
          ("Keybind capability in module '%s': unknown preset '%s'."):format(mod_name, cap.preset)
        )
      end
    end
  end

  -- Additional checks for DSL purity (Invariant 8 extended)
  -- "必须返回纯 Lua table", "无 require()，无 vim.*，无副作用", "getmetatable(m) == nil（无元表）"
  -- These are harder to check in a simple validator, might need static analysis or runtime hooks.
  -- For now, we assume the user will adhere to these.

  return { ok = ok, diags = diags }
end

return M
