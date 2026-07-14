-- ~/.config/nvim/lua/plugins/ui/noice.lua
-- Noice: UI overhaul for cmdline, messages, popup notifications.
-- Layer: ui (interface — command/message display).
return {
  {
    "folke/noice.nvim",
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      routes = {
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "%d+L, %d+B" },
              { find = "; after #%d+" },
              { find = "; before #%d+" },
            },
          },
          view = "mini",
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
      },
      views = {
        cmdline_popup = {
          position = { row = 5, col = "50%" },
          size = { width = 60, height = "auto" },
        },
        hover = {
          border = { style = "rounded", padding = { 0, 1 } },
          win_options = { winblend = 10, winhighlight = "Normal:Normal,FloatBorder:FloatBorder" },
        },
        signature = {
          border = { style = "single", padding = { 0, 1 } },
        },
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>sn",  "",                                                                             desc = "+noice" },
      { "<S-Enter>",   function() require("noice").redirect(vim.fn.getcmdline()) end,                  mode = "c",                        desc = "Redirect cmdline" },
      { "<leader>snl", function() require("noice").cmd("last")    end,                                 desc = "Noice last message" },
      { "<leader>snh", function() require("noice").cmd("history")  end,                                desc = "Noice history" },
      { "<leader>sna", function() require("noice").cmd("all")      end,                                desc = "Noice all" },
      { "<leader>snd", function() require("noice").cmd("dismiss")  end,                                desc = "Dismiss all" },
      { "<leader>snt", function() require("noice").cmd("pick")     end,                                desc = "Noice picker" },
      { "<c-f>",       function() if not require("noice.lsp").scroll(4)  then return "<c-f>" end end,  silent = true, expr = true, desc = "Scroll forward",  mode = { "i", "n", "s" } },
      { "<c-b>",       function() if not require("noice.lsp").scroll(-4) then return "<c-b>" end end,  silent = true, expr = true, desc = "Scroll backward", mode = { "i", "n", "s" } },
    },
  },
}