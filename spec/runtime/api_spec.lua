-- spec/runtime/api_spec.lua
-- Unit tests for runtime.api: user-facing facade.
-- Tests API surface, picker backend registration, lifecycle hooks,
-- and graceful degradation when plugins are not loaded.

local R = require("spec._runner")

R.describe("runtime.api", function()
  local api = require("runtime.api")

  -- ── API surface ───────────────────────────────────────────────────────

  R.describe("API surface", function()
    R.it("format is a function", function() R.assert_type(api.format, "function") end)
    R.it("find_files is a function", function() R.assert_type(api.find_files, "function") end)
    R.it("live_grep is a function", function() R.assert_type(api.live_grep, "function") end)
    R.it("buffers is a function", function() R.assert_type(api.buffers, "function") end)
    R.it("recent_files is a function", function() R.assert_type(api.recent_files, "function") end)
    R.it("help_tags is a function", function() R.assert_type(api.help_tags, "function") end)
    R.it("on_ready is a function", function() R.assert_type(api.on_ready, "function") end)
    R.it("on_lifecycle_change is a function", function() R.assert_type(api.on_lifecycle_change, "function") end)
    R.it("picker_register is a function", function() R.assert_type(api.picker_register, "function") end)
    R.it("picker_set_default is a function", function() R.assert_type(api.picker_set_default, "function") end)
  end)

  -- ── Namespaced tables ─────────────────────────────────────────────────

  R.describe("namespaced tables", function()
    R.it("diagnostics table exists", function() R.assert_type(api.diagnostics, "table") end)
    R.it("diagnostics.next is a function", function() R.assert_type(api.diagnostics.next, "function") end)
    R.it("diagnostics.prev is a function", function() R.assert_type(api.diagnostics.prev, "function") end)
    R.it("diagnostics.open is a function", function() R.assert_type(api.diagnostics.open, "function") end)
    R.it("diagnostics.list is a function", function() R.assert_type(api.diagnostics.list, "function") end)
    R.it("lsp table exists", function() R.assert_type(api.lsp, "table") end)
    R.it("terminal table exists", function() R.assert_type(api.terminal, "table") end)
  end)

  -- ── Picker backend registration ───────────────────────────────────────

  R.describe("picker_register()", function()
    R.it("registers a custom backend", function()
      api.picker_register("test_backend", {
        files = function() end,
        grep = function() end,
      })
      -- Should not error
      R.assert_true(true)
    end)

    R.it("rejects empty name", function()
      local ok = pcall(api.picker_register, "", {})
      R.assert_false(ok)
    end)

    R.it("rejects non-table backend", function()
      local ok = pcall(api.picker_register, "bad", "notatable")
      R.assert_false(ok)
    end)
  end)

  -- ── Graceful degradation ──────────────────────────────────────────────

  R.describe("graceful degradation", function()
    R.it("find_files does not crash when no picker available", function()
      -- In headless test env, no picker is loaded — should warn, not crash
      local ok = pcall(api.find_files)
      R.assert_true(ok, "find_files must not crash without a picker")
    end)

    R.it("live_grep does not crash when no picker available", function()
      local ok = pcall(api.live_grep)
      R.assert_true(ok, "live_grep must not crash without a picker")
    end)

    R.it("format does not crash when conform not loaded", function()
      -- In headless test env, conform is not loaded — falls back to vim.lsp.buf.format
      local ok = pcall(api.format)
      R.assert_true(ok, "format must not crash without conform")
    end)

    R.it("diagnostics.list does not crash", function()
      local ok = pcall(api.diagnostics.list)
      R.assert_true(ok, "diagnostics.list must not crash")
    end)
  end)

  -- ── on_ready ──────────────────────────────────────────────────────────

  R.describe("on_ready()", function()
    R.it("does not crash with a valid callback", function()
      local ok = pcall(api.on_ready, function() end)
      R.assert_true(ok)
    end)

    R.it("surfaces callback errors via pcall (not crash)", function()
      local ok = pcall(api.on_ready, function() error("test error") end)
      R.assert_true(ok, "on_ready must not propagate callback errors")
    end)
  end)

  -- ── on_lifecycle_change ───────────────────────────────────────────────

  R.describe("on_lifecycle_change()", function()
    R.it("does not crash with a valid callback", function()
      local ok = pcall(api.on_lifecycle_change, function() end)
      R.assert_true(ok)
    end)
  end)

  -- ── Picker with registered backend ────────────────────────────────────

  R.describe("picker with registered backend", function()
    R.it("calls the registered backend's method", function()
      local called = false
      api.picker_register("test_call_backend", {
        files = function() called = true end,
        grep = function() end,
        buffers = function() end,
        recent = function() end,
        help = function() end,
      })
      api.picker_set_default("test_call_backend")
      api.find_files()
      R.assert_true(called, "registered backend's files() must be called")
    end)
  end)
end)
