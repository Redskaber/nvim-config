-- ~/.config/nvim/lua/modules/lang/markup.lua
-- markup.lua is the single source of truth for all non-JS/TS
-- markup-adjacent filetypes: json, jsonc, yaml, toml, markdown, html,
-- css, scss.  typescript.lua no longer declares these.

return {
  version = 1,
  treesitter = { "json", "jsonc", "yaml", "toml", "markdown", "markdown_inline", "html", "xml" },
  lsp = {
    marksman = {},
    jsonls = {},
    yamlls = {},
    taplo = {},
  },
  formatters = {
    markdown = { "markdownlint" },
    html = { "prettierd" },
    css = { "prettierd" },
    scss = { "prettierd" },
    json = { "prettierd" },
    jsonc = { "prettierd" },
    yaml = { "prettierd" },
    toml = { "taplo" },
  },
  linters = {
    markdown = { "markdownlint" },
  },
  mason = { "prettierd" },
}
