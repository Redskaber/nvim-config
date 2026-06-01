-- spec/_fixtures/ir.lua
-- Shared IR construction helpers for all spec modules.
-- No side effects; returns a pure fixture factory.

local ir_mod = require("core.compiler.ir")
local util = require("core.kernel.util")

local M = {}

--- Minimal AST IR (post-collect stage input shape)
---@param caps? table<string, table>
---@param profile? string
---@return IR
function M.ast(caps, profile)
  local ir = ir_mod.new({}, profile or "full")
  ir.caps = caps or {}
  ir.meta = util.merge(ir.meta, { lang_modules = {}, cache_key = "", started_at = 0 })
  return ir
end

--- Minimal HIR (post-normalize; has symbols placeholder for canonicalize input)
---@param caps?    table
---@param symbols? IRSymbols
function M.hir(caps, symbols)
  local ir = M.ast(caps)
  ir.stage = "HIR"
  ir.symbols = symbols or { lsp = {}, tools = {} }
  return ir
end

--- Minimal MIR (post-resolve)
---@param caps?     table
---@param resolved? IRResolved
function M.mir(caps, resolved)
  local ir = M.hir(caps)
  ir.stage = "MIR"
  ir.resolved = resolved or { lsp = {}, tools = {} }
  return ir
end

--- Minimal LIR (post-optimize; ready for codegen pre-condition)
---@param caps?       table
---@param resolved?   IRResolved
---@param merged_lsp? table
---@param parsers?    string[]
function M.lir(caps, resolved, merged_lsp, parsers)
  local ir = M.mir(caps, resolved)
  ir.stage = "LIR"
  ir.merged_lsp = merged_lsp or {}
  ir.all_parsers = parsers or {}
  ir.symbols = ir.symbols or { lsp = {}, tools = {} }
  return ir
end

--- LIR with ext_caps populated (for cap_resolve testing)
---@param ext_caps table<string, table>
function M.lir_with_caps(ext_caps)
  local ir = M.lir()
  for cap_type, bucket in pairs(ext_caps) do
    ir.ext_caps[cap_type] = bucket
  end
  return ir
end

--- Standard lua_lang capability table (canonical fixture)
function M.lua_lang_cap()
  return {
    lsp = { lua_ls = { settings = { Lua = { workspace = { checkThirdParty = false } } } } },
    formatters = { lua = { "stylua" } },
    linters = { lua = { "luacheck" } },
    treesitter = { "lua", "luadoc", "luap" },
    mason = { "stylua" },
  }
end

--- Standard python capability table
function M.python_cap()
  return {
    lsp = { pyright = { settings = { pyright = { disableOrganizeImports = true } } } },
    formatters = { python = { { kind = "formatter", strategy = "ruff_or_black" } } },
    linters = { python = { "ruff" } },
    treesitter = { "python" },
    mason = { "ruff", "black", "isort" },
  }
end

--- Standard rust capability table (system tools)
function M.rust_cap()
  return {
    lsp = { rust_analyzer = { settings = { ["rust-analyzer"] = {} } } },
    formatters = { rust = { "rustfmt" } },
    linters = { rust = { "clippy" } },
    treesitter = { "rust", "toml" },
    mason = {},
  }
end

--- Run a phase against an IR and assert no phase-level errors
---@param phase table
---@param ir    IR
---@return IR
function M.run_phase_ok(phase, ir)
  local pass_mod = require("core.compiler.pass")
  local next_ir, errs = pass_mod.run_phase(phase, ir)
  if #errs > 0 then
    error("phase " .. phase.name .. " produced unexpected errors: " .. vim.inspect(errs), 2)
  end
  return next_ir
end

return M
