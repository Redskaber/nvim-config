-- lua/modules/cap/image.lua
-- P3: Image capability DSL module.
-- Adheres to DSL purity constraints (Invariant 8 extended).

return {
  cap_type = "image",
  version = 1,
  -- Placeholder fields based on AUDIT.md
  backend = "kitty", -- e.g., "kitty", "chafa", "sixel", "ueberzug"
  fallback = nil, -- e.g., "chafa"
  filetypes = { "png", "jpg", "jpeg", "gif", "webp" },
  max_width = 80,
  max_height = 30,
  integrations = {
    markdown = true,
  },
  mason = {},
  plugins = {},
}

