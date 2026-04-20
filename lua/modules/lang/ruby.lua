-- ~/.config/nvim/lua/modules/lang/ruby.lua
-- Ruby toolchain: solargraph (LSP), rubocop (lint+format)

return {
  version = 1,
  treesitter = { "ruby" },

  lsp = {
    solargraph = {
      cmd = { "solargraph", "stdio" },
      settings = {
        solargraph = {
          diagnostics = true,
          formatting = false, -- delegate to rubocop
        },
      },
    },
  },

  formatters = {
    ruby = { "rubocop" }, -- rubocop -A / -x
  },

  linters = {
    ruby = { "rubocop" },
  },

  -- 通常通过 gem 安装；若你希望 mason 兜底，可加 "solargraph"
  mason = {},
}
