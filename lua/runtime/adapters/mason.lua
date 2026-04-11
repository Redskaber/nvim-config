-- ~/.config/nvim/lua/runtime/adapters/mason.lua
-- Backend layer: IR → mason-nvim LazySpec.
-- Resolution decisions already live in IR.resolved (Phase 3).
-- This adapter only reads IR — no toolchain logic here.

local M = {}

local mappings = require("toolchain.mappings")
local util = require("core.util")

local BASE_TOOLS = { "codespell" }

---@param ir table  LIR or SPEC-ready IR
---@return table[]  LazySpec[]
function M.build(ir)
  if not ir.caps then
    vim.notify("[ltos:mason] IR missing required field: caps", vim.log.levels.WARN)
    return {}
  end

  local raw = vim.deepcopy(BASE_TOOLS)

  -- LSP servers — package names come exclusively from mappings.lsp_pkg()
  for server, _ in pairs(ir.merged_lsp or {}) do
    local want_mason = vim.tbl_get(ir, "resolved", "lsp", server)
    if want_mason then
      raw[#raw + 1] = mappings.lsp_pkg(server)
    end
  end

  -- Guard against double-counting LSP packages that appear in cap.mason
  local lsp_pkgs = {}
  for _, pkg in pairs(mappings.lsp_to_mason) do
    lsp_pkgs[pkg] = true
  end

  -- Formatters & linters from explicit cap.mason lists
  for _, cap in pairs(ir.caps) do
    if cap.mason then
      for _, t in ipairs(cap.mason) do
        if not lsp_pkgs[t] then
          local pkg = mappings.tool_pkg(t)
          local want = vim.tbl_get(ir, "resolved", "tools", t)
          if want and pkg then
            raw[#raw + 1] = pkg
          end
        end
      end
    end
  end

  return {
    {
      "mason-org/mason.nvim",
      _source = "ltos:mason",
      opts = { ensure_installed = util.dedup(raw) },
    },
  }
end

return M
