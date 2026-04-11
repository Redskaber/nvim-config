-- ~/.config/nvim/lua/core/schema.lua
-- Capability schema definition and fail-fast validation (P0-3).
-- Adapters receive validated AST; weak-typed tables never pass this gate.

local M = {}

-- ── AST node type definitions ────────────────────────────────────────────────

---@class FormatterNode
---@field kind      "formatter"
---@field name?     string   -- concrete formatter name
---@field strategy? string   -- strategy name (resolved in normalize stage)

-- Known AST node kinds for enumeration validation
local KNOWN_NODE_KINDS = { formatter = true, linter = true }
-- ── helpers ─────────────────────────────────────────────────────────────────

local function assert_type(path, value, expected)
  local t = type(value)
  if t ~= expected then
    error(("[schema] %s: expected %s, got %s"):format(path, expected, t), 3)
  end
end

local function assert_list_of_strings(path, value)
  assert_type(path, value, "table")
  for i, v in ipairs(value) do
    if type(v) ~= "string" then
      error(("[schema] %s[%d]: expected string, got %s"):format(path, i, type(v)), 3)
    end
  end
end

--- Validate a single AST node table (FormatterNode, LinterNode, etc.).
local function assert_ast_node(path, node)
  if not KNOWN_NODE_KINDS[node.kind] then
    error(
      ("[schema] %s: unknown node kind %q, expected one of: %s"):format(
        path,
        tostring(node.kind),
        table.concat(vim.tbl_keys(KNOWN_NODE_KINDS), ", ")
      ),
      3
    )
  end
  if node.name ~= nil and type(node.name) ~= "string" then
    error(("[schema] %s.name: expected string, got %s"):format(path, type(node.name)), 3)
  end
  if node.strategy ~= nil and type(node.strategy) ~= "string" then
    error(("[schema] %s.strategy: expected string, got %s"):format(path, type(node.strategy)), 3)
  end
end
--- Returns true if the string is a legacy Sentinel (surrounded by double underscores).
local function is_sentinel(s)
  return type(s) == "string" and s:match("^__.+__$") ~= nil
end
local function assert_string_map_of_string_lists(path, value)
  assert_type(path, value, "table")
  for ft, list in pairs(value) do
    if type(ft) ~= "string" or ft == "" then
      error(("[schema] %s key: expected non-empty string, got %s"):format(path, type(ft)), 3)
    end
    -- allow function sentinel for dynamic formatters (legacy)
    if type(list) == "function" then
      -- skip
    elseif type(list) == "table" then
      local item_path = path .. "." .. ft
      for i, v in ipairs(list) do
        if type(v) == "table" then
          assert_ast_node(item_path .. "[" .. i .. "]", v)
        elseif type(v) == "string" then
          if is_sentinel(v) then
            error(
              (
                "[schema] %s[%d]: Sentinel value %q is not allowed. "
                .. 'Use a FormatterNode instead, e.g. { kind = "formatter", strategy = "ruff_or_black" }'
              ):format(item_path, i, v),
              3
            )
          end
        else
          error(("[schema] %s[%d]: expected string or FormatterNode, got %s"):format(item_path, i, type(v)), 3)
        end
      end
    else
      error(("[schema] %s.%s: expected table (list), got %s"):format(path, ft, type(list)), 3)
    end
  end
end

-- ── public ──────────────────────────────────────────────────────────────────

--- Validate a raw capability table and return it (identity on success).
--- Throws a descriptive error on the first schema violation.
---@param name string  lang key for error messages
---@param cap  table
---@return table  the same cap (validated)
function M.validate(name, cap)
  local p = "cap[" .. name .. "]"
  assert_type(p, cap, "table")

  if cap.lsp ~= nil then
    assert_type(p .. ".lsp", cap.lsp, "table")
    for server, cfg in pairs(cap.lsp) do
      if type(server) ~= "string" then
        error(("[schema] %s.lsp key must be string, got %s"):format(p, type(server)), 2)
      end
      assert_type(p .. ".lsp." .. server, cfg, "table")
      if cfg.settings ~= nil and type(cfg.settings) ~= "table" then
        error(("[schema] %s.lsp.%s.settings must be table or nil"):format(p, server), 2)
      end
      if cfg.cmd ~= nil then
        assert_list_of_strings(p .. ".lsp." .. server .. ".cmd", cfg.cmd)
      end
      if cfg.mason ~= nil and type(cfg.mason) ~= "boolean" then
        error(("[schema] %s.lsp.%s.mason must be boolean or nil"):format(p, server), 2)
      end
    end
  end

  if cap.formatters ~= nil then
    assert_string_map_of_string_lists(p .. ".formatters", cap.formatters)
  end

  if cap.linters ~= nil then
    assert_string_map_of_string_lists(p .. ".linters", cap.linters)
  end

  if cap.treesitter ~= nil then
    assert_list_of_strings(p .. ".treesitter", cap.treesitter)
  end

  if cap.mason ~= nil then
    -- filter empty strings with a WARN rather than hard-erroring (Req 7.3)
    local filtered = {}
    for _, pkg in ipairs(cap.mason) do
      if type(pkg) == "string" and pkg ~= "" then
        filtered[#filtered + 1] = pkg
      elseif pkg == "" then
        vim.notify(("[schema] %s.mason: empty string filtered out"):format(p), vim.log.levels.WARN)
      else
        error(("[schema] %s.mason: expected string, got %s"):format(p, type(pkg)), 2)
      end
    end
    cap.mason = filtered
  end

  return cap
end

--- Validate IR field completeness for a given pipeline stage.
--- Delegates to core/ir.lua's ir.validate() and returns the error list.
---@param ir    table   IR object
---@param stage string  pipeline stage name
---@return string[]     list of error descriptions (empty = valid)
function M.validate_ir(ir, stage)
  local ir_mod = require("core.ir")
  return ir_mod.validate(ir, stage)
end
return M
