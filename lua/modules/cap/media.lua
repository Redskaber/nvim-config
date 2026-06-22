-- lua/modules/cap/media.lua
-- P3: Media capability DSL module.
-- Adheres to DSL purity constraints (Invariant 8 extended).

return {
  cap_type = "media",
  version = 1,
  -- Placeholder fields based on AUDIT.md
  viewers = {
    -- FIX-DEPLOY-1 (2026-06-23): replaced fake "nvim-image.lua" with real
    -- "3rd/image.nvim" (the canonical neovim image plugin).
    { kind = "image", plugin = "3rd/image.nvim", filetypes = { "png", "jpg" } },
    -- FIX-DEPLOY-1: removed fake "some-video-plugin" — no quality neovim video
    -- plugin exists. Users who need video support can add their own cap module.
  },
  mason = {},
}