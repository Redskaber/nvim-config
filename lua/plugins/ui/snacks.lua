-- ~/.config/nvim/lua/plugins/ui/snacks.lua
-- Snacks.nvim: dashboard, picker, explorer, toggles, notifier, etc.
-- Layer: ui (interface — multipurpose UI toolkit).
-- This is the primary file explorer (vim.g.lazyvim_file_explorer = "snacks").
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      bigfile = { enabled = true },
      -- FIX-DEPLOY-EXPLORER (2026-06-23): enabled Snacks explorer.
      -- <leader>e (root dir) and <leader>E (cwd) keymaps defined in keys below.
      --
      -- FIX-HIDDEN-FILES (2026-06-26): show dotfiles (.* ) in explorer by default.
      -- Previously: explorer = { enabled = true } used snacks defaults, which
      -- hide dotfiles (.gitignore, .env, .stylua.toml, etc.) and respect
      -- .gitignore. Users editing nvim config (which has many dotfiles) need
      -- to see them without manually pressing H each session.
      --
      -- Runtime toggle still available: press H (toggle dotfiles) or
      -- I (toggle gitignored) in the explorer window.
      explorer = {
        enabled = true,
        filter = {
          hidden = true, -- show .gitignore, .env, .stylua.toml, etc.
          respect_gitignore = false, -- show ALL files (not just non-ignored)
        },
      },
      indent = { enabled = true },
      input = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      notifier = { enabled = true },
      picker = { enabled = true },
      profiler = { enabled = true }, -- FIX-P3 (2026-07-15): lualine.lua references Snacks.profiler.status() and <leader>dps keymap below — module must be enabled.
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

      -- ── Snacks window scroll keybindings (merged from old ui/snacks.lua) ──
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
      -- Explorer
      { "<leader>e",  function() Snacks.explorer()                              end, desc = "Explorer (Root Dir)" },
      { "<leader>E",  function() Snacks.explorer({ cwd = vim.fn.getcwd() })    end, desc = "Explorer (cwd)" },
      -- find
      { "<leader>fb",      function() Snacks.picker.buffers()         end, desc = "Buffers" },
      { "<leader>fc",      function() Snacks.picker.files({ cwd = vim.fn.stdpath("config"), hidden = true, respects_gitignore = false }) end, desc = "Find config file" },
      { "<leader>ff",      function() Snacks.picker.files({ hidden = true, respects_gitignore = false }) end, desc = "Find files" },
      { "<leader>fG",      function() Snacks.picker.git_files()       end, desc = "Find git files" },
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
      -- Snacks window scroll keybindings (merged from old ui/snacks.lua)
      { "<C-j>", desc = "Snacks: Scroll down" },
      { "<C-k>", desc = "Snacks: Scroll up" },
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
}