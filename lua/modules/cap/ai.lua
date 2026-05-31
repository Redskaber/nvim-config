-- lua/modules/cap/ai.lua
-- P3: AI capability DSL module.
-- Adheres to DSL purity constraints (Invariant 8 extended).

return {
  cap_type = "ai",
  version = 1,
  -- Placeholder fields based on AUDIT.md
  completion = {
    provider = "copilot", -- e.g., "copilot", "codeium", "codecompanion", "avante"
  },
  chat = {
    provider = "copilot",
    adapter = "some-chat-adapter",
  },
  plugins = {
    { name = "github/copilot.vim" },
  },
}
