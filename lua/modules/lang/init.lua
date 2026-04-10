-- ~/.config/nvim/lua/lang/init.lua
-- Language registry aggregator.
-- Each lang/*.lua module returns a spec table that lazy.nvim imports.
-- This file re-exports everything so `{ import = "lang" }` in lazy.lua
-- picks up all language modules automatically.
--
-- Structure of each lang module:
--   return {
--     treesitter  = { "parser1", "parser2" },        -- ensure_installed
--     mason       = { "tool1", "tool2" },             -- ensure_installed
--     lsp         = { server_name = { settings = {} } },
--     formatters  = { ft = { "formatter" } },
--     linters     = { ft = { "linter" } },
--   }
--
-- The aggregator is NOT needed at runtime; each lang/*.lua returns its
-- own lazy spec directly so LazyVim's import mechanism handles loading.

return {}
