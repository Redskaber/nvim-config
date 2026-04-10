-- ~/.config/nvim/lua/plugins/ai.lua
-- AI coding assistant: codecompanion.nvim

return {
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    cmd = {
      "CodeCompanion",
      "CodeCompanionChat",
      "CodeCompanionActions",
    },
    keys = {
      { "<leader>ai", "<cmd>CodeCompanionChat Toggle<cr>", desc = "AI: toggle chat" },
      { "<leader>aa", "<cmd>CodeCompanionActions<cr>",     desc = "AI: actions",    mode = { "n", "v" } },
      { "<leader>ac", "<cmd>CodeCompanion<cr>",            desc = "AI: inline",     mode = { "n", "v" } },
    },
    opts = {
      opts = {
        log_level = "ERROR", -- set to "DEBUG" or "TRACE" when debugging
      },
    },
  },
}
