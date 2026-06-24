-- ~/.config/nvim/lua/plugins/ui/ui.lua
-- UI layer: bufferline, lualine, noice, mini.icons, snacks (dashboard,
-- picker, explorer, toggles), neogit, toggleterm, nvim-tree.

return {
  -- ── Bufferline ────────────────────────────────────────────────────────
  {
    "akinsho/bufferline.nvim",
    keys = {
      { "<leader>bp", "<Cmd>BufferLineTogglePin<cr>", desc = "Toggle pin" },
      {
        "<leader>bP",
        "<Cmd>BufferLineGroupClose ungrouped<cr>",
        desc = "Delete non-pinned buffers",
      },
      { "<leader>br", "<Cmd>BufferLineCloseRight<cr>", desc = "Delete buffers to the right" },
      { "<leader>bl", "<Cmd>BufferLineCloseLeft<cr>", desc = "Delete buffers to the left" },
      { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev buffer" },
      { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next buffer" },
      { "[B", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer prev" },
      { "]B", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer next" },
      { "<leader>bj", "<cmd>BufferLinePick<cr>", desc = "Pick Buffer" },
    },
    opts = {
      options = {
        -- stylua: ignore
        close_command       = function(n) Snacks.bufdelete(n) end,
        right_mouse_command = function(n) Snacks.bufdelete(n) end,
        diagnostics = "nvim_lsp",
        always_show_bufferline = false,
        show_buffer_close_icons = false,
        diagnostics_indicator = function(_, _, diag)
          local icons = LazyVim.config.icons.diagnostics
          local ret = (diag.error and icons.Error .. diag.error .. " " or "")
            .. (diag.warning and icons.Warn .. diag.warning or "")
          return vim.trim(ret)
        end,
        offsets = {
          {
            filetype = "neo-tree",
            text = "Neo-tree",
            highlight = "Directory",
            text_align = "left",
          },
          { filetype = "snacks_layout_box" },
        },
        get_element_icon = function(opts) return LazyVim.config.icons.ft[opts.filetype] end,
      },
    },
  },

  -- ── Lualine ───────────────────────────────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      local lualine_require = require("lualine_require")
      lualine_require.require = require

      local icons = LazyVim.config.icons
      vim.o.laststatus = vim.g.lualine_laststatus

      local opts = {
        options = {
          theme = "auto",
          globalstatus = vim.o.laststatus == 3,
          disabled_filetypes = {
            statusline = { "dashboard", "alpha", "ministarter", "snacks_dashboard" },
          },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch" },
          lualine_c = {
            LazyVim.lualine.root_dir(),
            {
              "diagnostics",
              symbols = {
                error = icons.diagnostics.Error,
                warn = icons.diagnostics.Warn,
                info = icons.diagnostics.Info,
                hint = icons.diagnostics.Hint,
              },
            },
            { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
            { LazyVim.lualine.pretty_path() },
          },
          lualine_x = {
            Snacks.profiler.status(),
            -- stylua: ignore
            { function() return require("noice").api.status.command.get() end, cond = function() return package.loaded["noice"] and require("noice").api.status.command.has() end, color = function() return { fg = Snacks.util.color("Statement") } end },
            -- stylua: ignore
            { function() return require("noice").api.status.mode.get() end,    cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has()    end, color = function() return { fg = Snacks.util.color("Constant")  } end },
            -- stylua: ignore
            { function() return "  " .. require("dap").status() end,           cond = function() return package.loaded["dap"]   and require("dap").status() ~= ""             end, color = function() return { fg = Snacks.util.color("Debug")     } end },
            -- stylua: ignore
            { require("lazy.status").updates, cond = require("lazy.status").has_updates, color = function() return { fg = Snacks.util.color("Special") } end },
            {
              "diff",
              symbols = {
                added = icons.git.added,
                modified = icons.git.modified,
                removed = icons.git.removed,
              },
              source = function()
                local gs = vim.b.gitsigns_status_dict
                if gs then
                  return { added = gs.added, modified = gs.changed, removed = gs.removed }
                end
              end,
            },
          },
          lualine_y = {
            { "progress", separator = " ", padding = { left = 1, right = 0 } },
            { "location", padding = { left = 0, right = 1 } },
          },
          lualine_z = {
            function() return " " .. os.date("%R") end,
          },
        },
        extensions = { "neo-tree", "lazy", "fzf" },
      }

      -- Trouble symbols in lualine_c
      if vim.g.trouble_lualine and LazyVim.has("trouble.nvim") then
        local trouble = require("trouble")
        local symbols = trouble.statusline({
          mode = "symbols",
          groups = {},
          title = false,
          filter = { range = true },
          format = "{kind_icon}{symbol.name:Normal}",
          hl_group = "lualine_c_normal",
        })
        table.insert(opts.sections.lualine_c, {
          symbols and symbols.get,
          cond = function() return vim.b.trouble_lualine ~= false and symbols.has() end,
        })
      end

      return opts
    end,
  },

  -- ── Noice ─────────────────────────────────────────────────────────────
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

  -- ── Mini icons ────────────────────────────────────────────────────────
  {
    "nvim-mini/mini.icons",
    lazy = true,
    opts = {
      file = {
        [".keep"] = { glyph = "󰊢 ", hl = "MiniIconsGrey" },
        [".envrc"] = { glyph = " ", hl = "MiniIconsYellow" },
        ["devcontainer.json"] = { glyph = " ", hl = "MiniIconsAzure" },
      },
      filetype = {
        dotenv = { glyph = " ", hl = "MiniIconsYellow" },
      },
      extension = {
        img = { glyph = " ", hl = "MiniIconsGrey" },
        iso = { glyph = " ", hl = "MiniIconsGrey" },
        lock = { glyph = "", hl = "MiniIconsGrey" },
      },
    },
  },

  { "MunifTanjim/nui.nvim" },

  -- ── Snacks (dashboard, picker, explorer, toggles, …) ──────────────────
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      bigfile = { enabled = true },
      -- FIX-DEPLOY-EXPLORER (2026-06-23): enabled Snacks explorer.
      -- This is the primary file explorer (vim.g.lazyvim_file_explorer = "snacks").
      -- <leader>e (root dir) and <leader>E (cwd) keymaps defined in keys below.
      explorer = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      notifier = { enabled = true },
      picker = { enabled = true },
      quickfile = { enabled = true },
      words = { enabled = true },
      styles = { notification = {} },
      statuscolumn = {
        enabled = true,
        relculright = true,
        separator = "│",
      },
      toggle = { map = LazyVim.safe_keymap_set },

      -- ── Dashboard ──────────────────────────────────────────────────
      dashboard = {
        enabled = true,
        preset = {
          pick = function(cmd, opts) return LazyVim.pick(cmd, opts)() end,
          header = [[
       ██╗      █████╗ ███████╗██╗   ██╗██╗   ██╗██╗███╗   ███╗          Z
       ██║     ██╔══██╗╚══███╔╝╚██╗ ██╔╝██║   ██║██║████╗ ████║      Z    
       ██║     ███████║  ███╔╝  ╚████╔╝ ██║   ██║██║██╔████╔██║   z       
       ██║     ██╔══██║ ███╔╝    ╚██╔╝  ╚██╗ ██╔╝██║██║╚██╔╝██║ z         
       ███████╗██║  ██║███████╗   ██║    ╚████╔╝ ██║██║ ╚═╝ ██║           
       ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝     ╚═══╝  ╚═╝╚═╝     ╚═╝           
]],
        },
      },

      -- ── Snacks window scroll keybindings ───────────────────────────
      win = {
        scroll_down = "<C-j>",
        scroll_up = "<C-k>",
      },
    },

    -- stylua: ignore
    keys = {
      -- Pickers
      { "<leader><space>", function() Snacks.picker.smart()           end, desc = "Smart find files" },
      { "<leader>,",       function() Snacks.picker.buffers()         end, desc = "Buffers" },
      { "<leader>/",       function() Snacks.picker.grep()            end, desc = "Grep" },
      { "<leader>:",       function() Snacks.picker.command_history()  end, desc = "Command history" },
      -- FIX-DEPLOY-EXPLORER (2026-06-23): Snacks explorer keymaps.
      -- <leader>e  → Snacks.explorer (root dir — LazyVim detects git root)
      -- <leader>E  → Snacks.explorer (cwd — explicit current working dir)
      -- <leader>fe → Snacks.picker.files (find files, not explorer)
      { "<leader>e",  function() Snacks.explorer()                              end, desc = "Explorer (Root Dir)" },
      { "<leader>E",  function() Snacks.explorer({ cwd = vim.fn.getcwd() })    end, desc = "Explorer (cwd)" },
      -- find
      { "<leader>fb",      function() Snacks.picker.buffers()         end, desc = "Buffers" },
      { "<leader>fc",      function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find config file" },
      { "<leader>ff",      function() Snacks.picker.files()           end, desc = "Find files" },
      { "<leader>fg",      function() Snacks.picker.git_files()       end, desc = "Find git files" },
      { "<leader>fp",      function() Snacks.picker.projects()        end, desc = "Projects" },
      { "<leader>fr",      function() Snacks.picker.recent()          end, desc = "Recent files" },
      -- git
      { "<leader>gb",      function() Snacks.picker.git_branches()    end, desc = "Git branches" },
      { "<leader>gl",      function() Snacks.picker.git_log()         end, desc = "Git log" },
      { "<leader>gL",      function() Snacks.picker.git_log_line()    end, desc = "Git log line" },
      { "<leader>gs",      function() Snacks.picker.git_status()      end, desc = "Git status" },
      { "<leader>gS",      function() Snacks.picker.git_stash()       end, desc = "Git stash" },
      { "<leader>gd",      function() Snacks.picker.git_diff()        end, desc = "Git diff (hunks)" },
      { "<leader>gf",      function() Snacks.picker.git_log_file()    end, desc = "Git log file" },
      -- GitHub
      { "<leader>gi",      function() Snacks.picker.gh_issue()        end, desc = "GitHub issues (open)" },
      { "<leader>gI",      function() Snacks.picker.gh_issue({ state = "all" }) end, desc = "GitHub issues (all)" },
      { "<leader>gp",      function() Snacks.picker.gh_pr()           end, desc = "GitHub PRs (open)" },
      { "<leader>gP",      function() Snacks.picker.gh_pr({ state = "all" }) end, desc = "GitHub PRs (all)" },
      -- grep
      { "<leader>sB",      function() Snacks.picker.grep_buffers()    end, desc = "Grep open buffers" },
      { "<leader>sg",      function() Snacks.picker.grep()            end, desc = "Grep" },
      { "<leader>sw",      function() Snacks.picker.grep_word()       end, desc = "Visual selection or word", mode = { "n", "x" } },
      -- search
      { '<leader>s"',      function() Snacks.picker.registers()       end, desc = "Registers" },
      { "<leader>s/",      function() Snacks.picker.search_history()  end, desc = "Search history" },
      { "<leader>sa",      function() Snacks.picker.autocmds()        end, desc = "Autocmds" },
      { "<leader>sb",      function() Snacks.picker.lines()           end, desc = "Buffer lines" },
      { "<leader>sc",      function() Snacks.picker.command_history()  end, desc = "Command history" },
      { "<leader>sC",      function() Snacks.picker.commands()        end, desc = "Commands" },
      { "<leader>sd",      function() Snacks.picker.diagnostics()     end, desc = "Diagnostics" },
      { "<leader>sD",      function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer diagnostics" },
      { "<leader>sh",      function() Snacks.picker.help()            end, desc = "Help pages" },
      { "<leader>sH",      function() Snacks.picker.highlights()      end, desc = "Highlights" },
      { "<leader>si",      function() Snacks.picker.icons()           end, desc = "Icons" },
      { "<leader>sj",      function() Snacks.picker.jumps()           end, desc = "Jumps" },
      { "<leader>sk",      function() Snacks.picker.keymaps()         end, desc = "Keymaps" },
      { "<leader>sl",      function() Snacks.picker.loclist()         end, desc = "Location list" },
      { "<leader>sm",      function() Snacks.picker.marks()           end, desc = "Marks" },
      { "<leader>sM",      function() Snacks.picker.man()             end, desc = "Man pages" },
      { "<leader>sp",      function() Snacks.picker.lazy()            end, desc = "Plugin spec search" },
      { "<leader>sq",      function() Snacks.picker.qflist()          end, desc = "Quickfix list" },
      { "<leader>sR",      function() Snacks.picker.resume()          end, desc = "Resume" },
      { "<leader>su",      function() Snacks.picker.undo()            end, desc = "Undo history" },
      { "<leader>uC",      function() Snacks.picker.colorschemes()    end, desc = "Colorschemes" },
      -- LSP via picker
      { "gd",         function() Snacks.picker.lsp_definitions()      end, desc = "Goto definition" },
      { "gD",         function() Snacks.picker.lsp_declarations()     end, desc = "Goto declaration" },
      { "gr",         function() Snacks.picker.lsp_references()       end, nowait = true, desc = "References" },
      { "gI",         function() Snacks.picker.lsp_implementations()  end, desc = "Goto implementation" },
      { "gy",         function() Snacks.picker.lsp_type_definitions() end, desc = "Goto type definition" },
      { "gai",        function() Snacks.picker.lsp_incoming_calls()   end, desc = "Calls incoming" },
      { "gao",        function() Snacks.picker.lsp_outgoing_calls()   end, desc = "Calls outgoing" },
      { "<leader>ss", function() Snacks.picker.lsp_symbols()          end, desc = "LSP symbols" },
      { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols()end, desc = "LSP workspace symbols" },
      -- Misc
      { "<leader>z",  function() Snacks.zen()                         end, desc = "Toggle zen mode" },
      { "<leader>Z",  function() Snacks.zen.zoom()                    end, desc = "Toggle zoom" },
      { "<leader>.",  function() Snacks.scratch()                     end, desc = "Toggle scratch buffer" },
      { "<leader>S",  function() Snacks.scratch.select()              end, desc = "Select scratch buffer" },
      { "<leader>dps",function() Snacks.profiler.scratch()            end, desc = "Profiler Scratch Buffer" },
      { "<leader>n",  function()
          if Snacks.config.picker and Snacks.config.picker.supports_live then
            Snacks.picker.notifications()
          else
            Snacks.notifier.show_history()
          end
        end, desc = "Notification history" },
      { "<leader>bd",   function() Snacks.bufdelete()               end, desc = "Delete buffer" },
      { "<leader>cR",   function() Snacks.rename.rename_file()      end, desc = "Rename file" },
      { "<leader>gB",   function() Snacks.gitbrowse()               end, desc = "Git browse", mode = { "n", "v" } },
      { "<leader>un",   function() Snacks.notifier.hide()           end, desc = "Dismiss all notifications" },
      { "<leader>N",    function()
          Snacks.win({
            file = vim.api.nvim_get_runtime_file("doc/news.txt", false)[1],
            width = 0.6, height = 0.6,
            wo   = { spell = false, wrap = false, signcolumn = "yes", statuscolumn = " ", conceallevel = 3 },
          })
        end, desc = "Neovim news" },
    },

    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          -- Debug helpers
          _G.dd = function(...) Snacks.debug.inspect(...) end
          _G.bt = function() Snacks.debug.backtrace() end

          if vim.fn.has("nvim-0.11") == 1 then
            vim._print = function(_, ...) dd(...) end
          else
            vim.print = _G.dd
          end

          -- FIX-DEPLOY-UI (2026-06-23): register Snacks.picker as vim.ui.select.
          -- LazyVim healthcheck expects this to be set.
          vim.ui.select = Snacks.picker.select

          -- ── Toggles ────────────────────────────────────────────────
          Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
          Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
          Snacks.toggle.option("relativenumber", { name = "Relative number" }):map("<leader>uL")
          Snacks.toggle.diagnostics():map("<leader>ud")
          Snacks.toggle.line_number():map("<leader>ul")
          Snacks.toggle
            .option("conceallevel", { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 })
            :map("<leader>uc")
          Snacks.toggle.treesitter():map("<leader>uT")
          Snacks.toggle
            .option("background", { off = "light", on = "dark", name = "Dark background" })
            :map("<leader>ub")
          Snacks.toggle.inlay_hints():map("<leader>uh")
          Snacks.toggle.indent():map("<leader>ug")
          Snacks.toggle.dim():map("<leader>uD")
        end,
      })
    end,
  },

  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    -- stylua: ignore
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>qS", function() require("persistence").select() end,desc = "Select Session" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
    },
  },

  { "nvim-lua/plenary.nvim", lazy = true },

  { "MunifTanjim/nui.nvim", lazy = true },
}
