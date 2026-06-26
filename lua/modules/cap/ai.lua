-- lua/modules/cap/ai.lua
-- P3: AI capability DSL module.
-- Adheres to DSL purity constraints (Invariant 8 extended).

return {
  cap_type = "ai",
  version = 1,
  -- This module is a MINIMAL AI capability marker.
  -- The authoritative AI plugin declarations live in modules/ai/copilot.lua
  -- (P6-C5 single source of truth). Previously this module duplicated
  -- copilot.vim, causing lazy.nvim spec conflicts. plugins field is now empty.
  -- Also removed fake "some-chat-adapter" string.
  completion = {
    provider = "copilot",
  },
  chat = {
    provider = "copilot",
  },
  plugins = {},
}