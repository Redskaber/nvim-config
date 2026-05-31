-- lua/modules/ai/copilot.lua
-- P3: Copilot AI capability DSL module.
-- Adheres to DSL purity constraints (Invariant 8 extended).

return {
  cap_type = "ai",
  version = 1,
  -- Placeholder fields based on AUDIT.md
  provides = { "completion", "chat" },
  providers = { "copilot" },
  plugins = {
    { name = "github/copilot.vim", cmd = { "Copilot" } },
  },
}
