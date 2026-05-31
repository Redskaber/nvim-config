-- lua/modules/cap/media.lua
-- P3: Media capability DSL module.
-- Adheres to DSL purity constraints (Invariant 8 extended).

return {
  cap_type = "media",
  version = 1,
  -- Placeholder fields based on AUDIT.md
  viewers = {
    { kind = "image", plugin = "nvim-image.lua", filetypes = { "png", "jpg" } },
    { kind = "video", plugin = "some-video-plugin", filetypes = { "mp4", "mkv" } },
  },
  mason = {},
}
