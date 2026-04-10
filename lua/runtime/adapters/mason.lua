-- ~/.config/nvim/lua/runtime/adapters/mason.lua
-- Pure function: ctx → mason ensure_installed spec.
-- Resolution decisions already live in ctx.resolved (pipeline stage 3).

local M = {}

local mappings = require("toolchain.mappings")

local BASE_TOOLS = { "codespell" }

---@param ctx table
---@return table[]
function M.build(ctx)
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

  -- LSP servers
  for server, cfg in pairs(ctx.merged_lsp or {}) do
    local want_mason = ctx.resolved and ctx.resolved.lsp[server]
    if want_mason then
      add(mappings.lsp_pkg(server))
    end
  end

  -- Formatters & linters (via explicit mason lists on each cap)
  for _, cap in pairs(ctx.caps) do
    if cap.mason then
      for _, t in ipairs(cap.mason) do
        local pkg = mappings.tool_pkg(t)
        local want = ctx.resolved and (ctx.resolved.tools[t] ~= false)
        if want and pkg then
          add(pkg)
        end
      end
    end
  end

  return {
    {
      "mason-org/mason.nvim",
      opts = { ensure_installed = tools },
    },
  }
end

return M
