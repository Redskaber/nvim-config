-- ~/.config/nvim/lua/modules/lang/markup.lua
-- markup.lua is the single source of truth for all non-JS/TS
-- markup-adjacent filetypes: json, jsonc, yaml, toml, markdown, html,
-- css, scss.  typescript.lua no longer declares these.

return {
  treesitter = { "json", "jsonc", "yaml", "toml", "markdown", "markdown_inline", "html", "xml" },
  lsp = {
    jsonls = {},
    yamlls = {},
    taplo = {},
  },
  formatters = {
    toml = { "taplo" },
    markdown = { "prettierd" },
    html = { "prettierd" },
    css = { "prettierd" },
    scss = { "prettierd" },
    json = { "prettierd" },
    jsonc = { "prettierd" },
    yaml = { "prettierd" },
  },
  mason = { "taplo", "prettierd" },
}
