-- lua/core/domain/ext_schema.lua
-- P3: Capability Type Schema for external capabilities.
-- P6: Uses centralized cap_types and keybind_presets_data.
-- Refactored if/elseif cap_type dispatch to
-- jump-table pattern (VALIDATORS map). Adding a new cap_type now requires
-- only adding a validator function + registering it in the map — no need
-- to modify the validate() dispatch logic.

local M = {}

local cap_types = require("core.domain.cap_types")
local keybind_presets = require("core.domain.keybind_presets_data")
-- use unified diagnostic.new() for all diags.
-- This replaces the inline {ok, severity, path, message} format with
-- the canonical Diagnostic{code, stage, node, message, severity} shape.
local diagnostic = require("core.domain.diagnostic")

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

-- OPT-A (2026-06-23): unified diag helpers using diagnostic.new()
-- All diags now have canonical shape: {code, stage, node, message, severity}
---@param diags table[]
---@param path  string
---@param msg   string
local function err(diags, path, msg)
  diags[#diags + 1] = diagnostic.new("ext_schema", path, msg, "error")
end

---@param diags table[]
---@param path  string
---@param msg   string
local function warn(diags, path, msg)
  diags[#diags + 1] = diagnostic.new("ext_schema", path, msg, "warn")
end

-- ── Reusable field validators (composable building blocks) ────────────────────

--- Validate a string-typed field against a known-values set.
---@param diags table[]
---@param path string
---@param field_name string
---@param value any
---@param known_set table<string, boolean>
---@param path_prefix string
local function validate_string_field(diags, path, field_name, value, known_set, path_prefix)
  if value == nil then
    return
  end
  if type(value) ~= "string" then
    err(diags, path, (path_prefix .. ": '%s' must be a string"):format(field_name))
  elseif not known_set[value] then
    err(diags, path, (path_prefix .. ": unknown %s '%s'"):format(field_name, value))
  end
end

--- Validate a string-or-warn field (warn instead of error for unknown values).
local function validate_string_field_warn(diags, path, field_name, value, known_set, path_prefix)
  if value == nil then
    return
  end
  if type(value) ~= "string" then
    err(diags, path, (path_prefix .. ": '%s' must be a string"):format(field_name))
  elseif not known_set[value] then
    warn(diags, path, (path_prefix .. ": unknown %s '%s'"):format(field_name, value))
  end
end

--- Validate a list field (must be table, each element validated by elem_validator).
---@param diags table[]
---@param path string
---@param field_name string
---@param value any
---@param path_prefix string
---@param elem_validator? fun(diags, path, elem, idx, path_prefix)  -- optional
local function validate_list_field(diags, path, field_name, value, path_prefix, elem_validator)
  if value == nil then
    return
  end
  if type(value) ~= "table" then
    err(diags, path, (path_prefix .. ": expected list for '%s'"):format(field_name))
    return
  end
  if elem_validator then
    for i, elem in ipairs(value) do
      elem_validator(diags, ("%s[%d]"):format(path, i), elem, i, path_prefix)
    end
  end
end

--- Validate a numeric field (warn if not number).
local function validate_numeric_field_warn(diags, path, field_name, value, path_prefix)
  if value ~= nil and type(value) ~= "number" then
    warn(diags, path, (path_prefix .. ": '%s' should be a number"):format(field_name))
  end
end

-- ── cap_type validators (jump-table entries) ─────────────────────────────────

local function validate_image(mod_name, cap, diags)
  local pp = ("image capability for '%s'"):format(mod_name)

  if not cap.backend and not cap.backends then
    warn(diags, mod_name .. ".backend", pp .. ": missing 'backend' or 'backends' field")
  end

  -- FIX-TEST (2026-06-23): backend unknown → error (test expects err, not warn)
  validate_string_field(
    diags,
    mod_name .. ".backend",
    "backend",
    cap.backend,
    KNOWN_IMAGE_BACKENDS,
    pp
  )

  -- backends list
  if cap.backends ~= nil then
    if type(cap.backends) ~= "table" then
      err(diags, mod_name .. ".backends", pp .. ": expected list for 'backends'")
    else
      for i, b in ipairs(cap.backends) do
        local bpath = ("%s.backends[%d]"):format(mod_name, i)
        if type(b) ~= "string" then
          err(diags, bpath, pp .. ": backend entry must be a string")
        elseif not KNOWN_IMAGE_BACKENDS[b] then
          warn(diags, bpath, (pp .. ": unknown backend '%s'"):format(b))
        end
      end
    end
  end

  validate_string_field_warn(
    diags,
    mod_name .. ".fallback",
    "fallback",
    cap.fallback,
    KNOWN_IMAGE_BACKENDS,
    pp
  )

  -- filetypes list
  if cap.filetypes ~= nil then
    if type(cap.filetypes) ~= "table" then
      err(diags, mod_name .. ".filetypes", pp .. ": 'filetypes' must be a list")
    else
      for i, ft in ipairs(cap.filetypes) do
        if type(ft) ~= "string" then
          err(
            diags,
            ("%s.filetypes[%d]"):format(mod_name, i),
            pp .. ": expected string in filetypes, got " .. type(ft)
          )
        end
      end
    end
  end

  validate_numeric_field_warn(diags, mod_name .. ".max_width", "max_width", cap.max_width, pp)
  validate_numeric_field_warn(diags, mod_name .. ".max_height", "max_height", cap.max_height, pp)

  if cap.integrations ~= nil and type(cap.integrations) ~= "table" then
    warn(diags, mod_name .. ".integrations", pp .. ": 'integrations' should be a table")
  end
end

-- editor shares image shape
local function validate_editor(mod_name, cap, diags) validate_image(mod_name, cap, diags) end

local function validate_media(mod_name, cap, diags)
  local pp = ("media capability for '%s'"):format(mod_name)

  if not cap.viewers or type(cap.viewers) ~= "table" then
    err(diags, mod_name .. ".viewers", pp .. ": expected list for 'viewers'")
    return
  end
  if #cap.viewers == 0 then
    err(diags, mod_name .. ".viewers", pp .. ": 'viewers' must be non-empty")
    return
  end

  for i, v in ipairs(cap.viewers) do
    local vpath = ("%s.viewers[%d]"):format(mod_name, i)
    if type(v) ~= "table" then
      err(diags, vpath, pp .. ": viewer entry must be a table")
    else
      if not v.kind then
        err(diags, vpath .. ".kind", pp .. ": viewer missing 'kind' field")
      elseif not KNOWN_VIEWER_KINDS[v.kind] then
        warn(diags, vpath .. ".kind", (pp .. ": unknown viewer kind '%s'"):format(v.kind))
      end
      if not v.plugin then
        err(diags, vpath .. ".plugin", pp .. ": viewer missing 'plugin' field")
      elseif type(v.plugin) ~= "string" then
        err(diags, vpath .. ".plugin", pp .. ": viewer 'plugin' must be a string")
      end
      if v.filetypes ~= nil and type(v.filetypes) ~= "table" then
        warn(diags, vpath .. ".filetypes", pp .. ": viewer 'filetypes' should be a list")
      end
    end
  end
end

local function validate_ai(mod_name, cap, diags)
  local pp = ("AI capability for '%s'"):format(mod_name)

  local has_substance = cap.completion or cap.chat or cap.plugins or cap.provides
  if not has_substance then
    warn(
      diags,
      mod_name,
      pp .. ": no 'completion', 'chat', 'plugins', or 'provides' defined — cap will be a no-op"
    )
  end

  if cap.completion ~= nil then
    if type(cap.completion) ~= "table" then
      err(diags, mod_name .. ".completion", pp .. ": expected table for 'completion'")
    elseif cap.completion.provider and not KNOWN_AI_PROVIDERS[cap.completion.provider] then
      warn(
        diags,
        mod_name .. ".completion.provider",
        (pp .. ": unknown completion provider '%s'"):format(cap.completion.provider)
      )
    end
  end

  if cap.chat ~= nil then
    if type(cap.chat) ~= "table" then
      err(diags, mod_name .. ".chat", pp .. ": 'chat' must be a table")
    else
      if cap.chat.provider and not KNOWN_AI_PROVIDERS[cap.chat.provider] then
        warn(
          diags,
          mod_name .. ".chat.provider",
          (pp .. ": unknown chat provider '%s'"):format(cap.chat.provider)
        )
      end
      if cap.chat.adapter and not KNOWN_AI_ADAPTERS[cap.chat.adapter] then
        warn(
          diags,
          mod_name .. ".chat.adapter",
          (pp .. ": unknown chat adapter '%s'"):format(cap.chat.adapter)
        )
      end
    end
  end

  if cap.plugins ~= nil then
    if type(cap.plugins) ~= "table" then
      err(diags, mod_name .. ".plugins", pp .. ": 'plugins' must be a list")
    else
      for i, p in ipairs(cap.plugins) do
        local ppath = ("%s.plugins[%d]"):format(mod_name, i)
        if type(p) ~= "table" then
          err(diags, ppath, pp .. ": plugin entry must be a table")
        elseif type(p.name) ~= "string" or p.name == "" then
          err(diags, ppath .. ".name", pp .. ": plugin 'name' must be a non-empty string")
        end
      end
    end
  end
end

local function validate_keybind(mod_name, cap, diags)
  local pp = ("keybind capability for '%s'"):format(mod_name)

  if not cap.preset and not cap.groups and not cap.bindings then
    err(diags, mod_name, pp .. ": must define at least one of 'preset', 'groups', or 'bindings'")
  end

  if cap.preset ~= nil then
    if type(cap.preset) ~= "string" then
      err(diags, mod_name .. ".preset", pp .. ": 'preset' must be a string")
    elseif not keybind_presets.is_known(cap.preset) then
      warn(
        diags,
        mod_name .. ".preset",
        (pp .. ": unknown preset '%s' (known: %s)"):format(
          cap.preset,
          table.concat(keybind_presets.ALL, ", ")
        )
      )
    end
  end

  if cap.groups ~= nil then
    if type(cap.groups) ~= "table" then
      err(diags, mod_name .. ".groups", pp .. ": expected list for 'groups'")
    else
      for i, g in ipairs(cap.groups) do
        local gpath = ("%s.groups[%d]"):format(mod_name, i)
        if type(g) ~= "table" then
          err(diags, gpath, pp .. ": group entry must be a table")
        else
          if not g.prefix then
            err(diags, gpath .. ".prefix", pp .. ": group missing 'prefix' field")
          elseif type(g.prefix) ~= "string" then
            err(diags, gpath .. ".prefix", pp .. ": group 'prefix' must be a string")
          end
          if not g.name then
            err(diags, gpath .. ".name", pp .. ": group missing 'name' field")
          elseif type(g.name) ~= "string" then
            err(diags, gpath .. ".name", pp .. ": group 'name' must be a string")
          end
        end
      end
    end
  end

  if cap.bindings ~= nil then
    if type(cap.bindings) ~= "table" then
      err(diags, mod_name .. ".bindings", pp .. ": 'bindings' must be a list")
    else
      for i, b in ipairs(cap.bindings) do
        local bpath = ("%s.bindings[%d]"):format(mod_name, i)
        if type(b) ~= "table" then
          err(diags, bpath, pp .. ": binding entry must be a table")
        else
          if not b.lhs then
            err(diags, bpath .. ".lhs", pp .. ": binding missing 'lhs' field")
          end
          if not b.rhs then
            err(diags, bpath .. ".rhs", pp .. ": binding missing 'rhs' field")
          end
        end
      end
    end
  end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- JUMP TABLE: cap_type → validator function
-- ═══════════════════════════════════════════════════════════════════════════
-- Replaced if/elseif cap_type dispatch chain with a jump table.
-- To add a new cap_type validator:
--   1. Write `local function validate_mytype(mod_name, cap, diags) ... end`
--   2. Add entry: `VALIDATORS[cap_types.MYTYPE] = validate_mytype`
-- No changes needed to M.validate() — it automatically dispatches via the map.
-- This is extensible: third-party cap types can register validators too.

local VALIDATORS = {
  [cap_types.IMAGE] = validate_image,
  [cap_types.EDITOR] = validate_editor,
  [cap_types.MEDIA] = validate_media,
  [cap_types.AI] = validate_ai,
  [cap_types.KEYBIND] = validate_keybind,
}

--- Register a validator for a custom cap_type (extensibility API).
--- Third-party modules can call this to add their own cap_type validation.
---@param type_name string
---@param validator fun(mod_name: string, cap: table, diags: table[])
function M.register_validator(type_name, validator)
  if type(type_name) == "string" and type(validator) == "function" then
    VALIDATORS[type_name] = validator
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
    -- OPT-A: use err() helper (creates diagnostic.new() consistently)
    err(diags, mod_name, ("unknown cap_type '%s' for module '%s'"):format(cap_type, mod_name))
    return { ok = false, diags = diags }
  end

  -- jump-table dispatch (replaces if/elseif chain)
  local validator = VALIDATORS[cap_type]
  if validator then
    validator(mod_name, cap, diags)
  end
  -- If no validator registered for this cap_type: silently skip
  -- (the cap_type is known but has no specific field validation)

  -- check severity only (diagnostic.new doesn't set .ok field)
  local ok = true
  for _, d in ipairs(diags) do
    if d.severity == "error" then
      ok = false
      break
    end
  end

  return { ok = ok, diags = diags }
end

---@return string[]
function M.known_cap_types() return cap_types.ALL end

---@param diags table[]
---@return string
function M.format_diags(diags)
  if not diags or #diags == 0 then
    return ""
  end
  local parts = {}
  for _, d in ipairs(diags) do
    parts[#parts + 1] = ("[%s] %s: %s"):format(
      d.severity or "error",
      d.path or d.node or "?",
      d.message or "?"
    )
  end
  return table.concat(parts, "\n")
end

return M