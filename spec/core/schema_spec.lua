-- spec/core/schema_spec.lua
-- core.domain.schema: lang DSL capability validator.

local R = require("spec._runner")

R.describe("core.domain.schema", function()
  local schema = require("core.domain.schema")

  local function assert_ok(cap, msg)
    local r = schema.validate("x", cap)
    R.assert_true(r.ok, (msg or "expected ok") .. ": " .. vim.inspect(r.diags))
  end

  local function assert_err(cap, pattern, msg)
    local r = schema.validate("x", cap)
    R.assert_false(r.ok, msg or "expected failure for: " .. vim.inspect(cap))
    if pattern then
      local found = false
      for _, d in ipairs(r.diags) do
        if (d.message or ""):find(pattern, 1, true) or (d.path or ""):find(pattern, 1, true) then
          found = true
          break
        end
      end
      R.assert_true(found, "no diag matched pattern: " .. pattern)
    end
  end

  -- ── basic shape ───────────────────────────────────────────────────────────

  R.it("validates empty cap table → ok", function()
    assert_ok({})
  end)

  -- ── lsp ───────────────────────────────────────────────────────────────────

  R.describe("lsp", function()
    R.it("accepts valid lsp entry", function()
      assert_ok({ lsp = { lua_ls = { settings = {} } } })
    end)
    R.it("rejects non-table lsp server config", function()
      assert_err({ lsp = { bad = "string" } }, "expected table")
    end)
    R.it("rejects non-string lsp key", function()
      assert_err({ lsp = { [42] = {} } }, "non-empty string")
    end)
  end)

  -- ── formatters ────────────────────────────────────────────────────────────

  R.describe("formatters", function()
    R.it("accepts plain string formatter", function()
      assert_ok({ formatters = { lua = { "stylua" } } })
    end)
    R.it("accepts FormatterNode with strategy", function()
      assert_ok({ formatters = { py = { { kind = "formatter", strategy = "ruff_or_black" } } } })
    end)
    R.it("rejects raw function formatter", function()
      assert_err(
        { formatters = {
          python = function()
            return {}
          end,
        } },
        "raw function"
      )
    end)
    R.it("rejects sentinel string in formatter list", function()
      assert_err({ formatters = { lua = { "__STRATEGY__" } } }, "sentinel")
    end)
    R.it("rejects FormatterNode with fn present in source DSL", function()
      assert_err({ formatters = { py = { { kind = "formatter", fn = function() end } } } }, "fn")
    end)
    R.it("rejects unknown node kind", function()
      assert_err({ formatters = { go = { { kind = "unknown_kind" } } } }, "unknown node kind")
    end)
    R.it("rejects non-string/non-table entry in formatter list", function()
      assert_err({ formatters = { lua = { 42 } } }, "expected string or FormatterNode")
    end)
  end)

  -- ── linters ───────────────────────────────────────────────────────────────

  R.describe("linters", function()
    R.it("accepts valid linter list", function()
      assert_ok({ linters = { python = { "ruff" } } })
    end)
    R.it("rejects non-string linter entry", function()
      assert_err({ linters = { python = { { kind = "formatter" } } } }, "linter entries")
    end)
    R.it("rejects sentinel in linters", function()
      assert_err({ linters = { lua = { "__LINT__" } } }, "sentinel")
    end)
  end)

  -- ── treesitter ────────────────────────────────────────────────────────────

  R.describe("treesitter", function()
    R.it("accepts string list", function()
      assert_ok({ treesitter = { "lua", "python" } })
    end)
    R.it("rejects non-string entry", function()
      assert_err({ treesitter = { "lua", 42 } }, "expected string")
    end)
  end)

  -- ── mason ─────────────────────────────────────────────────────────────────

  R.describe("mason", function()
    R.it("accepts non-empty string list", function()
      assert_ok({ mason = { "stylua", "ruff" } })
    end)
    R.it("rejects empty string in mason list", function()
      local r = schema.validate("x", { mason = { "stylua", "" } })
      R.assert_true(not r.ok or #r.diags > 0)
    end)
  end)

  -- ── version compatibility ─────────────────────────────────────────────────

  R.describe("version compatibility", function()
    R.it("version=1 accepted silently", function()
      assert_ok({ version = 1 })
    end)
    R.it("version=0 (older) accepted silently", function()
      assert_ok({ version = 0 })
    end)
    R.it("version=99 (future) → ok=true with warn", function()
      local r = schema.validate("x", { version = 99 })
      R.assert_true(r.ok)
      local warned = false
      for _, d in ipairs(r.diags) do
        if d.severity == "warn" and (d.path or ""):find("version") then
          warned = true
          break
        end
      end
      R.assert_true(warned)
    end)
    R.it("non-number version → warn diag", function()
      local r = schema.validate("x", { version = "v1" })
      R.assert_true(#r.diags > 0)
    end)
  end)

  -- ── diagnostic codes ──────────────────────────────────────────────────────

  R.it("all diagnostics carry non-empty S-prefixed code", function()
    local r = schema.validate("x", { lsp = { bad = "string" } })
    R.assert_true(#r.diags > 0)
    for _, d in ipairs(r.diags) do
      R.assert_type(d.code, "string")
      R.assert_true(#d.code > 0)
      R.assert_match(d.code, "^S")
    end
  end)

  -- ── format_diags() ────────────────────────────────────────────────────────

  R.it("format_diags() returns empty string for no diags", function()
    R.assert_eq(schema.format_diags({}), "")
  end)
  R.it("format_diags() returns non-empty string for diags", function()
    local r = schema.validate("x", { lsp = { bad = "string" } })
    R.assert_true(#schema.format_diags(r.diags) > 0)
  end)
end)