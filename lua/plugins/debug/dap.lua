-- ~/.config/nvim/lua/plugins/debug/dap.lua
-- DAP engine: nvim-dap + UI + virtual text.
-- Layer: debug (debug adapter protocol engine + UI).
-- Per-language DAP adapters live in this directory (dap-go, dap-python, etc).
--
-- FIX-DEPLOY-DAP (2026-06-23): removed ft lazy loading — LazyVim's dap
-- config calls require("dap").setup() at startup, but ft lazy loading
-- meant dap wasn't loaded yet → "attempt to call field 'setup' (a nil value)".
-- Now dap loads on keys/cmd (lazy but available when needed).
return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
    },
    keys = {
      {
        "<leader>db",
        function() require("dap").toggle_breakpoint() end,
        desc = "Toggle breakpoint",
      },
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step over" },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>dr", function() require("dap").repl.open() end, desc = "Open REPL" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle DAP UI" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
    end,
  },
}