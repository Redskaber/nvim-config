-- lua/runtime/adapters/mason.lua
-- Backend layer: IR → mason-nvim LazySpec.
-- REFACTOR (TODO-0.2, TODO-5.4): reads ir.symbols for canonical package names.
-- No calls to mappings.lsp_pkg() — all decisions are pre-computed in canonicalize pass.

local M = {}

local util = require("core.kernel.util")
local build_request_mod = require("runtime.build_request")

local function base_tools_from_ir(ir)
  local req = ir.meta and ir.meta.build_request
  if req and type(req.base_tools) == "table" then
    return req.base_tools
  end
  return build_request_mod.DEFAULT_BASE_TOOLS
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

  -- Guard: the canonicalize pass always produces ir.symbols. If absent, the
  -- IR is malformed (or the pipeline was bypassed) — bail with an error spec
  -- rather than silently falling back to a stale mappings-driven path that
  -- duplicates canonicalize's logic (and has historically drifted from it).
  if not ir.symbols then
    return { { _ltos_error = "[ltos:mason] IR missing required field: symbols (canonicalize pass not run?)" } }
  end

  local raw = list_copy(base_tools_from_ir(ir))
  local seen = {}

  local symbols = ir.symbols

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

  -- Build the deduplicated ensure_installed list. mason.nvim itself does
  -- NOT install these (LazyVim disables mason's auto-install); the
  -- mason-tool-installer.nvim dependency handles deferred installation.
  --
  -- FIX-MASON-UNKNOWN-PKG (2026-07-15): Filter out packages that are not
  -- real mason registry packages. When rules.resolve() falls back to
  -- identity (use_mason=true, pkg=tool_name) for an unmapped tool, the
  -- tool name may not exist in mason-registry. mason-tool-installer.nvim
  -- calls registry.get_package(pkg) which THROWS "Cannot find package"
  -- for unknown names, crashing the LazyVim mason config function.
  --
  -- We maintain a Known Non-Mason Tools set — tools that are commonly
  -- declared in lang modules but are NOT mason packages. These are
  -- system binaries or tools installed outside mason.
  local NON_MASON_TOOLS = {
    nasmfmt = true,   -- NASM formatter, system binary only
    gasfmt = true,    -- GAS formatter, not a mason package
  }

  local filtered = {}
  for _, pkg in ipairs(util.dedup(raw)) do
    if not NON_MASON_TOOLS[pkg] then
      filtered[#filtered + 1] = pkg
    end
  end
  local ensure_installed = filtered

  -- mason.nvim spec: no custom config — defer to LazyVim's mason config.
  -- mason-tool-installer.nvim (a LazyVim-managed dependency) handles the
  -- deferred install of `ensure_installed` packages on VeryLazy, avoiding
  -- the "Package is already installing" race that the previous manual
  -- config was working around.
  -- `opts_extend = { "ensure_installed" }` lets LazyVim merge our list
  -- with any list it already maintains for mason.nvim.
  return {
    {
      "mason-org/mason.nvim",
      _source = "ltos:mason",
      opts_extend = { "ensure_installed" },
      opts = { ensure_installed = ensure_installed },
      dependencies = {
        "WhoIsSethDaniel/mason-tool-installer.nvim",
      },
    },
  }
end

return M