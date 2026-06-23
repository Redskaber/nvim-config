-- lua/toolchain/strategy/builtin.lua
-- Layer 3 strategy: built-in FormatterStrategy implementations.
-- Called by toolchain/strategy/registry.lua via M.bootstrap(registry).
-- Does NOT require("toolchain.strategy.registry") — avoids circular dependency.

local M = {}

--- Register all built-in formatter strategies into the given registry.
---@param registry { register: fun(strategy_or_name: Strategy|string, fn?: fun(bufnr: integer): string[]) }
function M.bootstrap(registry)
  -- ruff_or_black: prefer ruff_format; fall back to isort + black
  registry.register({
    name = "ruff_or_black",
    applies = function(tool)
      return tool == "ruff_or_black"
    end,
    resolve = function(bufnr)
      local ok, conform = pcall(require, "conform")
      if ok and conform.get_formatter_info("ruff_format", bufnr).available then
        return { "ruff_format" }
      end
      return { "isort", "black" }
    end,
    priority = 50,
  })

  -- prettierd_or_prettier: prefer prettierd; fall back to prettier
  registry.register({
    name = "prettierd_or_prettier",
    applies = function(tool)
      return tool == "prettierd_or_prettier"
    end,
    resolve = function(bufnr)
      local ok, conform = pcall(require, "conform")
      if ok and conform.get_formatter_info("prettierd", bufnr).available then
        return { "prettierd" }
      end
      return { "prettier" }
    end,
    priority = 50,
  })

  -- stylua_or_lua_format: prefer stylua (system); fall back to lua_format
  registry.register({
    name = "stylua_or_lua_format",
    applies = function(tool)
      return tool == "stylua_or_lua_format"
    end,
    resolve = function(bufnr)
      local ok, conform = pcall(require, "conform")
      if ok and conform.get_formatter_info("stylua", bufnr).available then
        return { "stylua" }
      end
      return { "lua_format" }
    end,
    priority = 50,
  })
end

return M