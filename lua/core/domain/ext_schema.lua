-- lua/core/domain/ext_schema.lua
-- P3: Capability Type Schema for external capabilities.
-- P6: Uses centralized cap_types and keybind_presets_data.

local M = {}

local cap_types = require("core.domain.cap_types")
local keybind_presets = require("core.domain.keybind_presets_data")
local KNOWN_BACKENDS = {
  kitty = true,
  chafa = true,
  sixel = true,
  ueberzug = true,
}

local KNOWN_AI_PROVIDERS = {
  copilot = true,
  codeium = true,
  codecompanion = true,
  avante = true,
}

---@param cap_type string
---@param mod_name string
---@param cap table
---@return { ok: boolean, diags: string[] }
function M.validate(cap_type, mod_name, cap)
  local diags = {}
  local ok = true
  local CAP_TYPES = cap_types.as_set()

  if not CAP_TYPES[cap_type] then
    diags[#diags + 1] = ("Unknown cap_type '%s' for module '%s'"):format(cap_type, mod_name)
    return { ok = true, diags = diags }
  end

  if cap_type == cap_types.IMAGE or cap_type == cap_types.EDITOR then
    if not cap.backend and not cap.backends then
      ok = false
      diags[#diags + 1] = ("Image capability for '%s' is missing 'backend' or 'backends' field."):format(mod_name)
    end
    if cap.backends then
      for _, backend in ipairs(cap.backends) do
        if type(backend) == "string" and not KNOWN_BACKENDS[backend] then
          diags[#diags + 1] = ("Image capability for '%s': unknown backend '%s'."):format(mod_name, backend)
        end
      end
    end
    if cap.backend and type(cap.backend) == "string" and not KNOWN_BACKENDS[cap.backend] then
      diags[#diags + 1] = ("Image capability for '%s': unknown backend '%s'."):format(mod_name, cap.backend)
    end
    if cap.fallback and type(cap.fallback) == "string" and not KNOWN_BACKENDS[cap.fallback] then
      diags[#diags + 1] = ("Image capability for '%s': unknown fallback '%s'."):format(mod_name, cap.fallback)
    end
  elseif cap_type == cap_types.MEDIA then
    if not cap.viewers or #cap.viewers == 0 then
      ok = false
      diags[#diags + 1] = ("Media capability for '%s' is missing 'viewers' array."):format(mod_name)
    end
  elseif cap_type == cap_types.AI then
    if not cap.completion and not cap.chat and not cap.plugins then
      ok = false
      diags[#diags + 1] = ("AI capability for '%s' must define 'completion', 'chat', or 'plugins'."):format(mod_name)
    end
    if cap.completion and cap.completion.provider and not KNOWN_AI_PROVIDERS[cap.completion.provider] then
      diags[#diags + 1] = ("AI capability for '%s': unknown completion provider '%s'."):format(
        mod_name,
        cap.completion.provider
      )
    end
    if cap.chat and cap.chat.provider and not KNOWN_AI_PROVIDERS[cap.chat.provider] then
      diags[#diags + 1] = ("AI capability for '%s': unknown chat provider '%s'."):format(mod_name, cap.chat.provider)
    end
  elseif cap_type == cap_types.KEYBIND then
    if not cap.preset and not cap.groups and not cap.bindings then
      ok = false
      diags[#diags + 1] = ("Keybind capability for '%s' must define 'preset', 'groups', or 'bindings'."):format(
        mod_name
      )
    end
    if cap.preset and not keybind_presets.is_known(cap.preset) then
      diags[#diags + 1] = ("Keybind capability for '%s': unknown preset '%s' (known: %s)"):format(
        mod_name,
        cap.preset,
        table.concat(keybind_presets.ALL, ", ")
      )
    end
  end

  return { ok = ok, diags = diags }
end

---@return string[]
function M.known_cap_types()
  return cap_types.ALL
end

---@param diags string[]
---@return string
function M.format_diags(diags)
  if not diags or #diags == 0 then
    return ""
  end
  return table.concat(diags, "\n")
end

return M
