-- ~/.config/nvim/lua/plugins/ui/snacks.lua

return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.win = opts.win or {}
      opts.win.scroll_down = "<C-j>"
      opts.win.scroll_up = "<C-k>"
      return opts
    end,
    keys = {
      { "<C-j>", desc = "Snacks: Scroll down" },
      { "<C-k>", desc = "Snacks: Scroll up" },
    },
  },
}
