-- ~/.config/nvim/lua/runtime/adapters/mason.lua
-- Pure function: ctx → mason ensure_installed spec.
-- Resolution decisions already live in ctx.resolved (pipeline stage 3).

local M = {}

local mappings = require("toolchain.mappings")

local BASE_TOOLS = { "codespell" }

---@param ctx table
---@return table[]
function M.build(ctx)
  if not ctx.caps then
    vim.notify("[ltos:mason] IR missing required field: caps", vim.log.levels.WARN)
    return {}
  end
  local seen = {}
  local tools = {}

  local function add(pkg)
    if pkg and pkg ~= "" and not seen[pkg] then
      tools[#tools + 1] = pkg
      seen[pkg] = true
    end
  end

  -- Base tools always included
  for _, t in ipairs(BASE_TOOLS) do
    add(t)
  end

  -- LSP servers — package names come exclusively from mappings.lsp_pkg()
  for server, _ in pairs(ctx.merged_lsp or {}) do
    local want_mason = vim.tbl_get(ctx, "resolved", "lsp", server)
    if want_mason then
      add(mappings.lsp_pkg(server))
    end
  end

  -- Build a set of known LSP mason package names to exclude from cap.mason.
  -- This ensures LSP packages are never double-counted even if a lang module
  -- still lists them (Requirement 17.3: dedup via seen, no error).
  local lsp_pkgs = {}
  for _, pkg in pairs(mappings.lsp_to_mason) do
    lsp_pkgs[pkg] = true
  end

  -- Formatters & linters (via explicit mason lists on each cap).
  -- LSP package names are skipped here; they are sourced via lsp_pkg() above.
  for _, cap in pairs(ctx.caps) do
    if cap.mason then
      for _, t in ipairs(cap.mason) do
        if not lsp_pkgs[t] then
          local pkg = mappings.tool_pkg(t)
          local want = vim.tbl_get(ctx, "resolved", "tools", t)
          if want and pkg then
            add(pkg)
          end
        end
      end
    end
  end

  return {
    {
      "mason-org/mason.nvim",
      opts = { ensure_installed = tools },
      _source = "ltos:mason",
    },
  }
end

return M
