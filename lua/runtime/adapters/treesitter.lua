-- ~/.config/nvim/lua/runtime/adapters/treesitter.lua
-- Pure function: ctx → nvim-treesitter spec.

local M = {}

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

---@param ctx table
---@return table[]
function M.build(ctx)
  local seen = {}
  local parsers = {}

  local function add(p)
    if not seen[p] then
      parsers[#parsers + 1] = p
      seen[p] = true
    end
  end

  for _, p in ipairs(BASE_PARSERS) do
    add(p)
  end

  for _, cap in pairs(ctx.caps) do
    if cap.treesitter then
      for _, p in ipairs(cap.treesitter) do
        add(p)
      end
    end
  end

  return {
    {
      "nvim-treesitter/nvim-treesitter",
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
