-- ~/.config/nvim/lua/plugins/coding.lua
-- author: redskaber
-- datetime: 2025-12-12

return {
  {
    "nvim-mini/mini.pairs",
    opts = {
      modes = { insert = true, command = true, terminal = false },
      -- skip autopair when next character is one of these
      skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
      -- skip autopair when the cursor is inside these treesitter nodes
      skip_ts = { "string" },
      -- skip autopair when next character is closing pair
      -- and there are more closing pairs than opening pairs
      skip_unbalanced = true,
      -- better deal with markdown code blocks
      markdown = true,
    },
  },
  {
    "folke/ts-comments.nvim",
    opts = {
      lang = {
        -- Web
        javascript = {
          "// %s",
          "/* %s */",
          call_expression = "// %s",
          jsx_element = "{/* %s */}",
          jsx_fragment = "{/* %s */}",
          spread_element = "// %s",
          statement_block = "// %s",
        },
        tsx = {
          "// %s",
          "/* %s */",
          call_expression = "// %s",
          jsx_element = "{/* %s */}",
          jsx_fragment = "{/* %s */}",
          spread_element = "// %s",
          statement_block = "// %s",
        },
        typescript = { "// %s", "/* %s */" },
        css = "/* %s */",
        scss = "/* %s */",
        html = "<!-- %s -->",
        svelte = "<!-- %s -->",
        vue = "<!-- %s -->",
        -- Systems
        c = "// %s",
        cpp = "// %s",
        rust = { "// %s", "/* %s */" },
        zig = "// %s",
        go = "// %s",
        -- Scripting / config
        python = "# %s",
        lua = "-- %s",
        bash = "# %s",
        sh = "# %s",
        zsh = "# %s",
        fish = "# %s",
        yaml = "# %s",
        toml = "# %s",
        nix = { "# %s", "/* %s */" },
        -- Data / markup
        json = "// %s",
        jsonc = "// %s",
        sql = "-- %s",
        make = "# %s",
        -- Infra / config
        terraform = "# %s",
        hcl = "# %s",
        hyprlang = "# %s",
        ini = "; %s",
        -- Other
        graphql = "# %s",
        markdown = "<!-- %s -->",
        -- LazyVim extras
        astro = "<!-- %s -->",
        blueprint = "// %s",
        gleam = "// %s",
        kdl = "// %s",
        rego = "# %s",
        styled = "/* %s */",
        templ = { "// %s", component_block = "<!-- %s -->" },
      },
    },
  },
  {
    "nvim-mini/mini.ai",
    opts = function()
      local ai = require("mini.ai")
      return {
        n_lines = 500,
        custom_textobjects = {
          o = ai.gen_spec.treesitter({ -- code block
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }),
          f = ai.gen_spec.treesitter({
            a = "@function.outer",
            i = "@function.inner",
          }), -- function
          c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }), -- class
          t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" }, -- tags
          d = { "%f[%d]%d+" }, -- digits
          e = { -- Word with case
            {
              "%u[%l%d]+%f[^%l%d]",
              "%f[%S][%l%d]+%f[^%l%d]",
              "%f[%P][%l%d]+%f[^%l%d]",
              "^[%l%d]+%f[^%l%d]",
            },
            "^().*()$",
          },
          g = LazyVim.mini.ai_buffer, -- buffer
          u = ai.gen_spec.function_call(), -- u for "Usage"
          U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }), -- without dot in function name
        },
      }
    end,
  },
  {
    "folke/lazydev.nvim",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        { path = "LazyVim", words = { "LazyVim" } },
        { path = "snacks.nvim", words = { "Snacks" } },
        { path = "lazy.nvim", words = { "LazyVim" } },
      },
    },
  },
  {
    "L3MON4D3/LuaSnip",
    -- follow latest release.
    version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
    -- install jsregexp (optional!).
    build = "make install_jsregexp",
  },
  -- override nvim-cmp and add cmp-emoji
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-emoji" },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      table.insert(opts.sources, { name = "emoji" })
    end,
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
    },
    ft = {
      "go",
      "rust",
      "python",
      "javascript",
      "typescript",
      "lua",
      "c",
      "cpp",
      "java",
      "zig",
    },
  },
}
