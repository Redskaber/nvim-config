-- ~/.config/nvim/lua/config/options.lua
-- Loads globals first, then sets all vim.opt.* values.
-- Rule: one setting per line; group by concern; no vim.g.* here.

require("config.globals")

local env = require("core.kernel.env")
local opt = vim.opt

-- ── File & persistence ───────────────────────────────────────────────────
opt.autowrite = true
opt.confirm = true
opt.undofile = true
opt.undolevels = 10000
opt.updatetime = 200

-- ── Clipboard ───────────────────────────────────────────────────────────
-- Disable system clipboard over SSH to avoid OSC52 conflicts
opt.clipboard = env.is_ssh and "" or "unnamedplus"

-- ── Input ────────────────────────────────────────────────────────────────
opt.mouse = "a"
opt.timeoutlen = env.is_vscode and 1000 or 300

-- ── Indentation ──────────────────────────────────────────────────────────
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.shiftround = true
opt.smartindent = true

-- ── Search ───────────────────────────────────────────────────────────────
opt.ignorecase = true
opt.smartcase = true
opt.grepprg = "rg --vimgrep"
opt.grepformat = "%f:%l:%c:%m"

-- ── Lines & cursor ───────────────────────────────────────────────────────
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.scrolloff = 4
opt.sidescrolloff = 8

-- ── Display ──────────────────────────────────────────────────────────────
opt.termguicolors = true
opt.laststatus = 3
opt.showmode = false
opt.ruler = false
opt.linebreak = true
opt.wrap = false
opt.list = true
opt.conceallevel = 2
opt.winblend = 15
opt.pumblend = 10
opt.pumheight = 10
opt.signcolumn = "yes"

opt.fillchars = {
  foldopen = "",
  foldclose = "",
  fold = " ",
  foldsep = " ",
  diff = "╱",
  eob = " ",
}
opt.statuscolumn = [[%!v:lua.LazyVim.statuscolumn()]]

-- ── Windows & splits ─────────────────────────────────────────────────────
opt.splitbelow = true
opt.splitright = true
opt.splitkeep = "screen"
opt.winminwidth = 5

-- ── Completion & cmdline ─────────────────────────────────────────────────
opt.completeopt = "menu,menuone,noselect"
opt.wildmode = "longest:full,full"
opt.inccommand = "nosplit"

-- ── Folding ──────────────────────────────────────────────────────────────
-- FIX P0-6: unified fold strategy → treesitter expr when available, else indent
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99
opt.foldtext = ""

-- ── Formatting ───────────────────────────────────────────────────────────
opt.formatexpr = "v:lua.LazyVim.format.formatexpr()"
opt.formatoptions = "jcroqlnt"

-- ── Session & navigation ─────────────────────────────────────────────────
opt.sessionoptions = {
  "buffers",
  "curdir",
  "tabpages",
  "winsize",
  "help",
  "globals",
  "skiprtp",
  "folds",
}
opt.jumpoptions = "view"

-- ── Misc ─────────────────────────────────────────────────────────────────
opt.virtualedit = "block"
opt.spelllang = { "en" }
opt.smoothscroll = true