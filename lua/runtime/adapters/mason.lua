-- ~/.config/nvim/lua/runtime/adapters/mason.lua
-- Codegen adapter: IR → mason-nvim LazySpec.
-- Resolution decisions already live in ir.resolved (pipeline pass 3).
-- This adapter only reads IR; no toolchain logic here (P0-4 / P1-2).

local M = {}

local mappings = require("toolchain.mappings")
local util = require("core.util")

local BASE_TOOLS = { "codespell" }

---@param ir table  post-optimize IR
---@return table[]
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

  -- Build a set of known LSP mason package names to guard against
  -- double-counting if a lang module lists them explicitly in cap.mason.
  local lsp_pkgs = {}
  for _, pkg in pairs(mappings.lsp_to_mason) do
    lsp_pkgs[pkg] = true
  end

  -- Formatters & linters (via explicit mason lists on each cap)
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

  local ensure_installed = util.dedup(raw)

  return {
    {
      "mason-org/mason.nvim",
      opts = { ensure_installed = ensure_installed },
      _source = "ltos:mason",
    },
  }
end

return M
