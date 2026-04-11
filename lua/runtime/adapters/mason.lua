-- ~/.config/nvim/lua/runtime/adapters/mason.lua
-- Pure function: ctx → mason ensure_installed spec.
-- Resolution decisions already live in ctx.resolved (pipeline stage 3).
-- dedup delegated to core/util.dedup instead of inline seen/add.

local M = {}

local mappings = require("toolchain.mappings")
local util = require("core.util")

local BASE_TOOLS = { "codespell" }

---@param ctx table
---@return table[]
function M.build(ctx)
  if not ctx.caps then
    vim.notify("[ltos:mason] IR missing required field: caps", vim.log.levels.WARN)
    return {}
  end

  local raw = vim.deepcopy(BASE_TOOLS)

  -- LSP servers — package names come exclusively from mappings.lsp_pkg()
  for server, _ in pairs(ctx.merged_lsp or {}) do
    local want_mason = vim.tbl_get(ctx, "resolved", "lsp", server)
    if want_mason then
      raw[#raw + 1] = mappings.lsp_pkg(server)
    end
  end

  -- Build a set of known LSP mason package names to avoid double-counting
  -- even if a lang module still lists them in cap.mason.
  local lsp_pkgs = {}
  for _, pkg in pairs(mappings.lsp_to_mason) do
    lsp_pkgs[pkg] = true
  end

  -- Formatters & linters (via explicit mason lists on each cap)
  for _, cap in pairs(ctx.caps) do
    if cap.mason then
      for _, t in ipairs(cap.mason) do
        if not lsp_pkgs[t] then
          local pkg = mappings.tool_pkg(t)
          local want = vim.tbl_get(ctx, "resolved", "tools", t)
          if want and pkg then
            raw[#raw + 1] = pkg
          end
        end
      end
    end
  end

  -- FIX P2-3: use util.dedup for final deduplication
  local tools = util.dedup(raw)

  return {
    {
      "mason-org/mason.nvim",
      _source = "ltos:mason",
      opts = { ensure_installed = tools },
    },
  }
end

return M
