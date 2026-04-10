-- ~/.config/nvim/lua/runtime/api.lua
-- Unified runtime API façade. config/keymaps.lua imports THIS only.
-- Never import individual plugins from outside this module.

local M = {}

-- ── Picker façade ────────────────────────────────────────────────────────────
local function picker(name, opts)
  return function()
    if _G.Snacks and Snacks.picker and Snacks.picker[name] then
      Snacks.picker[name](opts)
    else
      vim.notify("[runtime.api] picker not ready: " .. name, vim.log.levels.WARN)
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

return M
