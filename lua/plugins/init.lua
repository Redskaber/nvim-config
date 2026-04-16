-- lua/plugins/init.lua
-- Layer 5 · app — plugin registry aggregator.
--
-- Single entry point for lazy.nvim's { import = "plugins" }.
-- lazy.nvim's lsmod() picks up this init.lua automatically when scanning
-- the plugins/ directory.
--
-- Each sub-module returns a LazySpec[]; this file merges them into one flat
-- list. Zero toolchain knowledge. Zero side-effects.
--
-- Sub-directory layout (by concern):
--   ai/          AI assistants
--   coding/      Editing utilities (pairs, comments, snippets, DAP, text-objects)
--   editor/      Editor UX (flash, which-key, gitsigns, trouble, multi-cursor)
--   formatting/  conform.nvim placeholder  (opts injected by LTOS adapter)
--   linting/     nvim-lint placeholder     (opts injected by LTOS adapter)
--   lsp/         nvim-lspconfig + mason    (servers injected by LTOS adapter)
--   sys/         System integrations (git UI, terminal, file tree)
--   theme/       Colorscheme
--   treesitter/  Treesitter placeholder    (parsers injected by LTOS adapter)
--   ui/          UI chrome (bufferline, lualine, noice, snacks, mini.icons)

-- Ordered sub-module list — determines spec merge order for lazy.nvim.
local SUB_MODULES = {
  "plugins.ai.ai",
  "plugins.coding.coding",
  "plugins.coding.comments",
  "plugins.coding.pairs",
  "plugins.coding.snip",
  "plugins.editor.editor",
  "plugins.editor.cursor",
  "plugins.formatting.formatting",
  "plugins.linting.linting",
  "plugins.lsp.lsp",
  "plugins.treesitter.treesitter",
  "plugins.sys.git",
  "plugins.sys.img",
  "plugins.sys.terminal",
  "plugins.theme.theme",
  "plugins.ui.ui",
  "plugins.ui.snacks",
}

local specs = {}

for _, modname in ipairs(SUB_MODULES) do
  local ok, result = pcall(require, modname)
  if not ok then
    -- Surface load errors without crashing the whole startup
    vim.notify("[plugins.init] failed to load " .. modname .. ":\n" .. tostring(result), vim.log.levels.ERROR)
  elseif type(result) == "table" then
    -- Each module returns either a single spec or a list of specs
    if #result > 0 and type(result[1]) == "table" then
      -- List of specs: flatten into specs
      for _, spec in ipairs(result) do
        specs[#specs + 1] = spec
      end
    else
      -- Single spec table
      specs[#specs + 1] = result
    end
  end
end

return specs
