-- ~/.config/nvim/lua/plugins/lang/markup.lua
-- Markdown / markup language editing enhancements.
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter (runtime/adapters/) owns: LSP (jsonls/yamlls/taplo),
--     formatter (prettierd), linters, mason packages, treesitter
--     (markdown/markdown_inline/json/yaml/toml/html/xml).
--   • This file owns: Markdown live preview (markdown-preview.nvim).
--
-- markdown-preview.nvim: launches a browser-based live preview that
-- updates as you edit the Markdown buffer. Complements the in-editor
-- rendering already provided by render-markdown.nvim (in coding.lua):
--   • render-markdown.nvim — inline buffer rendering (headings, code
--     blocks, tables as ASCII art)
--   • markdown-preview.nvim — browser rendering (full CSS, math, mermaid)
--
-- Usage: :MarkdownPreview / :MarkdownPreviewStop / :MarkdownPreviewToggle
-- Auto-opens on entering a markdown buffer (configurable via opts).
return {
  {
    "iamcco/markdown-preview.nvim",
    ft = "markdown",
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    build = function()
      -- Build the preview server (uses yarn/npm if available, falls back
      -- to the bundled binary). pcall prevents failure on systems without
      -- node toolchain — the plugin will then use a slower fallback.
      vim.fn["mkdp#util#install"]()
    end,
    init = function()
      vim.g.mkdp_auto_start = 0       -- don't auto-open on every .md file
      vim.g.mkdp_auto_close = 1       -- close preview when leaving buffer
      vim.g.mkdp_refresh_slow = 0     -- refresh on write, not on every keystroke
      vim.g.mkdp_browser = ""         -- use system default browser
      vim.g.mkdp_echo_preview_url = 1 -- echo URL for remote/headless access
    end,
    keys = {
      { "<leader>cp", "<cmd>MarkdownPreviewToggle<cr>", desc = "Markdown preview toggle" },
    },
  },
}
