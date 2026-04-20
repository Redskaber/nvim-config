-- ~/.config/nvim/lua/modules/lang/csharp.lua
-- C# via OmniSharp or Roslyn-based LSP

return {
  version = 1,
  treesitter = { "c_sharp", "xml" },

  lsp = {
    omnisharp = {
      cmd = { "omnisharp" },
      settings = {
        FormattingOptions = {
          EnableEditorConfigSupport = true,
        },
        RoslynExtensionsOptions = {
          EnableAnalyzersSupport = true,
          EnableImportCompletion = true,
        },
      },
    },
  },

  formatters = {
    csharp = { "dotnet-format" },
  },

  linters = {
    csharp = { "roslyn" }, -- conceptual mapping（实际走 omnisharp/roslyn）
  },

  mason = { "omnisharp", "csharpier" }, -- 可选：csharpier 作为 formatter 替代
}
