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
          lua = { "stylua" },
          javascript = { "prettierd" }, -- or "prettier"
          typescript = { "prettierd" },
          tsx = { "prettierd" },
          rust = { "rustfmt", lsp_format = "fallback" },
          zig = { "zigfmt" },
          go = { "gofmt" }, -- or "goimports",
          c = { "clang-format" },
          cpp = { "clang-format" },
          json = { "prettierd" },
          yaml = { "prettierd" },
          toml = { "stylua" },
          markdown = { "prettierd" },
          html = { "prettierd" },
          css = { "prettierd" },
          scss = { "prettierd" },
          fish = { "fish_indent" },
          sh = { "shfmt" },
          python = function(bufnr)
            if require("conform").get_formatter_info("ruff_format", bufnr).available then
              return { "ruff_format" }
            else
              return { "isort", "black" }
            end
          end,
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
        format_on_save = {
          -- These options will be passed to conform.format()
          timeout_ms = 500,
          lsp_format = "fallback",
        },
      }
      return opts
    end,
  },
}
