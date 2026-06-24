-- spec/core/ext_schema_spec.lua
-- core.domain.ext_schema: cap_type DSL validator for all known cap types.

local R = require("spec._runner")

R.describe("core.domain.ext_schema", function()
  local ext = require("core.domain.ext_schema")
  local FC = require("spec._fixtures.caps")

  local function ok(cap_type, cap, msg)
    local r = ext.validate(cap_type, "mod", cap)
    R.assert_true(r.ok, (msg or "expected ok") .. ": " .. ext.format_diags(r.diags))
  end

  local function err(cap_type, cap, pattern)
    local r = ext.validate(cap_type, "mod", cap)
    R.assert_false(r.ok, "expected failure for cap_type=" .. cap_type)
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

  local function warns(cap_type, cap, pattern)
    local r = ext.validate(cap_type, "mod", cap)
    R.assert_true(r.ok, "expected ok (warn only)")
    local found = false
    for _, d in ipairs(r.diags) do
      if
        d.severity == "warn"
        and ((d.message or ""):find(pattern, 1, true) or (d.path or ""):find(pattern, 1, true))
      then
        found = true
        break
      end
    end
    R.assert_true(found, "expected warn matching: " .. pattern)
  end

  -- ── dispatch ──────────────────────────────────────────────────────────────

  R.describe("dispatch", function()
    R.it("unknown cap_type → ok=false", function() err("bogus", {}, "unknown cap_type") end)
    R.it("non-table cap → ok=false", function()
      local r = ext.validate("image", "mod", "not_a_table")
      R.assert_false(r.ok)
    end)
  end)

  -- ── known_cap_types() ─────────────────────────────────────────────────────

  R.it("known_cap_types() includes all five types", function()
    local types = ext.known_cap_types()
    local set = {}
    for _, t in ipairs(types) do
      set[t] = true
    end
    for _, expected in ipairs({ "image", "media", "ai", "keybind", "editor" }) do
      R.assert_true(set[expected], "missing: " .. expected)
    end
  end)

  -- ── image ─────────────────────────────────────────────────────────────────

  R.describe("image", function()
    R.it("valid cap passes", function() ok("image", FC.image_cap()) end)
    R.it(
      "missing backend/backends → warn",
      function() warns("image", { version = 1, cap_type = "image" }, "backend") end
    )
    R.it(
      "unknown single backend → error",
      function()
        err(
          "image",
          { version = 1, cap_type = "image", backend = "xterm_ultra" },
          "unknown backend"
        )
      end
    )
    R.it(
      "unknown fallback → warn",
      function() warns("image", FC.image_cap({ fallback = "xterm_unknown" }), "fallback") end
    )
    R.it(
      "non-number max_width → warn",
      function() warns("image", FC.image_cap({ max_width = "100" }), "max_width") end
    )
    R.it(
      "non-string in filetypes → error",
      function() err("image", FC.image_cap({ filetypes = { "png", 42 } }), "expected string") end
    )
    R.it(
      "non-list backends → error",
      function()
        err("image", { version = 1, cap_type = "image", backends = "kitty" }, "expected list")
      end
    )
  end)

  -- ── media ─────────────────────────────────────────────────────────────────

  R.describe("media", function()
    R.it("valid cap passes", function() ok("media", FC.media_cap()) end)
    R.it(
      "non-list viewers → error",
      function() err("media", { version = 1, cap_type = "media", viewers = "bad" }, "expected list") end
    )
    R.it(
      "empty viewers → error",
      function() err("media", { version = 1, cap_type = "media", viewers = {} }, "non-empty") end
    )
    R.it(
      "viewer missing kind → error",
      function()
        err("media", { version = 1, cap_type = "media", viewers = { { plugin = "p" } } }, "kind")
      end
    )
    R.it(
      "viewer missing plugin → error",
      function()
        err("media", { version = 1, cap_type = "media", viewers = { { kind = "pdf" } } }, "plugin")
      end
    )
    R.it(
      "unknown viewer kind → warn",
      function()
        warns("media", {
          version = 1,
          cap_type = "media",
          viewers = { { kind = "hologram", plugin = "h.nvim" } },
        }, "kind")
      end
    )
  end)

  -- ── ai ────────────────────────────────────────────────────────────────────

  R.describe("ai", function()
    R.it("valid cap with completion+chat passes", function() ok("ai", FC.ai_cap()) end)
    R.it("empty ai cap is ok (no-op, but valid)", function()
      local r = ext.validate("ai", "mod", { version = 1, cap_type = "ai" })
      R.assert_true(r.ok)
    end)
    R.it(
      "unknown completion provider → warn",
      function()
        warns(
          "ai",
          { version = 1, cap_type = "ai", completion = { provider = "gpt_ultra" } },
          "provider"
        )
      end
    )
    R.it(
      "non-table completion → error",
      function()
        err("ai", { version = 1, cap_type = "ai", completion = "copilot" }, "expected table")
      end
    )
    R.it(
      "unknown chat adapter → warn",
      function()
        warns("ai", {
          version = 1,
          cap_type = "ai",
          chat = { provider = "codecompanion", adapter = "grok_unknown" },
        }, "adapter")
      end
    )
    R.it(
      "plugin entry missing name → error",
      function()
        err("ai", {
          version = 1,
          cap_type = "ai",
          plugins = { { cmd = { "Copilot" } } },
        }, "name")
      end
    )
  end)

  -- ── keybind ───────────────────────────────────────────────────────────────

  R.describe("keybind", function()
    R.it("valid cap passes", function() ok("keybind", FC.keybind_cap()) end)
    R.it(
      "no preset/groups/bindings → error",
      function() err("keybind", { version = 1, cap_type = "keybind" }, "must define") end
    )
    R.it(
      "unknown preset → warn",
      function()
        warns("keybind", { version = 1, cap_type = "keybind", preset = "dvorak_ultra" }, "preset")
      end
    )
    R.it(
      "known preset helix → ok",
      function() ok("keybind", { version = 1, cap_type = "keybind", preset = "helix" }) end
    )
    R.it(
      "group missing prefix → error",
      function()
        err(
          "keybind",
          { version = 1, cap_type = "keybind", groups = { { name = "git" } } },
          "prefix"
        )
      end
    )
    R.it(
      "group missing name → error",
      function()
        err(
          "keybind",
          { version = 1, cap_type = "keybind", groups = { { prefix = "<leader>g" } } },
          "name"
        )
      end
    )
    R.it(
      "non-list groups → error",
      function()
        err("keybind", { version = 1, cap_type = "keybind", groups = "bad" }, "expected list")
      end
    )
    R.it(
      "binding missing lhs → error",
      function()
        err("keybind", {
          version = 1,
          cap_type = "keybind",
          bindings = { { rhs = "cmd" } },
        }, "lhs")
      end
    )
    R.it(
      "binding missing rhs → error",
      function()
        err("keybind", {
          version = 1,
          cap_type = "keybind",
          bindings = { { lhs = "<leader>x" } },
        }, "rhs")
      end
    )
  end)

  -- ── format_diags() ────────────────────────────────────────────────────────

  R.it(
    "format_diags() returns empty string for no diags",
    function() R.assert_eq(ext.format_diags({}), "") end
  )

  -- ── DSL module purity (Invariant 8) ───────────────────────────────────────

  R.describe("DSL module purity (Invariant 8)", function()
    local cap_mods = {
      "modules.cap.image",
      "modules.cap.media",
      "modules.cap.ai",
      "modules.cap.keybind",
    }
    for _, mod in ipairs(cap_mods) do
      R.it(mod .. ": returns plain table (no metatable)", function()
        local _, m = pcall(require, mod)
        R.assert_type(m, "table")
        R.assert_nil(getmetatable(m))
        R.assert_type(m.version, "number")
        R.assert_type(m.cap_type, "string")
        R.assert_true(m.cap_type ~= "")
      end)
      R.it(mod .. ": passes ext_schema validation", function()
        local ok_m, m = pcall(require, mod)
        R.assert_true(ok_m)
        local r = ext.validate(m.cap_type, mod, m)
        R.assert_true(r.ok, mod .. " DSL failed schema: " .. ext.format_diags(r.diags))
      end)
    end
  end)
end)

