-- ~/.config/nvim/lua/plugins/lang/c_cpp.lua
-- C/C++ language editing enhancements.
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter (runtime/adapters/) owns: LSP (clangd), formatter
--     (clang-format), linters (clangtidy), mason packages, treesitter.
--   • This file owns: clangd editing extensions (switch source/header,
--     compiler flags inspection, inlay hints toggle).
--
-- clangd_extensions.nvim: augments clangd LSP with C++-specific niceties
-- that vanilla nvim-lspconfig does not provide:
--   • <leader>cA — switch between source (.c/.cpp) and header (.h) file
--   • :ClangdSwitchSourceHeader — explicit switch command
--   • Inlay hints toggle, memory usage inspection
-- High-frequency for any C/C++ project — the source/header switch alone
-- is a daily operation.
return {
  {
    "p00f/clangd_extensions.nvim",
    ft = { "c", "cpp", "objc", "objcpp", "cuda" },
    dependencies = { "neovim/nvim-lspconfig" },
    opts = {
      inlay_hints = {
        inline = vim.fn.has("nvim-0.10") == 1,
        only_current_line = false,
        parameter_hints_prefix = "<- ",
        other_hints_prefix = "=> ",
        max_len_align = false,
        right_align = false,
      },
      ast = {
        role_icons = {
          type = "🄣 ",
          declaration = "🄓 ",
          expression = "🄔 ",
          statement = ";",
          specifier = "🄢 ",
          ["template argument"] = "🆃 ",
        },
        kind_icons = {
          Compound = "🄲 ",
          Recovery = "🅁 ",
          TranslationUnit = "🅄 ",
          PackExpansion = "🄿 ",
          TemplateTypeParm = "🅃 ",
          TemplateTemplateParm = "🅃 ",
          TemplateParamObject = "🅃 ",
        },
      },
    },
    config = function(_, opts)
      require("clangd_extensions").setup(opts)
      vim.keymap.set(
        "n",
        "<leader>cA",
        "<cmd>ClangdSwitchSourceHeader<cr>",
        { desc = "Switch source/header (C/C++)" }
      )
    end,
  },
}
