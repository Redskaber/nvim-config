-- lua/runtime/adapters/mason.lua
-- Backend layer: IR → mason-nvim LazySpec.
-- REFACTOR (TODO-5.4): pure IR reader — no vim API calls.
-- Resolution decisions already live in IR.resolved (Phase 3).

local M = {}

local mappings = require("toolchain.mappings")
local util = require("core.kernel.util")

local BASE_TOOLS = { "codespell" }

--- Safe nested table get (replaces vim.tbl_get).
---@param t table
---@param ... string
---@return any
local function tget(t, ...)
  local cur = t
  for _, k in ipairs({ ... }) do
    if type(cur) ~= "table" then return nil end
    cur = cur[k]
  end
  return cur
end

--- Shallow-copy a list.
---@param t any[]
---@return any[]
local function list_copy(t)
  local out = {}
  for i, v in ipairs(t) do out[i] = v end
  return out
end
---@param ir table  LIR or SPEC-ready IR
---@return table[]  LazySpec[]
function M.build(ir)
  if not ir.caps then
    return { { _ltos_error = "[ltos:mason] IR missing required field: caps" } }
  end

  local raw = list_copy(BASE_TOOLS)

  -- LSP servers — package names come exclusively from mappings.lsp_pkg()
  for server, _ in pairs(ir.merged_lsp or {}) do
    local want_mason = tget(ir, "resolved", "lsp", server)
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
          local want = tget(ir, "resolved", "tools", t)
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
