-- spec/core/schema_spec.lua
-- core.domain.schema: DSL capability validator.

local R = require("spec._runner")

R.describe("core.domain.schema", function()
  local schema = require("core.domain.schema")

  local function ok(cap, msg)
    local r = schema.validate("x", cap)
    R.assert_true(r.ok, (msg or "expected ok") .. ": " .. vim.inspect(r.diags))
  end

  local function err(cap, pattern, msg)
    local r = schema.validate("x", cap)
    R.assert_false(r.ok, msg or "expected failure")
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

  R.it("validates empty cap", function()
    ok({})
  end)
  R.it("accepts valid lsp entry", function()
    ok({ lsp = { lua_ls = { settings = {} } } })
  end)
  R.it("rejects non-table lsp server config", function()
    err({ lsp = { bad = "string" } }, "expected table")
  end)
  R.it("rejects raw function formatter", function()
    err({ formatters = {
      python = function()
        return {}
      end,
    } }, "raw function")
  end)
  R.it("rejects sentinel string", function()
    err({ formatters = { lua = { "__STRATEGY__" } } }, "sentinel")
  end)
  R.it("accepts plain string formatter", function()
    ok({ formatters = { lua = { "stylua" } } })
  end)
  R.it("accepts FormatterNode with strategy", function()
    ok({ formatters = { py = { { kind = "formatter", strategy = "ruff_or_black" } } } })
  end)
  R.it("rejects FormatterNode with fn in source", function()
    err({ formatters = { py = { { kind = "formatter", fn = function() end } } } }, "fn")
  end)
  R.it("rejects unknown node kind", function()
    err({ formatters = { go = { { kind = "unknown" } } } }, "unknown node kind")
  end)
  R.it("accepts treesitter string list", function()
    ok({ treesitter = { "lua", "python" } })
  end)
  R.it("rejects non-string in treesitter list", function()
    err({ treesitter = { "lua", 42 } }, "expected string")
  end)
  R.it("rejects empty string in mason list", function()
    local r = schema.validate("x", { mason = { "stylua", "" } })
    R.assert_true(not r.ok or #r.diags > 0)
  end)
  R.it("accepts valid linter list", function()
    ok({ linters = { python = { "ruff" } } })
  end)
  R.it("rejects non-string linter entry", function()
    err({ linters = { python = { { kind = "formatter" } } } }, "linter entries")
  end)

  -- version compatibility (TODO-6.1)
  R.describe("version compatibility", function()
    R.it("version=1 accepted silently", function()
      ok({ version = 1 })
    end)
    R.it("version=0 (older) accepted silently", function()
      ok({ version = 0 })
    end)
    R.it("version=99 (future) → warn", function()
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
  end)

  R.it("all diagnostics have non-empty code field", function()
    local r = schema.validate("x", { lsp = { bad = "string" } })
    R.assert_true(#r.diags > 0)
    for _, d in ipairs(r.diags) do
      R.assert_type(d.code, "string")
      R.assert_true(#d.code > 0)
      R.assert_match(d.code, "^S%d+")
    end
  end)
end)
