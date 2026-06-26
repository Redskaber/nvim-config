-- ~/.config/nvim/lua/plugins/syntax/markdown-render.lua
-- In-buffer Markdown rendering (headings, code blocks, tables as ASCII).
-- Layer: syntax (visual rendering of structured markup).
-- Browser preview lives in plugins/lang/markup.lua (markdown-preview.nvim).
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    optional = true,
    opts = {
      file_types = { "markdown", "Avante" },
    },
    ft = { "markdown", "Avante" },
  },
}
