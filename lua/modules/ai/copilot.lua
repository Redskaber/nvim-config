-- lua/modules/ai/copilot.lua
-- P6-C5: Authoritative AI capability declaration.
-- plugins/ai/ai.lua is now a thin placeholder — this module is the single
-- source of truth for copilot + codecompanion plugin specs.
-- Adheres to DSL purity constraints (Invariant 8 extended).

return {
  cap_type = "ai",
  version = 1,
  provides = { "completion", "chat" },
  completion = {
    provider = "copilot",
  },

  chat = {
    provider = "codecompanion",
    adapter = "anthropic",
  },

  -- Plugin declarations consumed by runtime/adapters/ai_cap.lua → LazySpec[]
  plugins = {
    {
      name = "github/copilot.vim",
      cmd = { "Copilot" },
    },
    {
      name = "olimorris/codecompanion.nvim",
      cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
      keys = {
        {
          lhs = "<leader>ai",
          rhs = "<cmd>CodeCompanionChat Toggle<cr>",
          mode = "n",
          desc = "AI: toggle chat",
        },
        {
          lhs = "<leader>aa",
          rhs = "<cmd>CodeCompanionActions<cr>",
          mode = { "n", "v" },
          desc = "AI: actions",
        },
        {
          lhs = "<leader>ac",
          rhs = "<cmd>CodeCompanion<cr>",
          mode = { "n", "v" },
          desc = "AI: inline",
        },
      },
      opts = {
        log_level = "ERROR",
      },
    },
  },
}
