-- lua/core/domain/ext_schema.lua
-- P3: Capability Type Schema for external capabilities.
-- P6: Uses centralized cap_types and keybind_presets_data.
-- Extended: complete per-type field validation for all known cap_types.

local M = {}

local cap_types = require("core.domain.cap_types")
local keybind_presets = require("core.domain.keybind_presets_data")

-- ── Known value sets ──────────────────────────────────────────────────────────

local KNOWN_IMAGE_BACKENDS = {
  kitty = true,
  chafa = true,
  sixel = true,
  ueberzug = true,
}

local KNOWN_VIEWER_KINDS = {
  image = true,
  video = true,
  pdf = true,
  hex = true,
  csv = true,
  audio = true,
  document = true,
}

local KNOWN_AI_PROVIDERS = {
  copilot = true,
  codeium = true,
  codecompanion = true,
  avante = true,
}

local KNOWN_AI_ADAPTERS = {
  openai = true,
  anthropic = true,
  ollama = true,
  gemini = true,
  azure = true,
  copilot = true,
  groq = true,
}

-- ── Internal helpers ──────────────────────────────────────────────────────────

---@param diags table[]
---@param path  string
---@param msg   string
local function err(diags, path, msg)
  diags[#diags + 1] = { ok = false, severity = "error", path = path, message = msg }
end

---@param diags table[]
---@param path  string
---@param msg   string
local function warn(diags, path, msg)
  diags[#diags + 1] = { ok = true, severity = "warn", path = path, message = msg }
end

-- ── cap_type: image ───────────────────────────────────────────────────────────

local function validate_image(mod_name, cap, diags)
  local path_prefix = ("image capability for '%s'"):format(mod_name)

  -- backend / backends: at least one should be present (warn if missing)
  if not cap.backend and not cap.backends then
    warn(diags, mod_name .. ".backend", (path_prefix .. ": missing 'backend' or 'backends' field"))
  end

  -- validate single backend
  if cap.backend then
    if type(cap.backend) ~= "string" then
      err(diags, mod_name .. ".backend", (path_prefix .. ": 'backend' must be a string"))
    elseif not KNOWN_IMAGE_BACKENDS[cap.backend] then
      err(diags, mod_name .. ".backend", (path_prefix .. ": unknown backend '%s'"):format(cap.backend))
    end
  end

  -- validate backends list
  if cap.backends then
    if type(cap.backends) ~= "table" then
      err(diags, mod_name .. ".backends", (path_prefix .. ": 'backends' must be a list"))
    else
      for i, b in ipairs(cap.backends) do
        if type(b) ~= "string" then
          err(diags, ("%s.backends[%d]"):format(mod_name, i), (path_prefix .. ": backend entry must be a string"))
        elseif not KNOWN_IMAGE_BACKENDS[b] then
          warn(diags, ("%s.backends[%d]"):format(mod_name, i), (path_prefix .. ": unknown backend '%s'"):format(b))
        end
      end
    end
  end

  -- validate fallback
  if cap.fallback ~= nil then
    if type(cap.fallback) ~= "string" then
      err(diags, mod_name .. ".fallback", (path_prefix .. ": 'fallback' must be a string"))
    elseif not KNOWN_IMAGE_BACKENDS[cap.fallback] then
      warn(diags, mod_name .. ".fallback", (path_prefix .. ": unknown fallback '%s'"):format(cap.fallback))
    end
  end

  -- validate filetypes list
  if cap.filetypes ~= nil then
    if type(cap.filetypes) ~= "table" then
      err(diags, mod_name .. ".filetypes", (path_prefix .. ": 'filetypes' must be a list"))
    else
      for i, ft in ipairs(cap.filetypes) do
        if type(ft) ~= "string" then
          err(
            diags,
            ("%s.filetypes[%d]"):format(mod_name, i),
            (path_prefix .. ": filetypes entry must be a string, got %s"):format(type(ft))
          )
        end
      end
    end
  end

  -- validate numeric fields (warn, not error)
  if cap.max_width ~= nil and type(cap.max_width) ~= "number" then
    warn(diags, mod_name .. ".max_width", (path_prefix .. ": 'max_width' should be a number"))
  end
  if cap.max_height ~= nil and type(cap.max_height) ~= "number" then
    warn(diags, mod_name .. ".max_height", (path_prefix .. ": 'max_height' should be a number"))
  end

  -- integrations: optional table of { [name]: boolean }
  if cap.integrations ~= nil and type(cap.integrations) ~= "table" then
    warn(diags, mod_name .. ".integrations", (path_prefix .. ": 'integrations' should be a table"))
  end
end

-- ── cap_type: editor (same shape as image, different semantic use) ────────────

local function validate_editor(mod_name, cap, diags)
  -- editor caps share the same backend shape as image caps
  validate_image(mod_name, cap, diags)
end

-- ── cap_type: media ───────────────────────────────────────────────────────────

local function validate_media(mod_name, cap, diags)
  local path_prefix = ("media capability for '%s'"):format(mod_name)

  if not cap.viewers or type(cap.viewers) ~= "table" then
    err(diags, mod_name .. ".viewers", (path_prefix .. ": missing 'viewers' — expected a list"))
    return
  end

  if #cap.viewers == 0 then
    err(diags, mod_name .. ".viewers", (path_prefix .. ": 'viewers' must be non-empty"))
    return
  end

  for i, v in ipairs(cap.viewers) do
    local vpath = ("%s.viewers[%d]"):format(mod_name, i)
    if type(v) ~= "table" then
      err(diags, vpath, (path_prefix .. ": viewer entry must be a table"))
    else
      if not v.kind then
        err(diags, vpath .. ".kind", (path_prefix .. ": viewer missing 'kind' field"))
      elseif not KNOWN_VIEWER_KINDS[v.kind] then
        warn(diags, vpath .. ".kind", (path_prefix .. ": unknown viewer kind '%s'"):format(v.kind))
      end
      if not v.plugin then
        err(diags, vpath .. ".plugin", (path_prefix .. ": viewer missing 'plugin' field"))
      elseif type(v.plugin) ~= "string" then
        err(diags, vpath .. ".plugin", (path_prefix .. ": viewer 'plugin' must be a string"))
      end
      if v.filetypes ~= nil and type(v.filetypes) ~= "table" then
        warn(diags, vpath .. ".filetypes", (path_prefix .. ": viewer 'filetypes' should be a list"))
      end
    end
  end
end

-- ── cap_type: ai ──────────────────────────────────────────────────────────────

local function validate_ai(mod_name, cap, diags)
  local path_prefix = ("AI capability for '%s'"):format(mod_name)

  -- An AI cap with no completion/chat/plugins is valid (empty — still load)
  -- but we warn if none of the useful fields are present and it has no plugins
  local has_substance = cap.completion or cap.chat or cap.plugins or cap.provides
  if not has_substance then
    warn(
      diags,
      mod_name,
      (path_prefix .. ": no 'completion', 'chat', 'plugins', or 'provides' defined — cap will be a no-op")
    )
  end

  -- completion
  if cap.completion ~= nil then
    if type(cap.completion) ~= "table" then
      err(diags, mod_name .. ".completion", (path_prefix .. ": 'completion' must be a table"))
    else
      if cap.completion.provider and not KNOWN_AI_PROVIDERS[cap.completion.provider] then
        warn(
          diags,
          mod_name .. ".completion.provider",
          (path_prefix .. ": unknown completion provider '%s'"):format(cap.completion.provider)
        )
      end
    end
  end

  -- chat
  if cap.chat ~= nil then
    if type(cap.chat) ~= "table" then
      err(diags, mod_name .. ".chat", (path_prefix .. ": 'chat' must be a table"))
    else
      if cap.chat.provider and not KNOWN_AI_PROVIDERS[cap.chat.provider] then
        warn(
          diags,
          mod_name .. ".chat.provider",
          (path_prefix .. ": unknown chat provider '%s'"):format(cap.chat.provider)
        )
      end
      if cap.chat.adapter and not KNOWN_AI_ADAPTERS[cap.chat.adapter] then
        warn(diags, mod_name .. ".chat.adapter", (path_prefix .. ": unknown chat adapter '%s'"):format(cap.chat.adapter))
      end
    end
  end

  -- plugins: list of plugin spec tables
  if cap.plugins ~= nil then
    if type(cap.plugins) ~= "table" then
      err(diags, mod_name .. ".plugins", (path_prefix .. ": 'plugins' must be a list"))
    else
      for i, p in ipairs(cap.plugins) do
        local ppath = ("%s.plugins[%d]"):format(mod_name, i)
        if type(p) ~= "table" then
          err(diags, ppath, (path_prefix .. ": plugin entry must be a table"))
        elseif type(p.name) ~= "string" or p.name == "" then
          err(diags, ppath .. ".name", (path_prefix .. ": plugin 'name' must be a non-empty string"))
        end
      end
    end
  end
end

-- ── cap_type: keybind ─────────────────────────────────────────────────────────

local function validate_keybind(mod_name, cap, diags)
  local path_prefix = ("keybind capability for '%s'"):format(mod_name)

  if not cap.preset and not cap.groups and not cap.bindings then
    err(diags, mod_name, (path_prefix .. ": must define at least one of 'preset', 'groups', or 'bindings'"))
  end

  -- preset validation
  if cap.preset ~= nil then
    if type(cap.preset) ~= "string" then
      err(diags, mod_name .. ".preset", (path_prefix .. ": 'preset' must be a string"))
    elseif not keybind_presets.is_known(cap.preset) then
      warn(
        diags,
        mod_name .. ".preset",
        (path_prefix .. ": unknown preset '%s' (known: %s)"):format(cap.preset, table.concat(keybind_presets.ALL, ", "))
      )
    end
  end

  -- groups validation
  if cap.groups ~= nil then
    if type(cap.groups) ~= "table" then
      err(diags, mod_name .. ".groups", (path_prefix .. ": 'groups' must be a list"))
    else
      for i, g in ipairs(cap.groups) do
        local gpath = ("%s.groups[%d]"):format(mod_name, i)
        if type(g) ~= "table" then
          err(diags, gpath, (path_prefix .. ": group entry must be a table"))
        else
          if not g.prefix then
            err(diags, gpath .. ".prefix", (path_prefix .. ": group missing 'prefix' field"))
          elseif type(g.prefix) ~= "string" then
            err(diags, gpath .. ".prefix", (path_prefix .. ": group 'prefix' must be a string"))
          end
          if not g.name then
            err(diags, gpath .. ".name", (path_prefix .. ": group missing 'name' field"))
          elseif type(g.name) ~= "string" then
            err(diags, gpath .. ".name", (path_prefix .. ": group 'name' must be a string"))
          end
        end
      end
    end
  end

  -- bindings: optional list
  if cap.bindings ~= nil then
    if type(cap.bindings) ~= "table" then
      err(diags, mod_name .. ".bindings", (path_prefix .. ": 'bindings' must be a list"))
    else
      for i, b in ipairs(cap.bindings) do
        local bpath = ("%s.bindings[%d]"):format(mod_name, i)
        if type(b) ~= "table" then
          err(diags, bpath, (path_prefix .. ": binding entry must be a table"))
        else
          if not b.lhs then
            err(diags, bpath .. ".lhs", (path_prefix .. ": binding missing 'lhs' field"))
          end
          if not b.rhs then
            err(diags, bpath .. ".rhs", (path_prefix .. ": binding missing 'rhs' field"))
          end
        end
      end
    end
  end
end

-- ── Public API ────────────────────────────────────────────────────────────────

---@param cap_type string
---@param mod_name string
---@param cap table
---@return { ok: boolean, diags: table[] }
function M.validate(cap_type, mod_name, cap)
  local diags = {}
  local CAP_TYPES = cap_types.as_set()

  if type(cap) ~= "table" then
    err(diags, mod_name, ("expected table for cap, got %s"):format(type(cap)))
    return { ok = false, diags = diags }
  end

  if not CAP_TYPES[cap_type] then
    diags[#diags + 1] = {
      ok = false,
      severity = "error",
      path = mod_name,
      message = ("unknown cap_type '%s' for module '%s'"):format(cap_type, mod_name),
    }
    return { ok = false, diags = diags }
  end

  if cap_type == cap_types.IMAGE then
    validate_image(mod_name, cap, diags)
  elseif cap_type == cap_types.EDITOR then
    validate_editor(mod_name, cap, diags)
  elseif cap_type == cap_types.MEDIA then
    validate_media(mod_name, cap, diags)
  elseif cap_type == cap_types.AI then
    validate_ai(mod_name, cap, diags)
  elseif cap_type == cap_types.KEYBIND then
    validate_keybind(mod_name, cap, diags)
  end

  -- Determine overall ok: any error-severity entry → not ok
  local ok = true
  for _, d in ipairs(diags) do
    if d.ok == false or d.severity == "error" then
      ok = false
      break
    end
  end

  return { ok = ok, diags = diags }
end

---@return string[]
function M.known_cap_types()
  return cap_types.ALL
end

---@param diags table[]
---@return string
function M.format_diags(diags)
  if not diags or #diags == 0 then
    return ""
  end
  local parts = {}
  for _, d in ipairs(diags) do
    parts[#parts + 1] = ("[%s] %s: %s"):format(d.severity or "error", d.path or "?", d.message or "?")
  end
  return table.concat(parts, "\n")
end

return M
