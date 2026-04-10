-- ~/.config/nvim/lua/core/schema.lua
-- Capability schema definition and fail-fast validation (P0-3).
-- Adapters receive validated AST; weak-typed tables never pass this gate.

local M = {}

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

local function assert_string_map_of_string_lists(path, value)
  assert_type(path, value, "table")
  for ft, list in pairs(value) do
    if type(ft) ~= "string" then
      error(("[schema] %s key: expected string, got %s"):format(path, type(ft)), 3)
    end
    -- allow function sentinel for dynamic formatters
    if type(list) ~= "function" then
      assert_list_of_strings(path .. "." .. ft, list)
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
    assert_list_of_strings(p .. ".mason", cap.mason)
  end

  return cap
end

return M
