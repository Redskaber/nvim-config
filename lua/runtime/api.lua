-- ~/.config/nvim/lua/runtime/api.lua
-- App layer façade (TODO-9.1).
--
-- All config/, keymaps.lua, and plugin files import ONLY this module.
-- No direct requires of telescope/snacks/conform/etc from consumer code.

local M = {}

-- ── Lifecycle ──────────────────────────────────────────────────────────────────

--- Register a callback to run when LTOS reaches READY state.
--- Useful for plugins that need to execute logic after full initialization.
--- if already READY when called, execute immediately.
--- Previously, calling on_ready() after READY was reached would never fire
--- the callback (observer only fires on future transitions).
---@param fn function  Callback function to execute on READY
function M.on_ready(fn)
  local lifecycle = require("runtime.lifecycle")
  -- If already READY, execute immediately
  if lifecycle.is_ready() then
    pcall(fn)
    return
  end
  -- Otherwise, observe for future READY transition
  lifecycle.observe(function(state, _)
    if state == "READY" then
      pcall(fn)
    end
  end)
end

--- Register a callback to observe all lifecycle state transitions.
---@param fn fun(new_state: string, prev_state: string)
function M.on_lifecycle_change(fn)
  local lifecycle = require("runtime.lifecycle")
  lifecycle.observe(fn)
end
-- ── Format ────────────────────────────────────────────────────────────────────

---@param opts? table  conform.format() opts
function M.format(opts)
  local ok, conform = pcall(require, "conform")
  if ok then
    conform.format(vim.tbl_extend("force", { async = true, lsp_fallback = true }, opts or {}))
  else
    vim.lsp.buf.format(opts)
  end
end

-- ── Picker (pluggable backend) ────────────────────────────────────────────────

local _picker_backends = {}
local _default_picker = nil

--- Register a named picker backend.
--- backend = { files: fn, grep: fn, buffers: fn, recent: fn, help: fn, diagnostics?: fn }
---@param name    string
---@param backend table
function M.picker_register(name, backend)
  assert(type(name) == "string" and name ~= "", "backend name must be non-empty string")
  assert(type(backend) == "table", "backend must be a table")
  _picker_backends[name] = backend
end

--- Set the default picker backend name (used when vim.g.ltos_picker_backend is unset).
---@param name string
function M.picker_set_default(name) _default_picker = name end

local function bootstrap_picker_backends()
  if _picker_backends["snacks"] == nil then
    local ok, snacks = pcall(require, "snacks")
    if ok and snacks.picker then
      _picker_backends["snacks"] = snacks.picker
    end
  end
  if _picker_backends["telescope"] == nil then
    local ok, tel = pcall(require, "telescope.builtin")
    if ok then
      _picker_backends["telescope"] = tel
    end
  end
end

local function get_picker()
  bootstrap_picker_backends()
  local name = vim.g.ltos_picker_backend or _default_picker
  if name and _picker_backends[name] then
    return _picker_backends[name]
  end
  -- Auto-select first available registered backend
  if _picker_backends["snacks"] then
    return _picker_backends["snacks"]
  end
  if _picker_backends["telescope"] then
    return _picker_backends["telescope"]
  end
  return nil
end

local function pick(method, ...)
  local p = get_picker()
  if p and type(p[method]) == "function" then
    p[method](...)
  else
    vim.notify("[ltos:api] picker not available", vim.log.levels.WARN)
  end
end

function M.find_files(opts) pick("files", opts) end
function M.live_grep(opts) pick("grep", opts) end
function M.buffers(opts) pick("buffers", opts) end
function M.recent_files(opts) pick("recent", opts) end
function M.help_tags(opts) pick("help", opts) end

-- ── Diagnostics ───────────────────────────────────────────────────────────────

M.diagnostics = {
  next = function() vim.diagnostic.goto_next() end,
  prev = function() vim.diagnostic.goto_prev() end,
  open = function() vim.diagnostic.open_float() end,
  list = function()
    local p = get_picker()
    if p and type(p.diagnostics) == "function" then
      p.diagnostics()
    else
      vim.diagnostic.setloclist()
    end
  end,
}

-- ── LSP ───────────────────────────────────────────────────────────────────────

M.lsp = {
  rename = function() vim.lsp.buf.rename() end,
  code_action = function() vim.lsp.buf.code_action() end,
  hover = function() vim.lsp.buf.hover() end,
  signature = function() vim.lsp.buf.signature_help() end,
}

-- ── Terminal (pluggable backend) ──────────────────────────────────────────────

local _terminal_backends = {}
local _default_terminal = nil

--- Register a named terminal backend.
---@param name    string
---@param backend table
function M.terminal_register(name, backend)
  assert(type(name) == "string" and name ~= "", "backend name must be non-empty string")
  assert(type(backend) == "table", "backend must be a table")
  _terminal_backends[name] = backend
end

--- Set the default terminal backend name (used when vim.g.ltos_terminal_backend is unset).
---@param name string
function M.terminal_set_default(name) _default_terminal = name end

local function get_terminal()
  local name = vim.g.ltos_terminal_backend or _default_terminal or "toggleterm"
  local backend = _terminal_backends[name]
  if not backend then
    local ok, tt = pcall(require, "toggleterm.terminal")
    if ok then
      _terminal_backends["toggleterm"] = {
        float = function() tt.Terminal:new({ direction = "float" }):toggle() end,
        horizontal = function() tt.Terminal:new({ direction = "horizontal" }):toggle() end,
      }
      return _terminal_backends["toggleterm"]
    end
    vim.notify("[ltos:api] terminal backend not found: " .. name, vim.log.levels.WARN)
    return nil
  end
  return backend
end

M.terminal = {
  register = M.terminal_register,
  set_default = M.terminal_set_default,
  float = function()
    local b = get_terminal()
    if b and b.float then
      b.float()
    end
  end,
  horizontal = function()
    local b = get_terminal()
    if b and b.horizontal then
      b.horizontal()
    end
  end,
}

M.picker = {
  register = M.picker_register,
  set_default = M.picker_set_default,
}

-- ── UI helpers ────────────────────────────────────────────────────────────────

M.ui = {
  zen = function()
    local ok, snacks = pcall(require, "snacks")
    if ok then
      snacks.zen()
    end
  end,
  zoom = function()
    local ok, snacks = pcall(require, "snacks")
    if ok then
      snacks.zen.zoom()
    end
  end,
}

return M