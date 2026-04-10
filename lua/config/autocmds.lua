-- ~/.config/nvim/lua/config/autocmds.lua
-- Custom autocmds only. LazyVim's own autocmds are prefixed "lazyvim_".
-- To remove a LazyVim autocmd: vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- ── Highlight on yank ────────────────────────────────────────────────────
augroup("YankHighlight", { clear = true })
autocmd("TextYankPost", {
  group = "YankHighlight",
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- ── Restore cursor position ──────────────────────────────────────────────
augroup("RestoreCursor", { clear = true })
autocmd("BufReadPost", {
  group = "RestoreCursor",
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local nlines = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= nlines then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- ── Auto-create missing parent directories on save ───────────────────────
augroup("AutoMkdir", { clear = true })
autocmd("BufWritePre", {
  group = "AutoMkdir",
  callback = function(ev)
    if ev.match:match("^%w%w+://") then
      return
    end
    local dir = vim.fn.fnamemodify(ev.match, ":p:h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end
  end,
})

-- ── Close some filetypes with <q> ────────────────────────────────────────
augroup("CloseWithQ", { clear = true })
autocmd("FileType", {
  group = "CloseWithQ",
  pattern = {
    "help",
    "man",
    "lspinfo",
    "notify",
    "qf",
    "startuptime",
    "checkhealth",
  },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})

-- ── Equalise splits when Neovim is resized ───────────────────────────────
augroup("ResizeEqualise", { clear = true })
autocmd("VimResized", {
  group = "ResizeEqualise",
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})
