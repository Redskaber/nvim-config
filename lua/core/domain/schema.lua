-- lua/core/domain/schema.lua
-- Layer 2 domain: typed DSL validator + error recovery.
--
-- Validates lang module capability tables (the AST layer).
-- Rules:
--   • formatters values → list of string | FormatterNode only.
--   • Sentinel strings (__xxx__) are rejected.
--   • Raw functions are rejected — use FormatterNode { kind, strategy }.
--   • FormatterNode.fn must NOT appear in source DSL (injected by normalize).
--   • mason[] contains only non-empty strings.
--   • On validation failure: returns structured Diagnostic, not a Lua error.

local M = {}

-- ── AST node type definitions ─────────────────────────────────────────────────

---@class FormatterNode
---@field kind      "formatter"
---@field name?     string         concrete formatter name
---@field strategy? string         strategy key, resolved by normalize pass
---@field fn?       fun(bufnr: integer): string[]   injected by normalize; NEVER in source

local KNOWN_NODE_KINDS = { formatter = true }

-- ── Diagnostic type ───────────────────────────────────────────────────────────

---@class SchemaDiagnostic
---@field code     string     machine-readable code e.g. "S001"  (TODO-3.2)
---@field path     string
---@field message  string
---@field severity "error"|"warn"

--- Deterministic diagnostic code from path (pure, idempotent across runs).
---@param path string
---@return string
local function schema_code(path)
  local util = require("core.kernel.util")
  return "S" .. string.sub(util.hash(path), 1, 3):upper()
end

---@param path     string
---@param message  string
---@param severity? "error"|"warn"
---@return SchemaDiagnostic
local function diag(path, message, severity)
  return { code = schema_code(path), path = path, message = message, severity = severity or "error" }
end

-- ── Internal validators ───────────────────────────────────────────────────────

local function is_sentinel(s)
  return type(s) == "string" and s:match("^__.+__$") ~= nil
end

---@param path  string
---@param node  table
---@param diags SchemaDiagnostic[]
local function validate_formatter_node(path, node, diags)
  if not KNOWN_NODE_KINDS[node.kind] then
    -- Pure Lua: collect keys without vim.tbl_keys
    local valid_kinds = {}
    for k in pairs(KNOWN_NODE_KINDS) do
      valid_kinds[#valid_kinds + 1] = k
    end
    table.sort(valid_kinds)
    diags[#diags + 1] =
      diag(path, ("unknown node kind %q; valid: %s"):format(tostring(node.kind), table.concat(valid_kinds, ", ")))
    return
  end
  if node.name ~= nil and type(node.name) ~= "string" then
    diags[#diags + 1] = diag(path .. ".name", "expected string, got " .. type(node.name))
  end
  if node.strategy ~= nil and type(node.strategy) ~= "string" then
    diags[#diags + 1] = diag(path .. ".strategy", "expected string, got " .. type(node.strategy))
  end
  -- fn must NOT appear in source DSL — it is injected by the normalize pass
  if node.fn ~= nil then
    diags[#diags + 1] =
      diag(path .. ".fn", "fn must not be set in source modules; it is injected by the normalize pass")
  end
end

---@param path  string
---@param value any
---@param diags SchemaDiagnostic[]
local function validate_ft_tool_map(path, value, diags)
  if type(value) ~= "table" then
    diags[#diags + 1] = diag(path, "expected table, got " .. type(value))
    return
  end
  for ft, list in pairs(value) do
    if type(ft) ~= "string" or ft == "" then
      diags[#diags + 1] = diag(path .. ".<key>", "key must be a non-empty string")
    end
    local item_path = path .. "." .. tostring(ft)
    if type(list) == "function" then
      diags[#diags + 1] = diag(
        item_path,
        'raw function values are not allowed; use FormatterNode: { kind = "formatter", strategy = "..." }'
      )
    elseif type(list) ~= "table" then
      diags[#diags + 1] = diag(item_path, "expected list, got " .. type(list))
    else
      for i, v in ipairs(list) do
        local elem_path = item_path .. "[" .. i .. "]"
        if type(v) == "table" then
          validate_formatter_node(elem_path, v, diags)
        elseif type(v) == "string" then
          if is_sentinel(v) then
            diags[#diags + 1] = diag(
              elem_path,
              ('sentinel %q is forbidden; use FormatterNode: { kind = "formatter", strategy = "..." }'):format(v)
            )
          end
        else
          diags[#diags + 1] = diag(elem_path, "expected string or FormatterNode, got " .. type(v))
        end
      end
    end
  end
end

---@param path  string
---@param value any
---@param diags SchemaDiagnostic[]
local function validate_linter_map(path, value, diags)
  if type(value) ~= "table" then
    diags[#diags + 1] = diag(path, "expected table, got " .. type(value))
    return
  end
  for ft, list in pairs(value) do
    if type(ft) ~= "string" or ft == "" then
      diags[#diags + 1] = diag(path .. ".<key>", "key must be a non-empty string")
    end
    local item_path = path .. "." .. tostring(ft)
    if type(list) ~= "table" then
      diags[#diags + 1] = diag(item_path, "expected list, got " .. type(list))
    else
      for i, v in ipairs(list) do
        local elem_path = item_path .. "[" .. i .. "]"
        if type(v) ~= "string" then
          diags[#diags + 1] = diag(elem_path, "linter entries must be strings, got " .. type(v))
        elseif is_sentinel(v) then
          diags[#diags + 1] = diag(elem_path, ("sentinel %q is forbidden in linters"):format(v))
        end
      end
    end
  end
end
---@param path  string
---@param value any
---@param diags SchemaDiagnostic[]
local function validate_string_list(path, value, diags)
  if type(value) ~= "table" then
    diags[#diags + 1] = diag(path, "expected list, got " .. type(value))
    return
  end
  for i, v in ipairs(value) do
    if type(v) ~= "string" then
      diags[#diags + 1] = diag(path .. "[" .. i .. "]", "expected string, got " .. type(v))
    end
  end
end

-- ── Schema version compatibility ─────────────────────────────────────────────

-- Current compiler schema version. Modules declaring a higher version
-- get a warn diagnostic (forward-compat: we try to process them anyway).
-- Modules declaring a lower version are accepted silently (backward-compat).
local CURRENT_SCHEMA_VERSION = 1
-- ── Public API ────────────────────────────────────────────────────────────────

---@class ValidationResult
---@field ok        boolean
---@field cap?      table
---@field diags     SchemaDiagnostic[]

--- Validate a raw capability table from a lang module.
---@param name string
---@param cap  table
---@return ValidationResult
function M.validate(name, cap)
  local diags = {}

  if type(cap) ~= "table" then
    return {
      ok = false,
      diags = { diag(name, "module must return a table, got " .. type(cap)) },
    }
  end

  -- TODO-6.1: version field compatibility check
  if cap.version ~= nil then
    if type(cap.version) ~= "number" then
      diags[#diags + 1] = diag(name .. ".version", "version must be a number, got " .. type(cap.version), "warn")
    elseif cap.version > CURRENT_SCHEMA_VERSION then
      diags[#diags + 1] = diag(
        name .. ".version",
        ("module declares version %d but compiler supports up to %d — processing anyway"):format(
          cap.version,
          CURRENT_SCHEMA_VERSION
        ),
        "warn"
      )
    end
  end
  if cap.lsp ~= nil then
    if type(cap.lsp) ~= "table" then
      diags[#diags + 1] = diag(name .. ".lsp", "expected table, got " .. type(cap.lsp))
    else
      for server, cfg in pairs(cap.lsp) do
        if type(server) ~= "string" or server == "" then
          diags[#diags + 1] = diag(name .. ".lsp.<key>", "server name must be a non-empty string")
        end
        if type(cfg) ~= "table" then
          diags[#diags + 1] = diag(name .. ".lsp." .. tostring(server), "expected table, got " .. type(cfg))
        end
      end
    end
  end

  if cap.formatters ~= nil then
    validate_ft_tool_map(name .. ".formatters", cap.formatters, diags)
  end
  if cap.linters ~= nil then
    validate_linter_map(name .. ".linters", cap.linters, diags)
  end

  if cap.treesitter ~= nil then
    validate_string_list(name .. ".treesitter", cap.treesitter, diags)
  end

  if cap.mason ~= nil then
    validate_string_list(name .. ".mason", cap.mason, diags)
    if type(cap.mason) == "table" then
      for i, v in ipairs(cap.mason) do
        if type(v) == "string" and v == "" then
          diags[#diags + 1] = diag(name .. ".mason[" .. i .. "]", "mason entries must be non-empty strings")
        end
      end
    end
  end

  local has_error = false
  for _, d in ipairs(diags) do
    if d.severity == "error" then
      has_error = true
      break
    end
  end

  return {
    ok = not has_error,
    cap = not has_error and cap or nil,
    diags = diags,
  }
end

--- Format diagnostics to a human-readable string.
---@param diags SchemaDiagnostic[]
---@return string
function M.format_diags(diags)
  if #diags == 0 then
    return ""
  end
  local lines = {}
  for _, d in ipairs(diags) do
    lines[#lines + 1] = ("[%s][schema:%s] %s — %s"):format(d.code or "?", d.severity, d.path, d.message)
  end
  return table.concat(lines, "\n")
end

return M