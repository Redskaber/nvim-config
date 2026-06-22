-- ~/.config/nvim/lua/plugins/lsp/lsp.lua
-- LSP engine wiring only. Server configs come from runtime/adapters/lsp.lua.

return {
  { "mason-org/mason-lspconfig.nvim" },

  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "mason-org/mason.nvim",
      { "mason-org/mason-lspconfig.nvim", config = function() end },
    },
    opts_extend = { "servers.*.keys" },
    opts = function()
      ---@class PluginLspOpts
      local ret = {
        ---@type vim.diagnostic.Opts
        diagnostics = {
          underline = true,
          update_in_insert = false,
          severity_sort = true,
          virtual_text = {
            spacing = 4,
            source = "if_many",
            prefix = "●",
          },
          signs = {
            text = {
              [vim.diagnostic.severity.ERROR] = LazyVim.config.icons.diagnostics.Error,
              [vim.diagnostic.severity.WARN] = LazyVim.config.icons.diagnostics.Warn,
              [vim.diagnostic.severity.HINT] = LazyVim.config.icons.diagnostics.Hint,
              [vim.diagnostic.severity.INFO] = LazyVim.config.icons.diagnostics.Info,
            },
          },
        },

        inlay_hints = {
          enabled = true,
          exclude = { "vue" },
        },

        codelens = { enabled = false },

        -- P0-6: primary strategy is treesitter expr (set in options.lua);
        -- LSP folding is a secondary enhancement when server supports it.
        folds = { enabled = true },

        format = {
          formatting_options = nil,
          timeout_ms = nil,
        },

        -- Shared server defaults + key bindings
        ---@type table<string, lazyvim.lsp.Config|boolean>
        servers = {
          ["*"] = {
            capabilities = {
              workspace = {
                fileOperations = {
                  didRename = true,
                  willRename = true,
                },
              },
            },
            -- stylua: ignore
            keys = {
              { "<leader>cl", function() Snacks.picker.lsp_config() end,          desc = "LSP info" },
              { "gd",         vim.lsp.buf.definition,                             desc = "Goto definition",          has = "definition" },
              { "gr",         vim.lsp.buf.references,                             desc = "References",               nowait = true },
              { "gI",         vim.lsp.buf.implementation,                         desc = "Goto implementation" },
              { "gy",         vim.lsp.buf.type_definition,                        desc = "Goto type definition" },
              { "gD",         vim.lsp.buf.declaration,                            desc = "Goto declaration" },
              { "K",          function() vim.lsp.buf.hover() end,                 desc = "Hover" },
              { "gK",         function() vim.lsp.buf.signature_help() end,        desc = "Signature help",           has = "signatureHelp" },
              { "<c-k>",      function() vim.lsp.buf.signature_help() end,        desc = "Signature help",           mode = "i", has = "signatureHelp" },
              { "<leader>ca", vim.lsp.buf.code_action,                            desc = "Code action",              mode = { "n", "x" }, has = "codeAction" },
              { "<leader>cc", vim.lsp.codelens.run,                               desc = "Run codelens",             mode = { "n", "x" }, has = "codeLens" },
              { "<leader>cC", vim.lsp.codelens.refresh,                           desc = "Refresh codelens",         has = "codeLens" },
              { "<leader>cR", function() Snacks.rename.rename_file() end,         desc = "Rename file",              mode = { "n" }, has = { "workspace/didRenameFiles", "workspace/willRenameFiles" } },
              { "<leader>cr", vim.lsp.buf.rename,                                 desc = "Rename symbol",            has = "rename" },
              { "<leader>cA", LazyVim.lsp.action.source,                         desc = "Source action",            has = "codeAction" },
              { "]]",         function() Snacks.words.jump(vim.v.count1) end,     desc = "Next reference",           has = "documentHighlight", enabled = function() return Snacks.words.is_enabled() end },
              { "[[",         function() Snacks.words.jump(-vim.v.count1) end,    desc = "Prev reference",           has = "documentHighlight", enabled = function() return Snacks.words.is_enabled() end },
              { "<a-n>",      function() Snacks.words.jump(vim.v.count1, true) end,  desc = "Next reference",       has = "documentHighlight", enabled = function() return Snacks.words.is_enabled() end },
              { "<a-p>",      function() Snacks.words.jump(-vim.v.count1, true) end, desc = "Prev reference",       has = "documentHighlight", enabled = function() return Snacks.words.is_enabled() end },
              {
                "<leader>co",
                LazyVim.lsp.action["source.organizeImports"],
                desc = "Organize Imports",
                has = "codeAction",
                enabled = function(buf)
                  local code_actions = vim.tbl_filter(function(action)
                    return action:find("^source%.organizeImports%.?$")
                  end, LazyVim.lsp.code_actions({ bufnr = buf }))
                  return #code_actions > 0
                end
              },
            },
          },
        },

        setup = {},
      }
      return ret
    end,
  },

  {
    "mason-org/mason.nvim",
    -- FIX-DEPLOY-MASON (2026-06-23): opts_extend ensures ensure_installed lists
    -- from runtime/adapters/mason.lua are merged (not replaced) with any
    -- LazyVim defaults. This prevents the "Package is already installing" race
    -- by ensuring a single merged opts table.
    opts_extend = { "ensure_installed" },
    opts = {}, -- ensure_installed populated by runtime/adapters/mason.lua
  },
}