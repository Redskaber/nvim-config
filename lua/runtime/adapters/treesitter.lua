-- ~/.config/nvim/lua/runtime/adapters/treesitter.lua
-- Backend layer: IR → nvim-treesitter LazySpec.
--
-- FIX-TEST-BUG (2026-06-26): opts is now a STATIC table, not a lazy function.
-- Tests index `spec.opts.ensure_installed` directly. lazy.nvim still merges
-- static `opts = { ... }` with other specs' opts via `opts_extend`, so the
-- "merge with LazyVim defaults" behaviour is preserved.

local M = {}

local util = require("core.kernel.util")

local DEFAULT_BASE_PARSERS = {
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
  "markdown",
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

local function base_parsers_from_ir(ir)
  local req = ir.meta and ir.meta.build_request
  if req and type(req.base_parsers) == "table" then
    return req.base_parsers
  end
  return DEFAULT_BASE_PARSERS
end

---@param ir table
---@return table[]
function M.build(ir)
  if not ir.all_parsers then
    return { { _ltos_error = "[ltos:treesitter] IR missing required field: all_parsers" } }
  end

  local parsers = util.deep_copy(base_parsers_from_ir(ir))
  for _, p in ipairs(ir.all_parsers) do
    parsers[#parsers + 1] = p
  end
  parsers = util.dedup(parsers)

  return {
    {
      "nvim-treesitter/nvim-treesitter",
      _source = "ltos:treesitter",
      opts_extend = { "ensure_installed" },
      opts = { ensure_installed = parsers },
    },
  }
end

return M
