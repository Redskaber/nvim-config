-- ~/.config/nvim/lua/config/globals.lua
-- All vim.g.* runtime globals. Loaded by options.lua so the order is clear.
-- Keep this file ONLY for globals; vim.opt.* lives in config/options.lua.

-- Snacks.image checks for trash commands; if none found, healthcheck errors.
-- Default to "rm" (permanent delete) to avoid the error. Users with trash-cli
-- can override: vim.g.image_doc_trash_cmd = "trash"
vim.g.image_doc_trash_cmd = "rm"

-- NOTE: vim.g.lazyvim_file_explorer = "snacks" is set in
-- core/kernel/bootstrap.lua (Layer 0), NOT here. It must be set before
-- lazy.setup() reads it, and globals.lua loads inside lazy.setup().
-- See bootstrap.lua for the actual setting and rationale.

-- ── LazyVim feature flags ─────────────────────────────────────────────────
vim.g.autoformat = true
vim.g.snacks_animate = true
vim.g.lazyvim_picker = "auto" -- "telescope" | "fzf" | "auto"
vim.g.lazyvim_cmp = "auto" -- "nvim-cmp"  | "blink.cmp" | "auto"
vim.g.ai_cmp = true
vim.g.deprecation_warnings = false
vim.g.trouble_lualine = true

-- Root detection order: LSP → common project markers → cwd
vim.g.root_spec = { "lsp", { ".git", "lua", "Cargo.toml", "pyproject.toml" }, "cwd" }
vim.g.root_lsp_ignore = { "copilot" }

-- Markdown: don't let LazyVim fight our custom indent
vim.g.markdown_recommended_style = 0

-- ── LTOS runtime knobs ────────────────────────────────────────────────────────
-- vim.g.ltos_profile          = "full"     -- "full" | "minimal" | "nix"
-- vim.g.ltos_debug            = false      -- enable debug-level notify
-- vim.g.ltos_tool_overrides   = {}         -- per-tool { use_mason, pkg } overrides
-- vim.g.ltos_terminal_backend = "toggleterm"
-- vim.g.ltos_base_mason_tools = { "codespell" }
-- vim.g.ltos_base_parsers     = { "bash", "c", ... }
-- vim.g.ltos_disabled_plugins = { "gzip", "matchit", ... }

-- LTOS_DEBUG environment variable support
-- Set LTOS_DEBUG=trace,ir,cache,perf before launching nvim
local ltos_debug_env = vim.env.LTOS_DEBUG or ""
if ltos_debug_env ~= "" then
  local flags = {}
  for flag in ltos_debug_env:gmatch("[^,]+") do
    flags[flag:lower()] = true
  end
  vim.g.ltos_debug = flags["trace"] or flags["ir"] or flags["cache"] or flags["perf"]
  vim.g.ltos_debug_cache = flags["cache"]
  vim.g.ltos_debug_ir = flags["ir"]
  vim.g.ltos_debug_perf = flags["perf"]
  vim.g.ltos_debug_trace = flags["trace"]
end
