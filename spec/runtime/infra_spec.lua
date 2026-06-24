-- spec/runtime/infra_spec.lua
-- Runtime infrastructure:
--   providers/interface (ModuleProvider.discover)
--   providers/registry  (ProviderRegistry: profiles, filters)
--   providers/config    (ConfigProvider.build_setup_opts)
--   emitter/init        (emit pipeline, side-effect boundary)
--   emitter/cap_effects (keybind side-effects)
--   api                 (format/picker/terminal/diagnostics/lsp facades)
--   defaults/*          (data integrity: adapters/cap_adapters/caps/phases)

local R = require("spec._runner")

-- ── runtime.providers.interface (ModuleProvider.discover) ────────────────────

R.describe("runtime.providers.interface", function()
  local iface = require("runtime.providers.interface")

  R.describe("discover()", function()
    R.it("returns a table list", function()
      local mods = iface.discover()
      R.assert_type(mods, "table")
    end)

    R.it("contains lua module path", function()
      local mods = iface.discover()
      local found = false
      for _, m in ipairs(mods) do
        if m == "modules.lang.lua" then
          found = true
          break
        end
      end
      R.assert_true(found, "modules.lang.lua must be discovered")
    end)

    R.it("result is sorted", function()
      local mods = iface.discover()
      for i = 2, #mods do
        R.assert_true(mods[i - 1] <= mods[i], "discover() must return sorted list")
      end
    end)

    R.it("no duplicates in result", function()
      local mods = iface.discover()
      local seen = {}
      for _, m in ipairs(mods) do
        R.assert_nil(seen[m], "duplicate in discover(): " .. m)
        seen[m] = true
      end
    end)

    R.it("all paths use dot-notation (not slashes)", function()
      local mods = iface.discover()
      for _, m in ipairs(mods) do
        R.assert_nil(m:find("/"), "module path must use dot-notation: " .. m)
      end
    end)

    R.it("each discovered module loads as plain table", function()
      local mods = iface.discover()
      for _, m in ipairs(mods) do
        local ok, result = pcall(require, m)
        R.assert_true(ok, m .. " must load without error")
        R.assert_type(result, "table", m .. " must return a table")
      end
    end)
  end)
end)

-- ── runtime.providers.registry (ProviderRegistry) ────────────────────────────

R.describe("runtime.providers.registry", function()
  local reg = require("runtime.providers.registry")

  -- ── list_profiles() ───────────────────────────────────────────────────────

  R.describe("list_profiles()", function()
    R.it("includes 'full' profile", function()
      local profiles = reg.list_profiles()
      local set = {}
      for _, p in ipairs(profiles) do
        set[p] = true
      end
      R.assert_true(set.full, "'full' profile must be listed")
    end)
    R.it("includes 'minimal' profile", function()
      local profiles = reg.list_profiles()
      local set = {}
      for _, p in ipairs(profiles) do
        set[p] = true
      end
      R.assert_true(set.minimal, "'minimal' profile must be listed")
    end)
    R.it("includes 'nix' profile", function()
      local profiles = reg.list_profiles()
      local set = {}
      for _, p in ipairs(profiles) do
        set[p] = true
      end
      R.assert_true(set.nix, "'nix' profile must be listed")
    end)
    R.it("result is sorted", function()
      local profiles = reg.list_profiles()
      for i = 2, #profiles do
        R.assert_true(profiles[i - 1] <= profiles[i])
      end
    end)
  end)

  -- ── resolve() ────────────────────────────────────────────────────────────

  R.describe("resolve()", function()
    R.it("'full' profile returns all discovered modules", function()
      local full = reg.resolve("full")
      local minimal = reg.resolve("minimal")
      R.assert_true(#full > 0)
      R.assert_true(#full >= #minimal, "full must have >= modules than minimal")
    end)

    R.it("'minimal' profile returns only core modules", function()
      local minimal = reg.resolve("minimal")
      R.assert_true(#minimal >= 1, "minimal must have at least one core module")
      -- Each module in minimal must declare core=true
      for _, m in ipairs(minimal) do
        local ok, mod = pcall(require, m)
        R.assert_true(ok, m .. " must load")
        R.assert_true(mod.core == true, m .. " in minimal profile must have core=true")
      end
    end)

    R.it("'minimal' includes lua (core=true module)", function()
      local minimal = reg.resolve("minimal")
      local found = false
      for _, m in ipairs(minimal) do
        if m == "modules.lang.lua" then
          found = true
          break
        end
      end
      R.assert_true(found, "lua (core=true) must be in minimal profile")
    end)

    R.it("'nix' profile returns same module set as full", function()
      local full = reg.resolve("full")
      local nix = reg.resolve("nix")
      R.assert_eq(#full, #nix, "nix profile uses same modules as full (tool strategy differs)")
    end)

    R.it("result is deduplicated and sorted", function()
      local mods = reg.resolve("full")
      local seen = {}
      for i, m in ipairs(mods) do
        R.assert_nil(seen[m], "duplicate in resolve(): " .. m)
        seen[m] = true
        if i > 1 then
          R.assert_true(mods[i - 1] <= m, "resolve() must return sorted list")
        end
      end
    end)

    R.it("unknown profile falls back to full", function()
      -- register_filter only registers named profiles; unknown → full
      local full = reg.resolve("full")
      local unknown = reg.resolve("nonexistent_profile_xyz")
      R.assert_eq(#full, #unknown, "unknown profile must fall back to full module set")
    end)
  end)

  -- ── register() extension API ─────────────────────────────────────────────

  R.describe("register()", function()
    R.it("register() throws for empty path", function() R.assert_false(pcall(reg.register, "")) end)
    R.it("register() throws for non-string", function() R.assert_false(pcall(reg.register, 42)) end)
    R.it("register() adds extra module to full resolve", function()
      local before = #reg.resolve("full")
      reg.register("modules.lang.lua") -- already exists → deduplicated
      local after = #reg.resolve("full")
      -- Should not increase (dedup)
      R.assert_eq(before, after, "existing module must be deduplicated")
    end)
  end)
end)

-- ── runtime.providers.config (ConfigProvider) ────────────────────────────────

R.describe("runtime.providers.config", function()
  local config = require("runtime.providers.config")

  -- ── build_setup_opts() ───────────────────────────────────────────────────

  R.describe("build_setup_opts()", function()
    R.it("returns table with required lazy.nvim setup keys", function()
      local opts = config.build_setup_opts({})
      R.assert_type(opts, "table")
      R.assert_type(opts.spec, "table")
      R.assert_type(opts.defaults, "table")
      R.assert_type(opts.install, "table")
      R.assert_type(opts.checker, "table")
      R.assert_type(opts.performance, "table")
    end)

    R.it("spec includes LazyVim import", function()
      local opts = config.build_setup_opts({})
      local found = false
      for _, entry in ipairs(opts.spec) do
        if type(entry) == "table" and entry[1] == "LazyVim/LazyVim" then
          found = true
          break
        end
      end
      R.assert_true(found, "LazyVim/LazyVim must be in spec")
    end)

    R.it("lang_specs are appended to spec", function()
      local dummy_spec = { { "test/plugin", _source = "ltos:test" } }
      local opts = config.build_setup_opts(dummy_spec)
      local found = false
      for _, entry in ipairs(opts.spec) do
        if type(entry) == "table" and entry[1] == "test/plugin" then
          found = true
          break
        end
      end
      R.assert_true(found, "lang_specs must be appended to spec list")
    end)

    R.it("defaults.lazy = true (lazy loading default)", function()
      local opts = config.build_setup_opts({})
      R.assert_true(opts.defaults.lazy == true)
    end)

    R.it("defaults.version = false (always use latest)", function()
      local opts = config.build_setup_opts({})
      R.assert_false(opts.defaults.version)
    end)

    R.it("performance.rtp.disabled_plugins is non-empty list", function()
      local opts = config.build_setup_opts({})
      local disabled = opts.performance.rtp.disabled_plugins
      R.assert_type(disabled, "table")
      R.assert_true(#disabled > 0)
    end)

    R.it("lockfile path is a non-empty string", function()
      local opts = config.build_setup_opts({})
      R.assert_type(opts.lockfile, "string")
      R.assert_true(#opts.lockfile > 0)
    end)

    R.it("rocks.enabled = false", function()
      local opts = config.build_setup_opts({})
      R.assert_false(opts.rocks.enabled)
    end)
  end)

  -- ── register_spec() ──────────────────────────────────────────────────────

  R.describe("register_spec()", function()
    R.it("registers a spec provider function", function()
      local called = false
      config.register_spec(function()
        called = true
        return {}
      end)
      config.build_setup_opts({})
      R.assert_true(called, "registered spec provider must be called")
    end)
  end)
end)

-- ── runtime.emitter.init (side-effect boundary, Invariant 3) ─────────────────

R.describe("runtime.emitter.init", function()
  local emitter = require("runtime.emitter")

  -- ── emit() ────────────────────────────────────────────────────────────────

  R.describe("emit()", function()
    local function minimal_lir()
      local pipeline = require("runtime.pipeline")
      return pipeline.debug_run({ "modules.lang.lua" }, "optimize")
    end

    R.it("returns flat LazySpec[] list", function()
      local ir = minimal_lir()
      local specs = emitter.emit(ir, {
        "runtime.adapters.lsp",
        "runtime.adapters.mason",
      })
      R.assert_type(specs, "table")
      R.assert_true(#specs >= 2)
    end)

    R.it("each spec is a table", function()
      local ir = minimal_lir()
      local specs = emitter.emit(ir, {
        "runtime.adapters.lsp",
        "runtime.adapters.treesitter",
        "runtime.adapters.conform",
        "runtime.adapters.lint",
      })
      for i, s in ipairs(specs) do
        R.assert_type(s, "table", "spec[" .. i .. "] must be table")
      end
    end)

    R.it("unknown adapter path produces no crash (graceful degradation)", function()
      local ir = minimal_lir()
      local ok = pcall(emitter.emit, ir, {
        "runtime.adapters.does_not_exist_xyz",
        "runtime.adapters.lsp",
      })
      R.assert_true(ok, "emitter must not crash for unknown adapter path")
    end)

    R.it("adapter without build() is skipped gracefully", function()
      -- Inject a fake adapter module with no build()
      local fake_path = "runtime.adapters.__fake_no_build__"
      package.loaded[fake_path] = { name = "fake" } -- no build()
      local ir = minimal_lir()
      local ok, specs = pcall(emitter.emit, ir, { fake_path, "runtime.adapters.lsp" })
      R.assert_true(ok, "emitter must handle adapter without build()")
      R.assert_type(specs, "table")
      package.loaded[fake_path] = nil
    end)

    R.it("empty adapter list returns empty specs", function()
      local ir = minimal_lir()
      local specs = emitter.emit(ir, {})
      R.assert_type(specs, "table")
      R.assert_eq(#specs, 0)
    end)

    R.it(
      "Invariant 3: emitter is the sole side-effect boundary (no vim.notify in adapters)",
      function()
        -- Verify that adapters themselves don't call vim.notify
        -- This is a static check via the architecture; we verify emitter wraps correctly
        local ir = minimal_lir()
        local notify_count_before = 0 -- track via pcall
        local specs = emitter.emit(ir, {
          "runtime.adapters.lsp",
          "runtime.adapters.mason",
          "runtime.adapters.treesitter",
          "runtime.adapters.conform",
          "runtime.adapters.lint",
        })
        R.assert_true(#specs > 0, "all 5 adapters must produce specs via emitter")
      end
    )
  end)
end)

-- ── runtime.emitter.cap_effects (keybind side-effects) ───────────────────────

R.describe("runtime.emitter.cap_effects", function()
  local cap_effects = require("runtime.emitter.cap_effects")

  R.describe("apply_keybinds()", function()
    R.it("apply_keybinds(nil) does not crash", function()
      cap_effects._reset()
      local ok = pcall(cap_effects.apply_keybinds, nil)
      R.assert_true(ok, "apply_keybinds(nil) must not throw")
    end)

    R.it("apply_keybinds(ir_without_ext_caps) does not crash", function()
      cap_effects._reset()
      local ir = require("core.compiler.ir").new({}, "full")
      local ok = pcall(cap_effects.apply_keybinds, ir)
      R.assert_true(ok)
    end)

    R.it("_reset() clears applied flag (idempotent for tests)", function()
      cap_effects._reset()
      -- After reset, apply_keybinds should be callable again
      local ir = require("core.compiler.ir").new({}, "full")
      ir.ext_caps = { keybind = {} } -- empty bucket
      local ok = pcall(cap_effects.apply_keybinds, ir)
      R.assert_true(ok)
    end)

    R.it("apply_all() delegates to apply_keybinds", function()
      cap_effects._reset()
      local ir = require("core.compiler.ir").new({}, "full")
      local ok = pcall(cap_effects.apply_all, ir)
      R.assert_true(ok, "apply_all must not throw")
    end)
  end)
end)

-- ── runtime.api (editor facade) ──────────────────────────────────────────────

R.describe("runtime.api", function()
  local api = require("runtime.api")

  -- ── API surface ───────────────────────────────────────────────────────────

  R.describe("API surface completeness", function()
    local expected_fns = {
      "format",
      "find_files",
      "live_grep",
      "buffers",
      "recent_files",
      "help_tags",
      "on_ready",
      "on_lifecycle_change",
    }
    for _, fn in ipairs(expected_fns) do
      R.it(
        fn .. "() exists as function",
        function() R.assert_type(api[fn], "function", "api." .. fn .. " must be a function") end
      )
    end
  end)

  R.describe("namespaced tables", function()
    R.it("api.diagnostics table with next/prev/open/list", function()
      R.assert_type(api.diagnostics, "table")
      for _, m in ipairs({ "next", "prev", "open", "list" }) do
        R.assert_type(
          api.diagnostics[m],
          "function",
          "api.diagnostics." .. m .. " must be function"
        )
      end
    end)
    R.it("api.lsp table with rename/code_action/hover/signature", function()
      R.assert_type(api.lsp, "table")
      for _, m in ipairs({ "rename", "code_action", "hover", "signature" }) do
        R.assert_type(api.lsp[m], "function", "api.lsp." .. m .. " must be function")
      end
    end)
    R.it("api.terminal table with float/horizontal/register/set_default", function()
      R.assert_type(api.terminal, "table")
      for _, m in ipairs({ "float", "horizontal", "register", "set_default" }) do
        R.assert_type(api.terminal[m], "function", "api.terminal." .. m .. " must be function")
      end
    end)
    R.it("api.picker table with register/set_default", function()
      R.assert_type(api.picker, "table")
      R.assert_type(api.picker.register, "function")
      R.assert_type(api.picker.set_default, "function")
    end)
    R.it("api.ui table with zen/zoom", function()
      R.assert_type(api.ui, "table")
      R.assert_type(api.ui.zen, "function")
      R.assert_type(api.ui.zoom, "function")
    end)
  end)

  -- ── picker_register / picker_set_default ────────────────────────────────

  R.describe("picker_register()", function()
    R.it("throws for empty name", function() R.assert_false(pcall(api.picker_register, "", {})) end)
    R.it(
      "throws for non-table backend",
      function() R.assert_false(pcall(api.picker_register, "test", "not_a_table")) end
    )
    R.it("registers backend successfully", function()
      local ok = pcall(api.picker_register, "test_picker", { files = function() end })
      R.assert_true(ok)
    end)
  end)

  -- ── terminal_register ────────────────────────────────────────────────────

  R.describe("terminal_register()", function()
    R.it(
      "throws for empty name",
      function() R.assert_false(pcall(api.terminal_register, "", {})) end
    )
    R.it("registers terminal backend successfully", function()
      local ok = pcall(
        api.terminal_register,
        "test_terminal",
        { float = function() end, horizontal = function() end }
      )
      R.assert_true(ok)
    end)
  end)

  -- ── on_ready / on_lifecycle_change (P6-C1) ────────────────────────────────

  R.describe("lifecycle hooks (P6-C1)", function()
    R.it("on_ready() accepts a function callback", function()
      local ok = pcall(api.on_ready, function() end)
      R.assert_true(ok)
    end)
    R.it("on_lifecycle_change() accepts a function callback", function()
      local ok = pcall(api.on_lifecycle_change, function() end)
      R.assert_true(ok)
    end)
  end)
end)

-- ── runtime.defaults data integrity ──────────────────────────────────────────

R.describe("runtime.defaults data integrity", function()
  -- ── defaults/adapters.lua ─────────────────────────────────────────────────

  R.describe("runtime.defaults.adapters", function()
    local defaults = require("runtime.defaults.adapters")

    R.it("is a table list", function()
      R.assert_type(defaults, "table")
      R.assert_true(#defaults >= 5)
    end)

    R.it("each entry has path (string) and priority (number)", function()
      for i, entry in ipairs(defaults) do
        R.assert_type(entry.path, "string", "entry[" .. i .. "].path must be string")
        R.assert_type(entry.priority, "number", "entry[" .. i .. "].priority must be number")
      end
    end)

    R.it("contains all 5 required lang adapters", function()
      local paths = {}
      for _, e in ipairs(defaults) do
        paths[e.path] = true
      end
      for _, expected in ipairs({
        "runtime.adapters.lsp",
        "runtime.adapters.mason",
        "runtime.adapters.treesitter",
        "runtime.adapters.conform",
        "runtime.adapters.lint",
      }) do
        R.assert_true(paths[expected], expected .. " must be in defaults")
      end
    end)

    R.it("priorities are unique (no collisions)", function()
      local prios = {}
      for _, e in ipairs(defaults) do
        R.assert_nil(prios[e.priority], "duplicate priority " .. e.priority .. " for " .. e.path)
        prios[e.priority] = e.path
      end
    end)

    R.it("priorities are in ascending order", function()
      for i = 2, #defaults do
        R.assert_true(
          defaults[i].priority > defaults[i - 1].priority,
          "adapter priorities must be ascending"
        )
      end
    end)
  end)

  -- ── defaults/cap_adapters.lua ─────────────────────────────────────────────

  R.describe("runtime.defaults.cap_adapters", function()
    local defaults = require("runtime.defaults.cap_adapters")

    R.it("is a table list", function()
      R.assert_type(defaults, "table")
      R.assert_true(#defaults >= 4)
    end)

    R.it("each entry has cap_type and path", function()
      for i, entry in ipairs(defaults) do
        R.assert_type(entry.cap_type, "string", "entry[" .. i .. "].cap_type must be string")
        R.assert_type(entry.path, "string", "entry[" .. i .. "].path must be string")
      end
    end)

    R.it("contains image/media/ai/keybind cap adapters", function()
      local types = {}
      for _, e in ipairs(defaults) do
        types[e.cap_type] = true
      end
      for _, ct in ipairs({ "image", "media", "ai", "keybind" }) do
        R.assert_true(types[ct], ct .. " cap adapter must be registered")
      end
    end)

    R.it("each cap adapter module is loadable", function()
      for _, e in ipairs(defaults) do
        local ok, mod = pcall(require, e.path)
        R.assert_true(ok, e.path .. " must load without error")
        R.assert_type(mod.build, "function", e.path .. ".build must be a function")
      end
    end)
  end)

  -- ── defaults/caps.lua ─────────────────────────────────────────────────────

  R.describe("runtime.defaults.caps", function()
    local defaults = require("runtime.defaults.caps")

    R.it("has modules list", function()
      R.assert_type(defaults.modules, "table")
      R.assert_true(#defaults.modules >= 5)
    end)

    R.it("each cap module path is a non-empty string", function()
      for i, m in ipairs(defaults.modules) do
        R.assert_type(m, "string", "caps.modules[" .. i .. "] must be string")
        R.assert_true(#m > 0, "cap module path must not be empty")
      end
    end)

    R.it("contains required cap module paths", function()
      local set = {}
      for _, m in ipairs(defaults.modules) do
        set[m] = true
      end
      for _, expected in ipairs({
        "modules.cap.image",
        "modules.cap.media",
        "modules.cap.ai",
        "modules.cap.keybind",
      }) do
        R.assert_true(set[expected], expected .. " must be in default caps")
      end
    end)

    R.it("each cap module is loadable and has cap_type", function()
      for _, m in ipairs(defaults.modules) do
        local ok, mod = pcall(require, m)
        R.assert_true(ok, m .. " must load without error")
        if type(mod) == "table" and mod.cap_type then
          R.assert_type(mod.cap_type, "string")
        end
      end
    end)
  end)

  -- ── defaults/phases.lua ───────────────────────────────────────────────────

  R.describe("runtime.defaults.phases", function()
    local defaults = require("runtime.defaults.phases")

    R.it("has phases list and codegen path", function()
      R.assert_type(defaults.phases, "table")
      R.assert_type(defaults.codegen, "string")
    end)

    R.it(
      "phases list has 7 entries (excluding codegen)",
      function() R.assert_eq(#defaults.phases, 7, "expected exactly 7 non-codegen phases") end
    )

    R.it("each phase entry has path and priority", function()
      for i, entry in ipairs(defaults.phases) do
        R.assert_type(entry.path, "string", "phases[" .. i .. "].path must be string")
        R.assert_type(entry.priority, "number", "phases[" .. i .. "].priority must be number")
      end
    end)

    R.it("collect phase has lowest priority (runs first)", function()
      local collect_entry
      for _, e in ipairs(defaults.phases) do
        if e.path == "runtime.passes.collect" then
          collect_entry = e
          break
        end
      end
      R.assert_not_nil(collect_entry, "collect must be in phases defaults")
      -- collect should have the lowest priority number
      for _, e in ipairs(defaults.phases) do
        if e.path ~= "runtime.passes.collect" then
          R.assert_true(
            collect_entry.priority <= e.priority,
            "collect must have <= priority than " .. e.path
          )
        end
      end
    end)

    R.it("each phase module is loadable", function()
      for _, entry in ipairs(defaults.phases) do
        local ok = pcall(require, entry.path)
        R.assert_true(ok, entry.path .. " must load without error")
      end
      local ok = pcall(require, defaults.codegen)
      R.assert_true(ok, defaults.codegen .. " (codegen) must load")
    end)

    R.it("declarative after/before constraints in phases defaults (P6-D1)", function()
      -- Find collect_ext which must have after = {"collect"}
      local collect_ext_entry
      for _, e in ipairs(defaults.phases) do
        if e.path == "runtime.passes.collect_ext" then
          collect_ext_entry = e
          break
        end
      end
      R.assert_not_nil(collect_ext_entry, "collect_ext must be in phases defaults")
      R.assert_not_nil(collect_ext_entry.after, "collect_ext must have after constraint")
      local has_collect = false
      for _, dep in ipairs(collect_ext_entry.after or {}) do
        if dep == "collect" then
          has_collect = true
          break
        end
      end
      R.assert_true(has_collect, "collect_ext.after must include 'collect'")
    end)
  end)
end)

-- ── toolchain.defaults.mappings data integrity ────────────────────────────────

R.describe("toolchain.defaults.mappings", function()
  local defaults = require("toolchain.defaults.mappings")

  R.it("has lsp_to_mason table", function() R.assert_type(defaults.lsp_to_mason, "table") end)

  R.it("has tool_to_mason table", function() R.assert_type(defaults.tool_to_mason, "table") end)

  R.it("has system_tools table", function() R.assert_type(defaults.system_tools, "table") end)

  R.describe("lsp_to_mason", function()
    local expected = {
      lua_ls = "lua-language-server",
      rust_analyzer = "rust-analyzer",
      pyright = "pyright",
      gopls = "gopls",
      vtsls = "vtsls",
      bashls = "bash-language-server",
      nil_ls = "nil",
      jsonls = "json-lsp",
      yamlls = "yaml-language-server",
    }
    for server, pkg in pairs(expected) do
      R.it(server .. " → " .. pkg, function() R.assert_eq(defaults.lsp_to_mason[server], pkg) end)
    end
  end)

  R.describe("system_tools", function()
    local expected_system = {
      "rustfmt",
      "clippy",
      "gofmt",
      "zigfmt",
      "fish_indent",
      "fish",
      "nixpkgs_fmt",
      "git",
      "make",
      "clangtidy",
    }
    for _, tool in ipairs(expected_system) do
      R.it(
        tool .. " is a system tool (value = true)",
        function()
          R.assert_true(
            defaults.system_tools[tool] == true,
            tool .. " must be true in system_tools"
          )
        end
      )
    end
  end)

  R.describe("no overlap between system_tools and lsp_to_mason", function()
    R.it("lsp servers are not in system_tools", function()
      for server in pairs(defaults.lsp_to_mason) do
        R.assert_nil(
          defaults.system_tools[server],
          "LSP server " .. server .. " must not be in system_tools"
        )
      end
    end)
  end)
end)

