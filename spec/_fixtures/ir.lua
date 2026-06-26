-- spec/_fixtures/ir.lua
-- Pure IR construction helpers.
-- No side-effects; all functions return fresh value objects.

local M = {}

local function ir_mod() return require("core.compiler.ir") end
local function util() return require("core.kernel.util") end

-- ── IR stage constructors ─────────────────────────────────────────────────────

--- Minimal AST IR (post-collect shape).
---@param caps? table<string, table>
---@param profile? string
---@return IR
function M.ast(caps, profile)
  local ir = ir_mod().new({}, profile or "full")
  ir.caps = caps or {}
  return ir
end

--- Minimal HIR (post-normalize).
---@param caps?    table
---@param symbols? IRSymbols
---@return IR
function M.hir(caps, symbols)
  local ir = M.ast(caps)
  ir.stage = "HIR"
  ir.symbols = symbols or { lsp = {}, tools = {} }
  return ir
end

--- Minimal MIR (post-resolve).
---@param caps?     table
---@param resolved? IRResolved
---@return IR
function M.mir(caps, resolved)
  local ir = M.hir(caps)
  ir.stage = "MIR"
  ir.resolved = resolved or { lsp = {}, tools = {} }
  return ir
end

--- Minimal LIR (post-optimize; codegen-ready).
---@param caps?       table
---@param resolved?   IRResolved
---@param merged_lsp? table
---@param parsers?    string[]
---@return IR
function M.lir(caps, resolved, merged_lsp, parsers)
  local ir = M.mir(caps, resolved)
  ir.stage = "LIR"
  ir.merged_lsp = merged_lsp or {}
  ir.all_parsers = parsers or {}
  ir.symbols = ir.symbols or { lsp = {}, tools = {} }
  return ir
end

--- LIR seeded with ext_caps buckets.
---@param ext_caps table<string, table>
---@return IR
function M.lir_with_caps(ext_caps)
  local ir = M.lir()
  for cap_type, bucket in pairs(ext_caps) do
    ir.ext_caps[cap_type] = bucket
  end
  return ir
end

-- ── Canonical capability fixtures ─────────────────────────────────────────────

function M.lua_cap()
  return {
    lsp = { lua_ls = { settings = { Lua = { workspace = { checkThirdParty = false } } } } },
    formatters = { lua = { "stylua" } },
    linters = { lua = { "luacheck" } },
    treesitter = { "lua", "luadoc", "luap" },
    mason = { "stylua" },
  }
end

function M.python_cap()
  return {
    lsp = { pyright = { settings = { pyright = { disableOrganizeImports = true } } } },
    formatters = { python = { { kind = "formatter", strategy = "ruff_or_black" } } },
    linters = { python = { "ruff" } },
    treesitter = { "python" },
    mason = { "ruff", "black", "isort" },
  }
end

function M.rust_cap()
  return {
    lsp = { rust_analyzer = { settings = { ["rust-analyzer"] = {} } } },
    formatters = { rust = { "rustfmt" } },
    linters = { rust = { "clippy" } },
    treesitter = { "rust", "toml" },
    mason = {},
  }
end

-- ── Phase execution helper ────────────────────────────────────────────────────

--- Run a phase against an IR, asserting no phase-level errors.
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