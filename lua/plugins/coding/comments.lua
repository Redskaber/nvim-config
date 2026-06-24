-- ~/.config/nvim/lua/plugins/coding/comments.lua

return {
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
}

