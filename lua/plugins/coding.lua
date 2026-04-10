-- ~/.config/nvim/lua/plugins/coding.lua
-- Editing utilities: autopairs, comments, mini.ai text objects,
-- LuaSnip, cmp-emoji, nvim-dap.

return {
  -- ── Autopairs ─────────────────────────────────────────────────────────
  {
    "nvim-mini/mini.pairs",
    opts = {
      modes = { insert = true, command = true, terminal = false },
      skip_next        = [=[[%w%%%'%[%"%.%`%$]]=],
      skip_ts          = { "string" },
      skip_unbalanced  = true,
      markdown         = true,
    },
  },

  -- ── Comments ──────────────────────────────────────────────────────────
  {
    "folke/ts-comments.nvim",
    opts = {
      lang = {
        -- Web
        javascript      = { "// %s", "/* %s */", call_expression = "// %s", jsx_element = "{/* %s */}", jsx_fragment = "{/* %s */}", spread_element = "// %s", statement_block = "// %s" },
        tsx             = { "// %s", "/* %s */", call_expression = "// %s", jsx_element = "{/* %s */}", jsx_fragment = "{/* %s */}", spread_element = "// %s", statement_block = "// %s" },
        typescript      = { "// %s", "/* %s */" },
        css             = "/* %s */",
        scss            = "/* %s */",
        html            = "<!-- %s -->",
        svelte          = "<!-- %s -->",
        vue             = "<!-- %s -->",
        -- Systems
        c               = "// %s",
        cpp             = "// %s",
        rust            = { "// %s", "/* %s */" },
        zig             = "// %s",
        go              = "// %s",
        -- Scripting / config
        python          = "# %s",
        lua             = "-- %s",
        bash            = "# %s",
        sh              = "# %s",
        zsh             = "# %s",
        fish            = "# %s",
        yaml            = "# %s",
        toml            = "# %s",
        nix             = { "# %s", "/* %s */" },
        -- Data / markup
        json            = "// %s",
        jsonc           = "// %s",
        sql             = "-- %s",
        make            = "# %s",
        -- Infra / config
        terraform       = "# %s",
        hcl             = "# %s",
        hyprlang        = "# %s",
        ini             = "; %s",
        -- Other
        graphql         = "# %s",
        markdown        = "<!-- %s -->",
        -- LazyVim extras
        astro           = "<!-- %s -->",
        blueprint       = "// %s",
        gleam           = "// %s",
        kdl             = "// %s",
        rego            = "# %s",
        styled          = "/* %s */",
        templ           = { "// %s", component_block = "<!-- %s -->" },
      },
    },
  },

  -- ── Text objects (mini.ai) ────────────────────────────────────────────
  {
    "nvim-mini/mini.ai",
    opts = function()
      local ai = require("mini.ai")
      return {
        n_lines = 500,
        custom_textobjects = {
          o = ai.gen_spec.treesitter({
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }),
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
          c = ai.gen_spec.treesitter({ a = "@class.outer",    i = "@class.inner"    }),
          t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" }, -- tags
          d = { "%f[%d]%d+" },                                                  -- digits
          e = {                                                                  -- word-case segments
            { "%u[%l%d]+%f[^%l%d]", "%f[%S][%l%d]+%f[^%l%d]", "%f[%P][%l%d]+%f[^%l%d]", "^[%l%d]+%f[^%l%d]" },
            "^().*()$",
          },
          g = LazyVim.mini.ai_buffer,
          u = ai.gen_spec.function_call(),
          U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }),
        },
      }
    end,
  },

  -- ── Snippets ──────────────────────────────────────────────────────────
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",
    build   = "make install_jsregexp",
  },

  -- ── nvim-cmp: emoji source add-on ────────────────────────────────────
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-emoji" },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      table.insert(opts.sources, { name = "emoji" })
    end,
  },

  -- ── DAP (debug adapter protocol) ─────────────────────────────────────
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
    },
    ft = {
      "go", "rust", "python", "javascript", "typescript",
      "lua", "c", "cpp", "java", "zig",
    },
  },
}
