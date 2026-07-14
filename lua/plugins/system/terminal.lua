-- ~/.config/nvim/lua/plugins/system/terminal.lua
-- Terminal: toggleterm.
-- Layer: system (host integration — terminal emulator).
return {
  {
    "akinsho/toggleterm.nvim",
    keys = {
      { "<C-t>", "<cmd>ToggleTerm direction=float<cr>", desc = "Float terminal" },
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