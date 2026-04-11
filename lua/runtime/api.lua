-- ~/.config/nvim/lua/runtime/api.lua
-- Unified runtime API façade. config/keymaps.lua imports THIS only.
-- Never import individual plugins from outside this module.
--
-- terminal backend is resolved via vim.g.ltos_terminal_backend
-- (defaults to "toggleterm").  Swapping the terminal plugin only requires
-- registering a new backend handler — no changes to this file.

local M = {}

-- ── Picker façade ────────────────────────────────────────────────────────────
local function picker(name, opts)
  return function()
    local ok, err = pcall(function()
      if _G.Snacks and Snacks.picker and Snacks.picker[name] then
        Snacks.picker[name](opts)
      else
        error("picker not available: " .. name)
      end
    end)
    if not ok then
      vim.notify("[runtime.api] picker failed: " .. tostring(err), vim.log.levels.WARN)
    end
  end
end

M.find_files = picker("files")
M.live_grep = picker("grep")
M.buffers = picker("buffers")
M.recent_files = picker("recent")
M.help_tags = picker("help")

-- ── LSP façade ───────────────────────────────────────────────────────────────
M.lsp = {
  definition = function()
    vim.lsp.buf.definition()
  end,
  references = function()
    vim.lsp.buf.references()
  end,
  implementation = function()
    vim.lsp.buf.implementation()
  end,
  type_definition = function()
    vim.lsp.buf.type_definition()
  end,
  rename = function()
    vim.lsp.buf.rename()
  end,
  code_action = function()
    vim.lsp.buf.code_action()
  end,
  hover = function()
    vim.lsp.buf.hover()
  end,
  signature_help = function()
    vim.lsp.buf.signature_help()
  end,
}

-- ── Diagnostics façade ───────────────────────────────────────────────────────
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
    if _G.Snacks and Snacks.picker then
      Snacks.picker.diagnostics()
    else
      vim.diagnostic.setloclist()
    end
  end,
}

-- ── Git façade ───────────────────────────────────────────────────────────────
M.git = {
  status = picker("git_status"),
  log = picker("git_log"),
  diff = picker("git_diff"),
}

-- ── Format façade ────────────────────────────────────────────────────────────
M.format = function(opts)
  local ok, conform = pcall(require, "conform")
  if ok then
    conform.format(vim.tbl_extend("force", { async = true, lsp_format = "fallback" }, opts or {}))
  else
    vim.lsp.buf.format(opts)
  end
end

-- ── Terminal façade ──────────────────────────────────────────────────────────
-- backend is pluggable.  Register a custom backend by setting
--   vim.g.ltos_terminal_backend = "my_backend"
-- and calling:
--   require("runtime.api").terminal.register("my_backend", { float = fn, horizontal = fn })
--
-- Built-in backends: "toggleterm" (default), "native".

local _terminal_backends = {
  toggleterm = {
    float = function()
      local ok, tt = pcall(require, "toggleterm")
      if ok then
        tt.toggle(nil, "float")
      else
        vim.cmd("terminal")
      end
    end,
    horizontal = function()
      local ok, tt = pcall(require, "toggleterm")
      if ok then
        tt.toggle(nil, "horizontal")
      else
        vim.cmd("split | terminal")
      end
    end,
  },
  native = {
    float = function()
      vim.cmd("terminal")
    end,
    horizontal = function()
      vim.cmd("split | terminal")
    end,
  },
}

--- Register a custom terminal backend.
---@param name string
---@param backend { float: function, horizontal: function }
local function register_terminal_backend(name, backend)
  _terminal_backends[name] = backend
end

local function _terminal_dispatch(direction)
  local backend_name = vim.g.ltos_terminal_backend or "toggleterm"
  local backend = _terminal_backends[backend_name]
  if not backend then
    vim.notify(
      "[runtime.api] unknown terminal backend: " .. backend_name .. " — falling back to native",
      vim.log.levels.WARN
    )
    backend = _terminal_backends.native
  end
  local fn = backend[direction]
  if fn then
    local ok, err = pcall(fn)
    if not ok then
      vim.notify("[runtime.api] terminal." .. direction .. " failed: " .. tostring(err), vim.log.levels.WARN)
      vim.cmd("terminal")
    end
  end
end

M.terminal = {
  float = function()
    _terminal_dispatch("float")
  end,
  horizontal = function()
    _terminal_dispatch("horizontal")
  end,
  register = register_terminal_backend,
}

return M
