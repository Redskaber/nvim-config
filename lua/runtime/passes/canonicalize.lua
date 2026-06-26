-- lua/runtime/passes/canonicalize.lua
-- Compiler kernel: Phase 2.5 — canonicalize (TODO-0.2).
--
-- Symbol Canonicalization: resolves every LSP server name and tool name
-- to its canonical mason package name at compile time.
-- Produces a symbol table on the IR so all downstream phases read from
-- a single source of truth instead of calling mappings at runtime.
--
-- State contract: NORMALIZING → CANONICALIZING  (HIR in, HIR+ out, adds ir.symbols)
-- IR input:  HIR layer (caps with FormatterNode.fn injected)
-- IR output: HIR layer + ir.symbols (canonical symbol table)
--
-- ir.symbols schema:
--   ir.symbols.lsp[server]  = { mason = "pkg-name" | nil, system = bool }
--   ir.symbols.tools[tool]  = { mason = "pkg-name" | nil, system = bool }
--
-- Downstream consumers (resolve, mason adapter) read ONLY ir.symbols.
-- No adapter or pass may call mappings.lsp_pkg() / mappings.tool_pkg() directly.

local build_request_mod = require("runtime.build_request")
local ir_mod = require("core.compiler.ir")
local mappings = require("toolchain.mappings")
local rules = require("toolchain.rules")
local ov = require("runtime.output_validate")

---@type Phase
local canonicalize_pass = {
  name = "canonicalize",
  input_state = "normalizing",
  output_state = "canonicalizing",

  validate = function(ir) return ir_mod.validate(ir, "canonicalize") end,

  -- P6-D2 (2026-06-26): post-condition — output must have caps + meta + symbols
  output_validate = ov.canonicalize,

  ---@param ir IR
  ---@return IR
  run = function(ir)
    local req = (ir.meta and ir.meta.build_request) or {}
    local overrides = req.overrides or {}
    local ctx = build_request_mod.rules_ctx(req)

    local symbols = { lsp = {}, tools = {} }
    local diags = {}

    for _, cap in pairs(ir.caps) do
      -- ── LSP servers ──────────────────────────────────────────────────────
      for server, _ in pairs(cap.lsp or {}) do
        if not symbols.lsp[server] then
          local pkg = mappings.lsp_to_mason[server]
          -- pkg == nil means identity (server name == mason pkg name)
          -- We still record it so adapters never need to call mappings
          local resolved_pkg = pkg or server
          local is_system = mappings.system_tools[server] == true
          symbols.lsp[server] = {
            mason = is_system and nil or resolved_pkg,
            system = is_system,
          }
          if not pkg and not is_system then
            -- Identity mapping: warn so maintainers know to add explicit entry
            diags[#diags + 1] = ir_mod.diag(
              "canonicalize",
              "lsp." .. server,
              "no explicit lsp_to_mason entry — using identity: " .. server,
              "info"
            )
          end
        end
      end

      -- ── Formatter tools ───────────────────────────────────────────────────
      for _, fmts in pairs(cap.formatters or {}) do
        for _, v in ipairs(fmts) do
          if type(v) == "string" then
            if not symbols.tools[v] then
              local res = rules.resolve(v, overrides, ctx)
              symbols.tools[v] = { mason = res.pkg, system = not res.use_mason }
            end
          elseif type(v) == "table" and v.name then
            local tool = v.name
            if not symbols.tools[tool] then
              local res = rules.resolve(tool, overrides, ctx)
              symbols.tools[tool] = { mason = res.pkg, system = not res.use_mason }
            end
          end
        end
      end

      -- ── Linter tools ──────────────────────────────────────────────────────
      for _, lints in pairs(cap.linters or {}) do
        for _, tool in ipairs(lints) do
          if type(tool) == "string" and not symbols.tools[tool] then
            local res = rules.resolve(tool, overrides, ctx)
            symbols.tools[tool] = { mason = res.pkg, system = not res.use_mason }
          end
        end
      end

      -- ── Explicit mason[] list ─────────────────────────────────────────────
      for _, t in ipairs(cap.mason or {}) do
        if not symbols.tools[t] then
          local res = rules.resolve(t, overrides, ctx)
          symbols.tools[t] = { mason = res.pkg, system = not res.use_mason }
        end
      end
    end

    local next_ir = ir_mod.with(ir, { symbols = symbols })
    for _, d in ipairs(diags) do
      next_ir = ir_mod.append_diag(next_ir, d)
    end
    return next_ir
  end,
}

return canonicalize_pass