-- ~/.config/nvim/lua/modules/lang/markup.lua
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
  },
  mason = { "taplo", "json-lsp", "yaml-language-server", "prettierd" },
}
