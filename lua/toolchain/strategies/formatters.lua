-- ~/.config/nvim/lua/toolchain/strategies/formatters.lua
-- Strategy layer: built-in FormatterStrategy implementations.
-- Called by toolchain/strategies/init.lua via M.bootstrap(registry).
-- Does NOT require("toolchain.strategies") — avoids circular dependency.

local M = {}

--- Register all built-in formatter strategies into the given registry.
---@param registry { register: fun(name: string, fn: fun(bufnr: integer): string[]) }
function M.bootstrap(registry)
  -- ruff_or_black: prefer ruff_format; fall back to isort + black
  registry.register("ruff_or_black", function(bufnr)
    local ok, conform = pcall(require, "conform")
    if ok and conform.get_formatter_info("ruff_format", bufnr).available then
      return { "ruff_format" }
    end
    return { "isort", "black" }
  end)

  -- prettierd_or_prettier: prefer prettierd; fall back to prettier
  registry.register("prettierd_or_prettier", function(bufnr)
    local ok, conform = pcall(require, "conform")
    if ok and conform.get_formatter_info("prettierd", bufnr).available then
      return { "prettierd" }
    end
    return { "prettier" }
  end)

  -- stylua_or_lua_format: prefer stylua (system); fall back to lua_format
  registry.register("stylua_or_lua_format", function(bufnr)
    local ok, conform = pcall(require, "conform")
    if ok and conform.get_formatter_info("stylua", bufnr).available then
      return { "stylua" }
    end
    return { "lua_format" }
  end)
end

return M
