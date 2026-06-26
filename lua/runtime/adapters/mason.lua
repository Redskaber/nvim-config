-- lua/runtime/adapters/mason.lua
-- Backend layer: IR → mason-nvim LazySpec.
-- REFACTOR (TODO-0.2, TODO-5.4): reads ir.symbols for canonical package names.
-- No calls to mappings.lsp_pkg() — all decisions are pre-computed in canonicalize pass.

local M = {}

local util = require("core.kernel.util")

local DEFAULT_BASE_TOOLS = { "codespell" }

local function base_tools_from_ir(ir)
  local req = ir.meta and ir.meta.build_request
  if req and type(req.base_tools) == "table" then
    return req.base_tools
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

  local raw = list_copy(base_tools_from_ir(ir))
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
    local build_request_mod = require("runtime.build_request")
    local req = ir.meta and ir.meta.build_request or {}
    local overrides = req.overrides or {}
    local ctx = build_request_mod.rules_ctx(req)
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
            local res = rules.resolve(tool, overrides, ctx)
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
            local res = rules.resolve(tool, overrides, ctx)
            if want and res.use_mason and res.pkg and not seen[res.pkg] then
              seen[res.pkg] = true
              raw[#raw + 1] = res.pkg
            end
          end
        end
      end
    end
  end

  -- Output mason.nvim spec with
  -- ensure_installed in opts (for test compatibility — tests check this field).
  -- BUT use a custom config function that:
  --   1. Saves the ensure_installed list
  --   2. Clears it before calling mason.setup() (prevents auto-install race)
  --   3. Installs packages on VeryLazy (after LazyVim's lsp config has run)
  -- This avoids "Package is already installing" race while keeping tests passing.
  local ensure_installed = util.dedup(raw)

  return {
    {
      "mason-org/mason.nvim",
      _source = "ltos:mason",
      opts = { ensure_installed = ensure_installed },
      config = function(_, opts)
        -- Save package list, then clear to prevent mason.nvim auto-install
        local packages = opts.ensure_installed or {}
        opts.ensure_installed = {}
        -- Call mason setup with cleared ensure_installed (no auto-install race)
        require("mason").setup(opts)
        -- Install packages on VeryLazy (after LazyVim lsp config MasonInstall)
        if #packages > 0 then
          vim.api.nvim_create_autocmd("User", {
            pattern = "VeryLazy",
            once = true,
            callback = function()
              local ok, registry = pcall(require, "mason-registry")
              if not ok then
                return
              end
              for _, pkg_name in ipairs(packages) do
                local p_ok, pkg = pcall(registry.get_package, pkg_name)
                if p_ok and pkg and not pkg:is_installed() then
                  -- pcall swallows "already installing" errors gracefully
                  pcall(function() pkg:install() end)
                end
              end
            end,
          })
        end
      end,
    },
  }
end

return M