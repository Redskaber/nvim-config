-- ~/.config/nvim/lua/runtime/api.lua
-- App layer façade (TODO-9.1).
--
-- All config/, keymaps.lua, and plugin files import ONLY this module.
-- No direct requires of telescope/snacks/conform/etc from consumer code.
--
-- API namespaces:
--   M.format          — buffer formatting
--   M.find_files      — picker: files
--   M.live_grep       — picker: grep
--   M.buffers         — picker: buffers
--   M.recent_files    — picker: recent
--   M.help_tags       — picker: help
--   M.diagnostics     — diagnostic navigation
--   M.lsp             — LSP actions
--   M.terminal        — pluggable terminal backend
--   M.ui              — UI helpers

local M = {}

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

-- ── Picker (snacks.picker preferred, telescope fallback) ──────────────────────

local function picker()
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.picker then
    return snacks.picker
  end
  local ok2, tel = pcall(require, "telescope.builtin")
  if ok2 then
    return tel
  end
  return nil
end

local function pick(method, ...)
  local p = picker()
  if p and type(p[method]) == "function" then
    p[method](...)
  else
    vim.notify("[ltos:api] picker not available", vim.log.levels.WARN)
  end
end

function M.find_files(opts)
  pick("files", opts)
end
function M.live_grep(opts)
  pick("grep", opts)
end
function M.buffers(opts)
  pick("buffers", opts)
end
function M.recent_files(opts)
  pick("recent", opts)
end
function M.help_tags(opts)
  pick("help", opts)
end

-- ── Diagnostics ───────────────────────────────────────────────────────────────

M.diagnostics = {
  next = function()
    vim.diagnostic.goto_next()
  end,
  prev = function()
    vim.diagnostic.goto_prev()
  end,
  open = function()
    vim.diagnostic.open_float()
  end,
  list = function()
    local ok, snacks = pcall(require, "snacks")
    if ok and snacks.picker then
      snacks.picker.diagnostics()
    else
      vim.diagnostic.setloclist()
    end
  end,
}

-- ── LSP ───────────────────────────────────────────────────────────────────────

M.lsp = {
  rename = function()
    vim.lsp.buf.rename()
  end,
  code_action = function()
    vim.lsp.buf.code_action()
  end,
  hover = function()
    vim.lsp.buf.hover()
  end,
  signature = function()
    vim.lsp.buf.signature_help()
  end,
}

-- ── Terminal (pluggable backend) ──────────────────────────────────────────────

local _terminal_backends = {}

--- Register a named terminal backend.
--- backend = { float: fn, horizontal: fn, vertical?: fn }
---@param name    string
---@param backend table
function M.terminal_register(name, backend)
  assert(type(name) == "string" and name ~= "", "backend name must be non-empty string")
  assert(type(backend) == "table", "backend must be a table")
  _terminal_backends[name] = backend
end

local function get_terminal()
  local name = vim.g.ltos_terminal_backend or "toggleterm"
  local backend = _terminal_backends[name]
  if not backend then
    -- Auto-register toggleterm if available
    local ok, tt = pcall(require, "toggleterm.terminal")
    if ok then
      _terminal_backends["toggleterm"] = {
        float = function()
          tt.Terminal:new({ direction = "float" }):toggle()
        end,
        horizontal = function()
          tt.Terminal:new({ direction = "horizontal" }):toggle()
        end,
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
