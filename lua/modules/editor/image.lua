-- lua/modules/editor/image.lua
-- P3: Editor image capability DSL module.
-- Adheres to DSL purity constraints (Invariant 8 extended).

return {
  cap_type = "image",
  version = 1,
  -- Placeholder fields based on AUDIT.md
  -- removed fake "some-editor-image-plugin".
  -- The image adapter (runtime/adapters/image.lua) automatically outputs
  -- 3rd/image.nvim as the default image plugin when no explicit plugins
  -- are declared. This cap module only configures editor-specific image
  -- behavior (drawio/plantuml filetypes, kitty/sixel backends).
  plugins = {},
  backends = { "kitty", "sixel" },
  backend = "kitty",
  filetypes = { "drawio", "plantuml" },
  provides = { "image_preview" },
}