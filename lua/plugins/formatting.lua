-- ~/.config/nvim/lua/plugins/coding.lua
-- author: redskaber
-- datetime: 2025-12-12

return {
  { "mason.nvim" },
  {
    "stevearc/conform.nvim",
    dependencies = { "mason.nvim" },
    opts = function()
      ---@type conform.setupOpts
      local opts = {
        formatters_by_ft = {
          -- lang
          c = { "clang-format" },
          cpp = { "clang-format" },
          go = { "gofmt" },
          java = { "google-java-format" },
          javascript = { "prettierd" },
          kotlin = { "ktfmt" },
          lisp = { "cljfmt" },
          lua = { "stylua" },
          -- nix = { "alejandra" }, -- nixfmt
          python = { "ruff" },
          rust = { "rustfmt", lsp_format = "fallback" },
          typescript = { "prettierd" },
          tsx = { "prettierd" },
          zig = { "zigfmt" },

          -- markup
          toml = { "taplo" },
          markdown = { "prettierd" },
          html = { "prettierd" },
          css = { "prettierd" },
          scss = { "prettierd" },
          json = { "prettierd" },
          jsonc = { "prettierd" },
          yaml = { "prettierd" },

          -- shell
          sh = { "shfmt" },
          bash = { "shfmt" },
          fish = { "fish_indent" },

          -- Use the "*" filetype to run formatters on all filetypes.
          ["*"] = { "codespell" },
          -- Use the "_" filetype to run formatters on filetypes that don't
          -- have other formatters configured.
          ["_"] = { "trim_whitespace" },
        },
        -- The options you set here will be merged with the builtin formatters.
        -- You can also define any custom formatters here.
        ---@type table<string, conform.FormatterConfigOverride|fun(bufnr: integer): nil|conform.FormatterConfigOverride>
        formatters = {
          injected = { options = { ignore_errors = true } },
          -- # Example of using dprint only when a dprint.json file is present
          -- dprint = {
          --   condition = function(ctx)
          --     return vim.fs.find({ "dprint.json" }, { path = ctx.filename, upward = true })[1]
          --   end,
          -- },
          --
          -- # Example of using shfmt with extra args
          -- shfmt = {
          --   prepend_args = { "-i", "2", "-ci" },
          -- },
        },
      }
      return opts
    end,
  },
}
