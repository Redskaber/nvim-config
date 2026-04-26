-- ~/.config/nvim/lua/plugins/linting.lua
-- author: redskaber
-- datetime: 2025-12-12

return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      -- Event to trigger linters
      events = { "BufWritePost", "BufReadPost", "InsertLeave" },
      linters_by_ft = {
        -- lang
        c = { "clangtidy" },
        cpp = { "clangtidy" },
        java = { "checkstyle" },
        javascript = { "eslint" },
        javascriptreact = { "eslint" },
        kotlin = { "ktlint" },
        lisp = { "clj-kondo" },
        python = { "ruff" },
        typescript = { "eslint" },
        typescriptreact = { "eslint" },
        rust = { "clippy" },

        -- shell
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        fish = { "fish" },
        markdown = { "markdownlint" },
        text = { "typos" },
        -- Use the "*" filetype to run linters on all filetypes.
        -- ['*'] = { 'global linter' },
        -- Use the "_" filetype to run linters on filetypes that don't have other linters configured.
        -- ['_'] = { 'fallback linter' },
        -- ["*"] = { "typos" },
      },
      -- LazyVim extension to easily override linter options
      -- or add custom linters.
      ---@type table<string,table>
      linters = {
        -- -- Example of using selene only when a selene.toml file is present
        -- selene = {
        --   -- `condition` is another LazyVim extension that allows you to
        --   -- dynamically enable/disable linters based on the context.
        --   condition = function(ctx)
        --     return vim.fs.find({ "selene.toml" }, { path = ctx.filename, upward = true })[1]
        --   end,
        -- },
      },
    },
  },
}
