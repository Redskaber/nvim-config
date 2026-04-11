-- ~/.config/nvim/lua/toolchain/strategies/formatters.lua
-- Built-in FormatterStrategy implementations.
-- Registered into the strategy registry on module load.

local strategies = require("toolchain.strategies")

-- ruff_or_black: prefer ruff_format; fall back to isort + black
strategies.register("ruff_or_black", function(bufnr)
  local ok, conform = pcall(require, "conform")
  if ok and conform.get_formatter_info("ruff_format", bufnr).available then
    return { "ruff_format" }
  end
  return { "isort", "black" }
end)

-- prettierd_or_prettier: prefer prettierd; fall back to prettier
strategies.register("prettierd_or_prettier", function(bufnr)
  local ok, conform = pcall(require, "conform")
  if ok and conform.get_formatter_info("prettierd", bufnr).available then
    return { "prettierd" }
  end
  return { "prettier" }
end)
