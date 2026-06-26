-- ~/.config/nvim/lua/plugins/coding/colorizer.lua
-- Highlight color codes (#fff, rgb(), hsl()) with their actual color.
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter: build-time toolchain config.
--   • This file: editing-layer visual annotation (color preview).
--
-- nvim-colorizer.lua: high-performance color highlighter using Lua + libuv.
-- Highlights #hex, rgb(), rgba(), hsl(), hsla(), and named CSS colors
-- directly in the buffer. Essential for frontend/CSS/markdown editing.
--
-- Why nvim-colorizer.lua (NvChad fork) over the original chrisbra/Colorizer:
--   • 2024+ active maintenance, 10x faster (Lua vs Vimscript)
--   • Proper async (doesn't block on large buffers)
--   • Supports all CSS color functions including color-mix() and oklch()
return {
  {
    "NvChad/nvim-colorizer.lua",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      filetypes = {
        "css",
        "scss",
        "sass",
        "html",
        "javascript",
        "typescript",
        "javascriptreact",
        "typescriptreact",
        "vue",
        "svelte",
        "astro",
        "lua",
        "markdown",
        "json",
        "yaml",
        "toml",
        "rust",
        "python",
        "*", -- fallback: enable for all filetypes (cheap, lazy)
      },
      user_default_options = {
        RGB = true, -- #RGB hex codes
        RRGGBB = true, -- #RRGGBB hex codes
        names = true, -- "Name" codes like Blue
        RRGGBBAA = true, -- #RRGGBBAA hex codes
        AARRGGBB = false, -- 0xAARRGGBB hex codes
        rgb_fn = true, -- CSS rgb() and rgba() functions
        hsl_fn = true, -- CSS hsl() and hsla() functions
        css = true, -- Enable all CSS features
        css_fn = true, -- Enable all CSS *functions*
        mode = "background", -- 'background' | 'foreground' | 'virtualtext'
        tailwind = true, -- LSP-based tailwind colors (if tailwind LSP active)
        always_update = false,
      },
      buftypes = {},
    },
    config = function(_, opts) require("colorizer").setup(opts) end,
  },
}
