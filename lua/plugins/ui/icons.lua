-- ~/.config/nvim/lua/plugins/ui/icons.lua
-- Icon providers: mini.icons + nui.nvim + plenary.nvim (shared deps).
-- Layer: ui (interface — icon/rendering utilities).
return {
  {
    "nvim-mini/mini.icons",
    lazy = true,
    opts = {
      file = {
        [".keep"] = { glyph = "󰊢 ", hl = "MiniIconsGrey" },
        [".envrc"] = { glyph = " ", hl = "MiniIconsYellow" },
        ["devcontainer.json"] = { glyph = "", hl = "MiniIconsAzure" },
      },
      filetype = {
        dotenv = { glyph = " ", hl = "MiniIconsYellow" },
      },
      extension = {
        img = { glyph = " ", hl = "MiniIconsGrey" },
        iso = { glyph = " ", hl = "MiniIconsGrey" },
        lock = { glyph = "", hl = "MiniIconsGrey" },
      },
    },
  },

  { "MunifTanjim/nui.nvim" },

  { "nvim-lua/plenary.nvim", lazy = true },
}