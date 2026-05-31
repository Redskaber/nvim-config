-- lua/core/domain/ext_schema.lua
-- P3: Capability Type Schema for external capabilities.

local M = {}

local CAP_TYPES = {
  image = true,
  media = true,
  ai = true,
  keybind = true,
  editor = true, -- Added editor as per IR.ext_caps initialization
}

---@class ValidationResult
---@field ok boolean
---@field diags table<string, string>

--- Validate a capability table against its cap_type schema.
---@param cap_type string
---@param mod_name string
---@param cap table
---@return ValidationResult
function M.validate(cap_type, mod_name, cap)
  local diags = {}
  local ok = true

  if not CAP_TYPES[cap_type] then
    diags[#diags + 1] = ("Unknown cap_type '%s' for module '%s'"):format(cap_type, mod_name)
    -- For forward compatibility, unknown cap_types are not errors, just warnings.
    ok = true
  end

  -- Placeholder for actual validation logic based on cap_type
  -- This will be expanded as individual cap_type schemas are defined.
  if cap_type == "image" then
    if not cap.backend then
      ok = false
      diags[#diags + 1] = ("Image capability for '%s' is missing 'backend' field."):format(mod_name)
    end
    -- Add more image specific validations here
  elseif cap_type == "media" then
    if not cap.viewers or #cap.viewers == 0 then
      ok = false
      diags[#diags + 1] = ("Media capability for '%s' is missing 'viewers' array."):format(mod_name)
    end
    -- Add more media specific validations here
  elseif cap_type == "ai" then
    if not cap.completion and not cap.chat then
      ok = false
      diags[#diags + 1] = ("AI capability for '%s' must define 'completion' or 'chat'."):format(mod_name)
    end
    -- Add more AI specific validations here
  elseif cap_type == "keybind" then
    if not cap.preset and not cap.groups then
      ok = false
      diags[#diags + 1] = ("Keybind capability for '%s' must define 'preset' or 'groups'."):format(mod_name)
    end
    -- Add more keybind specific validations here
  end

  return { ok = ok, diags = diags }
end

--- Get all known capability types.
---@return string[]
function M.known_cap_types()
  local types = {}
  for k in pairs(CAP_TYPES) do
    types[#types + 1] = k
  end
  table.sort(types)
  return types
end

--- Format diagnostics into a readable string.
---@param diags table<string, string>
---@return string
function M.format_diags(diags)
  if #diags == 0 then return "" end
  return table.concat(diags, "\n")
end

return M
