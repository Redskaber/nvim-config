-- ~/.config/nvim/lua/plugins/system/terminal.lua
-- Terminal: toggleterm.
-- Layer: system (host integration — terminal emulator).
-- NOTE (P1-3): the <C-t> keymap is intentionally NOT defined here.
-- config/keymaps.lua owns <C-t> → runtime.api.terminal.horizontal().
-- Defining it here as well would shadow that mapping (snacks/toggleterm
-- keys load after keymaps.lua and win), causing <C-t> to open a float
-- instead of the intended horizontal terminal.
return {
  {
    "akinsho/toggleterm.nvim",
    keys = {
      { "<leader>t", "<cmd>ToggleTerm direction=float<cr>", desc = "Float terminal" },
      { "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Horizontal terminal" },
    },
    opts = {
      open_mapping = nil,
      direction = "horizontal",
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return math.floor(vim.o.columns * 0.4)
        end
      end,
    },
  },
}