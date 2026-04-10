-- ~/.config/nvim/lua/config/keymaps.lua
-- Editor-level keymaps. Plugin-aware calls go via runtime.api.
-- No direct requires of telescope/snacks/conform from here.

local map = vim.keymap.set

-- ── Better movement ───────────────────────────────────────────────────────
map({ "n", "x" }, "j", "gj", { silent = true, desc = "Down (visual line)" })
map({ "n", "x" }, "k", "gk", { silent = true, desc = "Up   (visual line)" })

-- ── Window navigation ─────────────────────────────────────────────────────
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- ── Resize ────────────────────────────────────────────────────────────────
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase width" })

-- ── Buffer navigation ─────────────────────────────────────────────────────
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- ── Save / quit ───────────────────────────────────────────────────────────
map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit all" })

-- ── Format (via façade) ───────────────────────────────────────────────────
map({ "n", "v" }, "<leader>cf", function()
  require("runtime.api").format()
end, { desc = "Format buffer" })

-- ── Find (via façade) ─────────────────────────────────────────────────────
map("n", "<leader>ff", function()
  require("runtime.api").find_files()
end, { desc = "Find files" })
map("n", "<leader>fg", function()
  require("runtime.api").live_grep()
end, { desc = "Live grep" })
map("n", "<leader>fb", function()
  require("runtime.api").buffers()
end, { desc = "Buffers" })
map("n", "<leader>fr", function()
  require("runtime.api").recent_files()
end, { desc = "Recent files" })
map("n", "<leader>sh", function()
  require("runtime.api").help_tags()
end, { desc = "Help tags" })

-- ── Diagnostics (via façade) ──────────────────────────────────────────────
map("n", "]d", function()
  require("runtime.api").diagnostics.next()
end, { desc = "Next diagnostic" })
map("n", "[d", function()
  require("runtime.api").diagnostics.prev()
end, { desc = "Prev diagnostic" })
map("n", "<leader>cd", function()
  require("runtime.api").diagnostics.open()
end, { desc = "Diagnostic float" })
map("n", "<leader>xd", function()
  require("runtime.api").diagnostics.list()
end, { desc = "Diagnostics list" })

-- ── Search ────────────────────────────────────────────────────────────────
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear highlight" })

-- ── Indenting keeps selection ─────────────────────────────────────────────
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- ── Move lines ────────────────────────────────────────────────────────────
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move line down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move line up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move lines down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move lines up" })

-- ── Better paste ──────────────────────────────────────────────────────────
map("x", "p", [["_dP]], { desc = "Paste without yanking" })
