-- ~/.config/nvim/lua/runtime/adapters/treesitter.lua
-- Backend layer: IR → nvim-treesitter LazySpec.

local M = {}

local util = require("core.kernel.util")

local BASE_PARSERS = {
  "bash",
  "c",
  "diff",
  "html",
  "javascript",
  "jsdoc",
  "json",
  "lua",
  "luadoc",
  "luap",
  "markdownwn",
  "markdown_inline",
  "printf",
  "python",
  "query",
  "regex",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "xml",
  "yaml",
}

---@param ir table
---@return table[]
function M.build(ir)
  if not ir.all_parsers then
    return { { _ltos_error = "[ltos:treesitter] IR missing required field: all_parsers" } }
  end

  local parsers = util.dedup(vim.list_extend(vim.deepcopy(BASE_PARSERS), ir.all_parsers))

  return {
    {
      "nvim-treesitter/nvim-treesitter",
      _source = "ltos:treesitter",
      event = { "LazyFile", "VeryLazy" },
      cmd = { "TSUpdate", "TSInstall", "TSLog", "TSUninstall" },
      opts_extend = { "ensure_installed" },
      ---@alias lazyvim.TSFeat { enable?: boolean, disable?: string[] }
      ---@class lazyvim.TSConfig: TSConfig
      opts = {
        ensure_installed = parsers,
        indent = { enable = true }, ---@type lazyvim.TSFeat
        highlight = { enable = true }, ---@type lazyvim.TSFeat
        folds = { enable = true }, ---@type lazyvim.TSFeat
        textobjects = {
          select = {
            enable = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
              ["aa"] = "@parameter.outer",
              ["ia"] = "@parameter.inner",
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer", ["]a"] = "@parameter.inner" },
            goto_next_end = { ["]F"] = "@function.outer", ["]C"] = "@class.outer", ["]A"] = "@parameter.inner" },
            goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer", ["[a"] = "@parameter.inner" },
            goto_previous_end = { ["[F"] = "@function.outer", ["[C"] = "@class.outer", ["[A"] = "@parameter.inner" },
          },
          swap = {
            enable = true,
            swap_next = { ["<leader>a"] = "@parameter.inner" },
            swap_previous = { ["<leader>A"] = "@parameter.inner" },
          },
        },
      },
    },
  }
end

return M
