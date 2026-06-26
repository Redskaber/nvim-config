-- ~/.config/nvim/lua/plugins/git/neogit.lua
-- Neogit (Magit-style git UI) + diffview (diff browser).
-- Layer: git (version control integration — UI layer).
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
