-- ~/.config/nvim/lua/plugins/editor/cursor.lua
return {
  {
    "mg979/vim-visual-multi",
    keys = {
      { "<C-n>", mode = { "n", "x" }, desc = "VM: Add next selection" },
      { "<C-d>", mode = { "n", "x" }, desc = "VM: Find subword" },
      { "<leader>vu", "<Plug>(VM-Undo)", desc = "VM: Undo" },
      { "<leader>vr", "<Plug>(VM-Redo)", desc = "VM: Redo" },
    },
    init = function()
      vim.g.VM_maps = {
        ["Find Under"] = "<C-n>",
        ["Find Subword Under"] = "<C-d>",
        ["Add Cursor Down"] = "<A-j>", -- 终端友好垂直添加
        ["Add Cursor Up"] = "<A-k>",
      }
      vim.g.VM_leader = " " -- 与 LazyVim 空格 leader 对齐
      vim.g.VM_mouse_mappings = 1
    end,
  },
}