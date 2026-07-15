-- spec/core/ports_spec.lua
-- Unit tests for core.compiler.ports: injectable IO abstraction.
-- Tests default behavior, configuration injection, path caching,
-- and ensure_cache_dir (libuv fs_mkdir).

local R = require("spec._runner")

R.describe("core.compiler.ports", function()
  local ports = require("core.compiler.ports")

  -- ── Default behavior (before configure) ───────────────────────────────
  -- NOTE: ltos_tests.lua calls ports_bootstrap.setup() before any spec runs,
  -- so ports are already configured when these tests execute. We test the
  -- "unconfigured" behavior by temporarily replacing with broken impls
  -- and restoring in after_each.

  R.describe("default behavior", function()
    R.after_each(function()
      require("runtime.ports_bootstrap").setup()
      ports._clear_path_cache()
    end)

    R.it("cache_dir returns a string", function()
      R.assert_type(ports.cache_dir(), "string")
    end)

    R.it("json_encode errors when replaced with broken impl", function()
      ports.configure({ json_encode = function(_) error("not configured") end })
      local ok = pcall(ports.json_encode, {})
      R.assert_false(ok, "json_encode must error when unconfigured")
    end)

    R.it("json_decode errors when replaced with broken impl", function()
      ports.configure({ json_decode = function(_) error("not configured") end })
      local ok = pcall(ports.json_decode, "{}")
      R.assert_false(ok, "json_decode must error when unconfigured")
    end)

    R.it("read_file returns nil for nonexistent path", function()
      R.assert_nil(ports.read_file("/nonexistent/path/that/does/not/exist"))
    end)

    R.it("resolve_runtime_file returns nil for nonexistent file", function()
      ports._clear_path_cache()
      local result = ports.resolve_runtime_file("nonexistent/module.lua")
      R.assert_nil(result)
    end)

    R.it("debug_cache returns a boolean", function()
      R.assert_type(ports.debug_cache(), "boolean")
    end)

    R.it("notify does not crash", function()
      local ok = pcall(ports.notify, vim.log.levels.INFO, "test message")
      R.assert_true(ok)
    end)

    R.it("ensure_cache_dir does not crash on empty string", function()
      local ok = pcall(ports.ensure_cache_dir, "")
      R.assert_true(ok)
    end)

    R.it("ensure_cache_dir does not crash on nil", function()
      local ok = pcall(ports.ensure_cache_dir, nil)
      R.assert_true(ok)
    end)
  end)

  -- ── configure() ───────────────────────────────────────────────────────

  R.describe("configure()", function()
    R.after_each(function()
      -- FIX (2026-07-15): Restore ports to bootstrap state (NOT broken defaults).
      -- Other suites (commands_spec, layer_boundary_spec, etc.) depend on
      -- ports_bootstrap having configured json_encode/decode/read_file/etc.
      -- Resetting to error-throwing defaults pollutes the shared ports module.
      require("runtime.ports_bootstrap").setup()
      ports._clear_path_cache()
    end)

    R.it("injects custom cache_dir", function()
      ports.configure({ cache_dir = function() return "/custom/cache" end })
      R.assert_eq(ports.cache_dir(), "/custom/cache")
    end)

    R.it("injects custom json_encode", function()
      ports.configure({ json_encode = function(t) return "encoded" end })
      R.assert_eq(ports.json_encode({}), "encoded")
    end)

    R.it("injects custom json_decode", function()
      ports.configure({ json_decode = function(s) return { decoded = true } end })
      local result = ports.json_decode("whatever")
      R.assert_true(result.decoded)
    end)

    R.it("injects custom read_file", function()
      ports.configure({ read_file = function(path) return "content of " .. path end })
      R.assert_eq(ports.read_file("/test"), "content of /test")
    end)

    R.it("injects custom debug_cache", function()
      ports.configure({ debug_cache = function() return true end })
      R.assert_true(ports.debug_cache())
    end)

    R.it("injects custom notify (captures calls)", function()
      local captured = nil
      ports.configure({ notify = function(level, msg) captured = { level, msg } end })
      ports.notify(vim.log.levels.WARN, "test notify")
      R.assert_not_nil(captured)
      R.assert_eq(captured[2], "test notify")
    end)

    R.it("ignores non-function values in configure", function()
      -- Should not crash, should silently ignore non-function values
      local ok = pcall(ports.configure, { cache_dir = "not a function" })
      R.assert_true(ok)
    end)

    R.it("clears path cache on configure", function()
      -- Prime the cache with default impl
      ports.resolve_runtime_file("test/primed.lua")
      -- Reconfigure — cache should be cleared
      ports.configure({ resolve_runtime_file = function(_) return "/new/path" end })
      local result = ports.resolve_runtime_file("test/primed.lua")
      R.assert_eq(result, "/new/path", "after configure, cached nil should not persist")
    end)
  end)

  -- ── Path caching (resolve_runtime_file memoization) ───────────────────

  R.describe("path caching", function()
    R.after_each(function()
      -- Restore bootstrap state
      require("runtime.ports_bootstrap").setup()
      ports._clear_path_cache()
    end)

    R.it("caches positive results", function()
      local call_count = 0
      ports.configure({
        resolve_runtime_file = function(rel)
          call_count = call_count + 1
          return "/resolved/" .. rel
        end,
      })
      ports._clear_path_cache()
      local r1 = ports.resolve_runtime_file("test/file.lua")
      local r2 = ports.resolve_runtime_file("test/file.lua")
      R.assert_eq(r1, r2, "same result both calls")
      R.assert_eq(call_count, 1, "underlying impl called only once (cached)")
    end)

    R.it("caches negative results (nil)", function()
      local call_count = 0
      ports.configure({
        resolve_runtime_file = function(_)
          call_count = call_count + 1
          return nil
        end,
      })
      ports._clear_path_cache()
      local r1 = ports.resolve_runtime_file("nonexistent.lua")
      local r2 = ports.resolve_runtime_file("nonexistent.lua")
      R.assert_nil(r1)
      R.assert_nil(r2)
      R.assert_eq(call_count, 1, "nil result cached — impl called only once")
    end)

    R.it("_clear_path_cache resets cache", function()
      local call_count = 0
      ports.configure({
        resolve_runtime_file = function(_)
          call_count = call_count + 1
          return "/path"
        end,
      })
      ports._clear_path_cache()
      ports.resolve_runtime_file("test/clear.lua")
      R.assert_eq(call_count, 1)
      ports._clear_path_cache()
      ports.resolve_runtime_file("test/clear.lua")
      R.assert_eq(call_count, 2, "after clear, impl called again")
    end)

    R.it("caches different paths independently", function()
      local call_count = 0
      ports.configure({
        resolve_runtime_file = function(rel)
          call_count = call_count + 1
          return "/" .. rel
        end,
      })
      ports._clear_path_cache()
      ports.resolve_runtime_file("a.lua")
      ports.resolve_runtime_file("b.lua")
      R.assert_eq(call_count, 2, "different paths = different cache entries")
    end)
  end)

  -- ── ensure_cache_dir ──────────────────────────────────────────────────

  R.describe("ensure_cache_dir", function()
    R.it("creates nested directory structure", function()
      local tmp = "/tmp/ltos_ports_test_" .. tostring(os.time())
      local nested = tmp .. "/a/b/c"
      ports.ensure_cache_dir(nested)
      local stat = vim.loop.fs_stat(nested)
      R.assert_not_nil(stat, "nested directory must be created")
      if stat then
        R.assert_eq(stat.type, "directory")
      end
      vim.fn.delete(tmp, "rf")
    end)

    R.it("is idempotent (calling twice does not error)", function()
      local tmp = "/tmp/ltos_ports_idem_" .. tostring(os.time())
      ports.ensure_cache_dir(tmp)
      ports.ensure_cache_dir(tmp)
      local stat = vim.loop.fs_stat(tmp)
      R.assert_not_nil(stat)
      vim.fn.delete(tmp, "rf")
    end)
  end)
end)
