-- ~/.config/nvim/lua/runtime/adapters/mason.lua
-- Auto-derives mason ensure_installed from ALL capability declarations.
-- Single source of truth: no more duplicated lists across lang files.

local M = {}
local tc = require("core.toolchain")

---@param caps table<string, Capability>
---@return table[]
function M.build(caps)
  local seen = {}
  local tools = {}

  -- Collect tools from lsp servers (auto-derive mason package from server name)
  for _, cap in pairs(caps) do
    if cap.lsp then
      for server, config in pairs(cap.lsp) do
        -- If mason field is explicitly false, skip; nil = auto-resolve
        local should_mason = (config.mason == nil) and tc.use_mason(server) or config.mason
        if should_mason and not seen[server] then
          -- Map common LSP server names to mason package names
          local pkg = ({
            lua_ls = "lua-language-server",
            rust_analyzer = "rust-analyzer",
            nil_ls = "nil",
          })[server] or server
          tools[#tools + 1] = pkg
          seen[pkg] = true
        end
      end
    end

    -- Explicit mason extras from each capability
    if cap.mason then
      for _, t in ipairs(cap.mason) do
        if t ~= "" and not seen[t] and tc.use_mason(t) then
          tools[#tools + 1] = t
          seen[t] = true
        end
      end
    end

    -- Formatters: derive mason packages for known formatters
    if cap.formatters then
      for _, fmts in pairs(cap.formatters) do
        for _, f in ipairs(fmts) do
          if f ~= "__ruff_or_black__" and not seen[f] and tc.use_mason(f) then
            tools[#tools + 1] = f
            seen[f] = true
          end
        end
      end
    end

    -- Linters: derive mason packages for known linters
    if cap.linters then
      for _, lnts in pairs(cap.linters) do
        for _, l in ipairs(lnts) do
          -- fish linter is the fish binary itself, not a mason package
          if l ~= "fish" and not seen[l] and tc.use_mason(l) then
            tools[#tools + 1] = l
            seen[l] = true
          end
        end
      end
    end
  end

  -- Always include base tools
  local base = { "codespell" }
  for _, t in ipairs(base) do
    if not seen[t] then
      tools[#tools + 1] = t
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
