-- lua/modules/editor/image.lua
-- P3: Editor image capability DSL module.
-- Adheres to DSL purity constraints (Invariant 8 extended).

return {
  cap_type = "image",
  version = 1,
  -- Placeholder fields based on AUDIT.md
  plugins = {
    { name = "some-editor-image-plugin", opts = {} },
  },
  backends = { "kitty", "sixel" },
  backend = "kitty",
  filetypes = { "drawio", "plantuml" },
  provides = { "image_preview" },
}
