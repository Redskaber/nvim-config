-- ~/.config/nvim/lua/core/schema.lua
-- Capability schema: fail-fast AST validation gate (P0-1).
--
-- Rules enforced here:
--   • formatters values must be a list of string | FormatterNode — NO raw functions.
--   • Sentinel strings (surrounded by __) are rejected.
--   • All node kinds must be in KNOWN_NODE_KINDS.
--   • mason[] contains only non-empty strings.

local M = {}

-- ── AST node type definitions ────────────────────────────────────────────────

---@class FormatterNode
---@field kind      "formatter"
---@field name?     string                        -- concrete formatter name
---@field strategy? string                        -- strategy key (resolved in normalize)
---@field fn?       fun(bufnr: integer): string[] -- injected by normalize; never in source

-- Known AST node kinds
local KNOWN_NODE_KINDS = { formatter = true }

-- ── Helpers ──────────────────────────────────────────────────────────────────

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

local function is_sentinel(s)
  return type(s) == "string" and s:match("^__.+__$") ~= nil
end

local function assert_ast_node(path, node)
  if not KNOWN_NODE_KINDS[node.kind] then
    error(
      ("[schema] %s: unknown node kind %q; expected one of: %s"):format(
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
  -- fn is ONLY injected by the normalize pass — never allowed in source modules
  if node.fn ~= nil then
    error(("[schema] %s.fn: must not be set in lang module source; injected by normalize pass only"):format(path), 3)
  end
end

--- Validate a formatters or linters map: { [ft]: string[] | FormatterNode[] }
--- Raw function values are REJECTED (P0-1: no function fallback).
local function assert_ft_tool_map(path, value)
  assert_type(path, value, "table")
  for ft, list in pairs(value) do
    if type(ft) ~= "string" or ft == "" then
      error(("[schema] %s key: expected non-empty string, got %s"):format(path, type(ft)), 3)
    end
    -- STRICT: reject raw functions — use FormatterNode { kind="formatter", strategy="..." }
    if type(list) == "function" then
      error(
        (
          "[schema] %s.%s: raw function values are not allowed. "
          .. 'Use a FormatterNode instead: { kind = "formatter", strategy = "my_strategy" }'
        ):format(path, ft),
        3
      )
    end
    if type(list) ~= "table" then
      error(("[schema] %s.%s: expected list (table), got %s"):format(path, ft, type(list)), 3)
    end
    local item_path = path .. "." .. ft
    for i, v in ipairs(list) do
      if type(v) == "table" then
        assert_ast_node(item_path .. "[" .. i .. "]", v)
      elseif type(v) == "string" then
        if is_sentinel(v) then
          error(
            (
              "[schema] %s[%d]: Sentinel %q is forbidden. "
              .. 'Use FormatterNode: { kind = "formatter", strategy = "..." }'
            ):format(item_path, i, v),
            3
          )
        end
        -- plain string is valid
      else
        error(("[schema] %s[%d]: expected string or FormatterNode, got %s"):format(item_path, i, type(v)), 3)
      end
    end
  end
end

-- ── Public API ───────────────────────────────────────────────────────────────

--- Validate a raw capability table.
--- Returns the same table on success; throws a descriptive error on violation.
---@param name string
---@param cap  table
---@return table
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
    assert_ft_tool_map(p .. ".formatters", cap.formatters)
  end

  if cap.linters ~= nil then
    assert_ft_tool_map(p .. ".linters", cap.linters)
  end

  if cap.treesitter ~= nil then
    assert_list_of_strings(p .. ".treesitter", cap.treesitter)
  end

  if cap.mason ~= nil then
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

return M
