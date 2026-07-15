-- ~/.config/nvim/lua/plugins/debug/dap-python.lua
-- Python language editing enhancements.
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter (runtime/adapters/) owns: LSP (pyright), formatter
--     (ruff_or_black strategy), linters (ruff), mason packages, treesitter.
--   • This file owns: debug adapter integration (nvim-dap-python).
--
-- nvim-dap-python: debugpy-based Python debugger. Integrates with the
-- existing nvim-dap + nvim-dap-ui setup. Requires debugpy on PATH or
-- installed via mason; the plugin auto-detects via mason.nvim if present.
return {
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      -- Prefer mason-managed debugpy; fall back to system debugpy.
      local ok, mason_registry = pcall(require, "mason-registry")
      local debugpy_path
      if ok and mason_registry then
        local pkg = mason_registry.get_package("debugpy")
        if pkg and pkg:is_installed() then
          debugpy_path = pkg:get_install_path() .. "/debugpy-adapter"
        end
      end
      require("dap-python").setup(debugpy_path or "python")
    end,
  },
}