-- lua/runtime/adapters/mason.lua
-- Backend layer: IR → mason-nvim LazySpec.
-- REFACTOR (TODO-0.2, TODO-5.4): reads ir.symbols for canonical package names.
-- No calls to mappings.lsp_pkg() — all decisions are pre-computed in canonicalize pass.

local M = {}

local util = require("core.kernel.util")

local DEFAULT_BASE_TOOLS = { "codespell" }

local function base_tools()
  local g = vim.g.ltos_base_mason_tools
  if type(g) == "table" then
    return g
  end
  return DEFAULT_BASE_TOOLS
end

--- Shallow-copy a list.
---@param t any[]
---@return any[]
local function list_copy(t)
  local out = {}
  for i, v in ipairs(t) do
    out[i] = v
  end
  return out
end

---@param ir table  LIR or SPEC-ready IR
---@return table[]  LazySpec[]
function M.build(ir)
  if not ir.caps then
    return { { _ltos_error = "[ltos:mason] IR missing required field: caps" } }
  end

  local raw = list_copy(base_tools())
  local seen = {}

  -- Use ir.symbols when available (post-canonicalize); fall back to ir.resolved
  local symbols = ir.symbols

  if symbols then
    -- ── LSP packages from ir.symbols.lsp ─────────────────────────────────
    for server, sym in pairs(symbols.lsp) do
      local want = ir.resolved and ir.resolved.lsp[server]
      if want and sym.mason and not seen[sym.mason] then
        seen[sym.mason] = true
        raw[#raw + 1] = sym.mason
      end
    end

    -- ── Tool packages from ir.symbols.tools ───────────────────────────────
    for tool, sym in pairs(symbols.tools) do
      local want = ir.resolved and ir.resolved.tools[tool]
      if want and sym.mason and not seen[sym.mason] then
        seen[sym.mason] = true
        raw[#raw + 1] = sym.mason
      end
    end
  else
    -- Fallback path (no canonicalize pass — should not happen in normal pipeline)
    local mappings = require("toolchain.mappings")
    local rules = require("toolchain.rules")
    local overrides = vim.g.ltos_tool_overrides
    if type(overrides) ~= "table" then
      overrides = {}
    end
    for server, _ in pairs(ir.merged_lsp or {}) do
      local want = ir.resolved and ir.resolved.lsp[server]
      if want then
        local pkg = mappings.lsp_pkg(server)
        if pkg and not seen[pkg] then
          seen[pkg] = true
          raw[#raw + 1] = pkg
        end
      end
    end
    for _, cap in pairs(ir.caps) do
      -- explicit mason[] list
      for _, t in ipairs(cap.mason or {}) do
        local want = ir.resolved and ir.resolved.tools[t]
        if want and not seen[t] then
          seen[t] = true
          raw[#raw + 1] = t
        end
      end
      -- formatter tools
      for _, fmts in pairs(cap.formatters or {}) do
        for _, v in ipairs(fmts) do
          local tool = type(v) == "string" and v or (type(v) == "table" and v.name)
          if tool then
            local want = ir.resolved and ir.resolved.tools[tool]
            local res = rules.resolve(tool, overrides)
            if want and res.use_mason and res.pkg and not seen[res.pkg] then
              seen[res.pkg] = true
              raw[#raw + 1] = res.pkg
            end
          end
        end
      end
      -- linter tools
      for _, lints in pairs(cap.linters or {}) do
        for _, tool in ipairs(lints) do
          if type(tool) == "string" then
            local want = ir.resolved and ir.resolved.tools[tool]
            local res = rules.resolve(tool, overrides)
            if want and res.use_mason and res.pkg and not seen[res.pkg] then
              seen[res.pkg] = true
              raw[#raw + 1] = res.pkg
            end
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
