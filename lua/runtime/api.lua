-- ~/.config/nvim/lua/runtime/api.lua
-- Unified runtime façade (P0-4).
--
-- API boundary: format / find_files / live_grep / buffers / recent_files /
--               help_tags / diagnostics / lsp / ui / terminal
--
-- Rules:
--   • config/ and keymaps.lua import ONLY this module — never telescope/snacks directly.
--   • The terminal backend is pluggable: register via M.terminal.register().
--   • Plugin modules (telescope, conform, snacks…) are lazy-required at call time.

local M = {}

-- ── Format ───────────────────────────────────────────────────────────────────

function M.format(opts)
  local ok, conform = pcall(require, "conform")
  if ok then
    conform.format(vim.tbl_extend("force", { async = true, lsp_fallback = true }, opts or {}))
  else
    vim.lsp.buf.format(opts)
  end
end

-- ── Find / search ─────────────────────────────────────────────────────────────

local function picker()
  -- prefer snacks.picker if available, else telescope
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

-- ── Terminal (pluggable backend) ──────────────────────────────────────────────

local _terminal_backends = {}

--- Register a named terminal backend.
--- backend = { float = fn, horizontal = fn, vertical? = fn }
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
    -- Auto-register toggleterm if loaded
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

-- ── LSP helpers ───────────────────────────────────────────────────────────────

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
}

return M
