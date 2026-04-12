-- lua/plugins/sys/terminal.lua
-- Terminal and file-tree plugins.

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
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>fe", "<cmd>NvimTreeToggle<cr>", desc = "File tree (nvim-tree)" },
    },
    config = function()
      require("nvim-tree").setup({
        sort = { sorter = "case_sensitive" },
        view = { width = 30 },
        renderer = { group_empty = true },
        filters = { dotfiles = true },
      })
    end,
    opts = {
      view = { width = 30 },
      renderer = { group_empty = true },
      filters = { dotfiles = false },
    },
  },
}
