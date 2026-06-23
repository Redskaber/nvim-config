-- spec/core/types_spec.lua
-- core.compiler.types: Dependency Inversion abstraction layer.
-- core.domain.cap_types: capability type enum.
-- core.domain.icons: icon table integrity.

local R = require("spec._runner")

-- ── core.compiler.types (DIP: L1 abstract interface) ─────────────────────────

R.describe("core.compiler.types", function()
  local types = require("core.compiler.types")

  -- ── API surface ───────────────────────────────────────────────────────────

  R.describe("public API surface", function()
    R.it("diag() function exists", function()
      R.assert_type(types.diag, "function")
    end)
    R.it("error() alias exists", function()
      R.assert_type(types.error, "function")
    end)
    R.it("format_diagnostic() exists", function()
      R.assert_type(types.format_diagnostic, "function")
    end)
    R.it("cap_types() returns table", function()
      R.assert_type(types.cap_types(), "table")
    end)
    R.it("configure() exists", function()
      R.assert_type(types.configure, "function")
    end)
    R.it("is_cap_type_known() exists", function()
      R.assert_type(types.is_cap_type_known, "function")
    end)
    R.it("cap_types_set() exists", function()
      R.assert_type(types.cap_types_set, "function")
    end)
  end)

  -- ── after runtime.types_bootstrap.setup() ────────────────────────────────

  R.describe("after types_bootstrap injection", function()
    -- types_bootstrap is called in ltos_tests.lua before all specs
    R.it("diag() produces a valid Diagnostic (injected factory works)", function()
      local d = types.diag("collect", "mod.a", "test message", "error")
      R.assert_type(d, "table")
      R.assert_eq(d.stage, "collect")
      R.assert_eq(d.node, "mod.a")
      R.assert_eq(d.message, "test message")
      R.assert_eq(d.severity, "error")
      R.assert_type(d.code, "string")
      R.assert_true(#d.code > 0)
    end)

    R.it("error() alias produces same result as diag()", function()
      local d1 = types.diag("s", "n", "m", "error")
      local d2 = types.error("s", "n", "m", "error")
      R.assert_eq(d1.code, d2.code)
    end)

    R.it("format_diagnostic() returns non-empty string", function()
      local d = types.diag("collect", "mod", "error msg", "error")
      local out = types.format_diagnostic(d)
      R.assert_type(out, "string")
      R.assert_true(#out > 0)
    end)

    R.it("cap_types() returns table with all five type constants", function()
      local ct = types.cap_types()
      for _, key in ipairs({ "IMAGE", "MEDIA", "AI", "KEYBIND", "EDITOR" }) do
        R.assert_type(ct[key], "string", "cap_types()." .. key .. " must be string")
      end
    end)

    R.it("is_cap_type_known() returns true for known types", function()
      R.assert_true(types.is_cap_type_known("image"))
      R.assert_true(types.is_cap_type_known("media"))
      R.assert_true(types.is_cap_type_known("ai"))
      R.assert_true(types.is_cap_type_known("keybind"))
      R.assert_true(types.is_cap_type_known("editor"))
    end)

    R.it("is_cap_type_known() returns false for unknown type", function()
      R.assert_false(types.is_cap_type_known("unknown_type_xyz"))
    end)

    R.it("cap_types_set() returns set table for O(1) lookup", function()
      local set = types.cap_types_set()
      R.assert_type(set, "table")
      R.assert_true(set["image"] == true)
      R.assert_true(set["ai"] == true)
      R.assert_nil(set["nonexistent"])
    end)
  end)

  -- ── configure() idempotency (DIP wiring) ─────────────────────────────────

  R.describe("configure() idempotency", function()
    R.it("re-calling configure() does not break diag()", function()
      local diag_mod = require("core.domain.diagnostic")
      local ct = require("core.domain.cap_types")
      types.configure({
        diagnostic_factory = {
          new = diag_mod.new,
          diag = diag_mod.diag,
          format = diag_mod.format,
        },
        cap_types = ct,
      })
      -- Must still work after re-configuration
      local d = types.diag("s", "n", "m", "warn")
      R.assert_eq(d.severity, "warn")
    end)
  end)
end)

-- ── core.domain.cap_types ─────────────────────────────────────────────────────

R.describe("core.domain.cap_types", function()
  local ct = require("core.domain.cap_types")

  -- ── constants ────────────────────────────────────────────────────────────

  R.describe("type constants", function()
    R.it("IMAGE = 'image'", function()
      R.assert_eq(ct.IMAGE, "image")
    end)
    R.it("MEDIA = 'media'", function()
      R.assert_eq(ct.MEDIA, "media")
    end)
    R.it("AI = 'ai'", function()
      R.assert_eq(ct.AI, "ai")
    end)
    R.it("KEYBIND = 'keybind'", function()
      R.assert_eq(ct.KEYBIND, "keybind")
    end)
    R.it("EDITOR = 'editor'", function()
      R.assert_eq(ct.EDITOR, "editor")
    end)
  end)

  -- ── ALL list ──────────────────────────────────────────────────────────────

  R.describe("ALL list", function()
    R.it("has exactly 5 entries", function()
      R.assert_eq(#ct.ALL, 5)
    end)
    R.it("contains all five type strings", function()
      local set = {}
      for _, v in ipairs(ct.ALL) do
        set[v] = true
      end
      for _, key in ipairs({ "image", "media", "ai", "keybind", "editor" }) do
        R.assert_true(set[key], key .. " must be in ALL")
      end
    end)
    R.it("order is deterministic (same between requires)", function()
      local ct2 = require("core.domain.cap_types")
      for i, v in ipairs(ct.ALL) do
        R.assert_eq(v, ct2.ALL[i])
      end
    end)
  end)

  -- ── is_known() ────────────────────────────────────────────────────────────

  R.describe("is_known()", function()
    R.it("returns true for all known types", function()
      for _, t in ipairs(ct.ALL) do
        R.assert_true(ct.is_known(t), t .. " must be known")
      end
    end)
    R.it("returns false for unknown type", function()
      R.assert_false(ct.is_known("unknown_xyz"))
    end)
    R.it("returns false for nil", function()
      R.assert_false(ct.is_known(nil))
    end)
    R.it("returns false for empty string", function()
      R.assert_false(ct.is_known(""))
    end)
  end)

  -- ── as_set() ─────────────────────────────────────────────────────────────

  R.describe("as_set()", function()
    R.it("returns table with all known types as true", function()
      local s = ct.as_set()
      for _, t in ipairs(ct.ALL) do
        R.assert_true(s[t] == true, t .. " must be true in set")
      end
    end)
    R.it("set has exactly 5 entries", function()
      local s = ct.as_set()
      local cnt = 0
      for _ in pairs(s) do
        cnt = cnt + 1
      end
      R.assert_eq(cnt, 5)
    end)
    R.it("unknown key is absent (nil, not false)", function()
      local s = ct.as_set()
      R.assert_nil(s["unknown_xyz"])
    end)
    R.it("returns fresh table each call (independent)", function()
      local s1 = ct.as_set()
      local s2 = ct.as_set()
      s1["extra"] = true
      R.assert_nil(s2["extra"])
    end)
  end)

  -- ── no vim API ────────────────────────────────────────────────────────────

  R.it("module is pure data — no vim API calls on require", function()
    -- Just verify it loads without needing vim context
    package.loaded["core.domain.cap_types"] = nil
    local ok, m = pcall(require, "core.domain.cap_types")
    R.assert_true(ok, "cap_types must load in pure Lua context")
    R.assert_eq(#m.ALL, 5)
    -- restore
    package.loaded["core.domain.cap_types"] = ct
  end)
end)

-- ── core.domain.icons ────────────────────────────────────────────────────────

R.describe("core.domain.icons", function()
  local icons = require("core.domain.icons")

  -- ── structural integrity ──────────────────────────────────────────────────

  R.describe("top-level tables", function()
    R.it("has diagnostics table", function()
      R.assert_type(icons.diagnostics, "table")
    end)
    R.it("has git table", function()
      R.assert_type(icons.git, "table")
    end)
    R.it("has fold table", function()
      R.assert_type(icons.fold, "table")
    end)
    R.it("has todo table", function()
      R.assert_type(icons.todo, "table")
    end)
    R.it("has ft table", function()
      R.assert_type(icons.ft, "table")
    end)
    R.it("has file table", function()
      R.assert_type(icons.file, "table")
    end)
    R.it("has extension table", function()
      R.assert_type(icons.extension, "table")
    end)
  end)

  -- ── diagnostics ───────────────────────────────────────────────────────────

  R.describe("diagnostics icons", function()
    for _, key in ipairs({ "Error", "Warn", "Hint", "Info" }) do
      R.it(key .. " is non-empty string", function()
        R.assert_type(icons.diagnostics[key], "string")
        R.assert_true(#icons.diagnostics[key] > 0)
      end)
    end
  end)

  -- ── git ───────────────────────────────────────────────────────────────────

  R.describe("git icons", function()
    for _, key in ipairs({ "added", "modified", "removed" }) do
      R.it(key .. " is non-empty string", function()
        R.assert_type(icons.git[key], "string")
        R.assert_true(#icons.git[key] > 0)
      end)
    end
  end)

  -- ── todo ──────────────────────────────────────────────────────────────────

  R.describe("todo icons", function()
    for _, key in ipairs({ "FIX", "TODO", "HACK", "WARN", "PERF", "NOTE", "TEST" }) do
      R.it(key .. " is non-empty string", function()
        R.assert_type(icons.todo[key], "string")
        R.assert_true(#icons.todo[key] > 0)
      end)
    end
  end)

  -- ── ft coverage ───────────────────────────────────────────────────────────

  R.describe("ft icon coverage", function()
    local expected_fts = {
      "lua",
      "python",
      "rust",
      "go",
      "typescript",
      "javascript",
      "markdown",
      "yaml",
      "json",
      "sh",
      "c",
      "cpp",
    }
    for _, ft in ipairs(expected_fts) do
      R.it(ft .. " filetype icon exists", function()
        R.assert_type(icons.ft[ft], "string")
        R.assert_true(#icons.ft[ft] > 0)
      end)
    end
  end)

  -- ── extension coverage ───────────────────────────────────────────────────

  R.describe("extension icon coverage", function()
    local expected_exts = { "lua", "py", "rs", "go", "ts", "js", "md", "json", "png", "zip" }
    for _, ext in ipairs(expected_exts) do
      R.it("." .. ext .. " extension entry has glyph + hl", function()
        local e = icons.extension[ext]
        R.assert_not_nil(e, "extension." .. ext .. " must exist")
        R.assert_type(e.glyph, "string")
        R.assert_type(e.hl, "string")
        R.assert_true(#e.glyph > 0)
        R.assert_true(#e.hl > 0)
      end)
    end
  end)

  -- ── re-export via config/icons.lua ───────────────────────────────────────

  R.it("config.icons re-exports core.domain.icons identically", function()
    local config_icons = require("config.icons")
    R.assert_eq(config_icons.diagnostics, icons.diagnostics)
    R.assert_eq(config_icons.git, icons.git)
    R.assert_eq(config_icons.ft, icons.ft)
  end)
end)

-- ── core.domain.keybind_presets_data ─────────────────────────────────────────

R.describe("core.domain.keybind_presets_data", function()
  local kp = require("core.domain.keybind_presets_data")

  R.describe("constants", function()
    R.it("HELIX = 'helix'", function()
      R.assert_eq(kp.HELIX, "helix")
    end)
    R.it("VIM   = 'vim'", function()
      R.assert_eq(kp.VIM, "vim")
    end)
    R.it("EMACS = 'emacs'", function()
      R.assert_eq(kp.EMACS, "emacs")
    end)
  end)

  R.describe("ALL list", function()
    R.it("has 3 entries", function()
      R.assert_eq(#kp.ALL, 3)
    end)
    R.it("contains helix, vim, emacs", function()
      local set = {}
      for _, v in ipairs(kp.ALL) do
        set[v] = true
      end
      R.assert_true(set.helix)
      R.assert_true(set.vim)
      R.assert_true(set.emacs)
    end)
  end)

  R.describe("is_known()", function()
    R.it("true for helix/vim/emacs", function()
      R.assert_true(kp.is_known("helix"))
      R.assert_true(kp.is_known("vim"))
      R.assert_true(kp.is_known("emacs"))
    end)
    R.it("false for unknown", function()
      R.assert_false(kp.is_known("dvorak"))
    end)
    R.it("false for nil", function()
      R.assert_false(kp.is_known(nil))
    end)
  end)

  R.describe("as_set()", function()
    R.it("returns set with 3 entries", function()
      local s = kp.as_set()
      local cnt = 0
      for _ in pairs(s) do
        cnt = cnt + 1
      end
      R.assert_eq(cnt, 3)
    end)
    R.it("each known preset maps to true", function()
      local s = kp.as_set()
      R.assert_true(s.helix == true)
      R.assert_true(s.vim == true)
      R.assert_true(s.emacs == true)
    end)
  end)
end)