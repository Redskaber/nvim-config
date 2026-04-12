-- lua/plugins/git.lua
-- Git UI plugins: Neogit (Magit-style) + diffview.

return {
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "folke/snacks.nvim",
    },
    cmd = "Neogit",
    keys = {
      { "<leader>ngg", "<cmd>Neogit<cr>", desc = "Neogit UI" },
      { "<leader>ngc", "<cmd>Neogit commit<cr>", desc = "Commit" },
      { "<leader>ngp", "<cmd>Neogit push<cr>", desc = "Push" },
      { "<leader>ngl", "<cmd>Neogit pull<cr>", desc = "Pull" },
    },
    opts = {
      integrations = { diffview = true },
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
    opts = {},
  },
}
