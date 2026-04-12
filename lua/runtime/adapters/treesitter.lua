-- ~/.config/nvim/lua/runtime/adapters/treesitter.lua
-- Backend layer: IR → nvim-treesitter LazySpec.

local M = {}

local util = require("core.kernel.util")

local BASE_PARSERS = {
  "bash",
  "c",
  "diff",
  "lua",
  "luadoc",
  "markdown",
  "markdown_inline",
  "printf",
  "query",
  "regex",
  "vim",
  "vimdoc",
}

---@param ir table
---@return table[]
function M.build(ir)
  if not ir.all_parsers then
    vim.notify("[ltos:treesitter] IR missing required field: all_parsers", vim.log.levels.WARN)
    return {}
  end

  local parsers = util.dedup(vim.list_extend(vim.deepcopy(BASE_PARSERS), ir.all_parsers))

  return {
    {
      "nvim-treesitter/nvim-treesitter",
      _source = "ltos:treesitter",
      opts = {
        ensure_installed = parsers,
        indent = { enable = true },
        highlight = { enable = true },
        folds = { enable = true },
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
