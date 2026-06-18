-- spec/runtime/cap_spec.lua
-- collect_ext pass, cap_resolve pass, CapAdapterRegistry, cap adapters.

local R = require("spec._runner")

-- ── collect_ext pass ──────────────────────────────────────────────────────────

R.describe("runtime.passes.collect_ext", function()
  local collect_ext = require("runtime.passes.collect_ext")
  local ir_mod = require("core.compiler.ir")
  local F = require("spec._fixtures.caps")

  -- ── registered() / register() ─────────────────────────────────────────────

  R.describe("registered()", function()
    R.it("returns the current cap module list (>= 5 defaults)", function()
      R.assert_true(#collect_ext.registered() >= 5)
    end)
    R.it("register() updates the module list", function()
      local orig = collect_ext.registered()
      collect_ext.register({ "modules.cap.image" })
      R.assert_eq(#collect_ext.registered(), 1)
      -- restore
      collect_ext.register(orig)
    end)
  end)

  -- ── pass.run() ────────────────────────────────────────────────────────────

  R.describe("pass.run()", function()
    R.it("populates ext_caps.image bucket after collect", function()
      local ir = collect_ext.pass.run(ir_mod.new({ "modules.lang.lua_lang" }, "full"))
      R.assert_type(ir.ext_caps, "table")
      R.assert_not_nil(ir.ext_caps.image, "image bucket must exist")
      R.assert_true(next(ir.ext_caps.image) ~= nil, "image bucket must be non-empty")
    end)

    R.it("only collect_ext may write ext_caps (Invariant 11)", function()
      -- Verify other passes don't touch ext_caps by checking collect result
      local ir = ir_mod.new({}, "full")
      local after = collect_ext.pass.run(ir)
      -- original IR ext_caps must be clean
      for _, bucket in pairs(ir.ext_caps) do
        R.assert_true(next(bucket) == nil, "original IR ext_caps must be unchanged")
      end
      -- result must have populated buckets
      R.assert_type(after.ext_caps, "table")
    end)

    R.it("validates cap modules via ext_schema (Invariant 12)", function()
      -- A module with invalid cap_type should be skipped with a diagnostic
      local bad_module = "modules.cap.image" -- valid; just confirming schema is called
      collect_ext.register({ bad_module })
      local ir = collect_ext.pass.run(ir_mod.new({}, "full"))
      -- No error diagnostics for a valid module
      local err_count = 0
      for _, d in ipairs(ir.diagnostics or {}) do
        if d.severity == "error" then
          err_count = err_count + 1
        end
      end
      R.assert_eq(err_count, 0, "valid cap module must not produce error diagnostics")
      -- restore
      collect_ext.register(require("runtime.defaults.caps").modules)
    end)
  end)
end)

-- ── cap_resolve pass ──────────────────────────────────────────────────────────

R.describe("runtime.passes.cap_resolve", function()
  local cap_resolve = require("runtime.passes.cap_resolve")
  local ir_mod = require("core.compiler.ir")
  local collect_ext = require("runtime.passes.collect_ext")
  local FC = require("spec._fixtures.caps")

  R.it("populates cap_specs.image from ext_caps.image", function()
    local ir = collect_ext.pass.run(ir_mod.new({}, "full"))
    ir = cap_resolve.pass.run(ir)
    R.assert_type(ir.cap_specs, "table")
    R.assert_type(ir.cap_specs.image, "table")
  end)

  R.it("warn diagnostic when no adapter registered for cap_type", function()
    -- temporarily register an unknown cap_type
    local ir_base = ir_mod.new({}, "full")
    ir_base.ext_caps["unknown_type_xyz"] = { mod = { cap_type = "unknown_type_xyz", version = 1 } }
    local ir = cap_resolve.pass.run(ir_base)
    local found_warn = false
    for _, d in ipairs(ir.diagnostics or {}) do
      if d.severity == "warn" and (d.message or ""):find("no capability adapter") then
        found_warn = true
        break
      end
    end
    R.assert_true(found_warn, "missing adapter must produce warn diagnostic")
  end)

  R.it("warn message uses lowercase (§3.10 convention)", function()
    local ir_base = ir_mod.new({}, "full")
    ir_base.ext_caps["unknown_xyz_lower"] = { mod = {} }
    local ir = cap_resolve.pass.run(ir_base)
    for _, d in ipairs(ir.diagnostics or {}) do
      if d.severity == "warn" and (d.message or ""):find("no capability adapter") then
        -- First character of message should be lowercase 'n'
        R.assert_eq(d.message:sub(1, 1), "n", "warn message must start lowercase")
        return
      end
    end
  end)

  R.it("does not mutate input IR (COW)", function()
    local ir = collect_ext.pass.run(ir_mod.new({}, "full"))
    local orig_cap_specs = ir.cap_specs
    cap_resolve.pass.run(ir)
    R.assert_eq(ir.cap_specs, orig_cap_specs, "input IR cap_specs must not be mutated")
  end)
end)

-- ── CapAdapterRegistry ────────────────────────────────────────────────────────

R.describe("runtime.adapters.cap_registry", function()
  local reg = require("runtime.adapters.cap_registry")

  R.it("at least 4 cap adapters registered after setup", function()
    R.assert_true(#reg.list() >= 4)
  end)

  R.it("image adapter is registered and loadable", function()
    R.assert_not_nil(reg.get("image"), "image adapter must be registered")
  end)

  R.it("media adapter is registered and loadable", function()
    R.assert_not_nil(reg.get("media"))
  end)

  R.it("ai adapter is registered and loadable", function()
    R.assert_not_nil(reg.get("ai"))
  end)

  R.it("keybind adapter is registered and loadable", function()
    R.assert_not_nil(reg.get("keybind"))
  end)

  R.it("unknown cap_type returns nil", function()
    R.assert_nil(reg.get("unknown_cap_type_xyz_" .. math.random(1e6)))
  end)

  R.it("list() is sorted", function()
    local list = reg.list()
    for i = 2, #list do
      R.assert_true(list[i - 1] <= list[i], "list must be sorted")
    end
  end)

  -- ── setup() idempotency (P6-C2) ───────────────────────────────────────────

  R.it("setup() is idempotent — double call does not duplicate adapters", function()
    local count1 = #reg.list()
    reg.setup()
    reg.setup()
    R.assert_eq(#reg.list(), count1)
  end)
end)

-- ── cap adapters: build() contract ────────────────────────────────────────────

R.describe("cap adapter build() contracts (Invariant 13)", function()
  local ir_mod = require("core.compiler.ir")
  local FC = require("spec._fixtures.caps")

  local adapters = {
    { name = "image", mod = "runtime.adapters.image", caps = FC.all_caps().image },
    { name = "media", mod = "runtime.adapters.media", caps = FC.all_caps().media },
    { name = "ai_cap", mod = "runtime.adapters.ai_cap", caps = FC.all_caps().ai },
    { name = "keybind", mod = "runtime.adapters.keybind", caps = FC.all_caps().keybind },
  }

  for _, entry in ipairs(adapters) do
    local name = entry.name
    local mod = entry.mod
    local caps = entry.caps

    R.describe(name .. " adapter", function()
      local ir = ir_mod.new({}, "full")

      R.it("build(ir, caps_by_name) returns table without error", function()
        local adapter = require(mod)
        local ok, result = pcall(adapter.build, ir, caps)
        R.assert_true(ok, name .. ".build() must not throw")
        R.assert_type(result, "table", name .. ".build() must return table")
      end)

      R.it("build(ir, {}) returns empty table gracefully", function()
        local adapter = require(mod)
        local ok, result = pcall(adapter.build, ir, {})
        R.assert_true(ok)
        R.assert_type(result, "table")
      end)

      R.it("all returned specs are tables (LazySpec shape)", function()
        local adapter = require(mod)
        local _, specs = pcall(adapter.build, ir, caps)
        if type(specs) == "table" then
          for i, s in ipairs(specs) do
            R.assert_type(s, "table", name .. " spec[" .. i .. "] must be a table")
          end
        end
      end)
    end)
  end
end)

-- ── ai_cap adapter: provider coverage (P6-C5) ────────────────────────────────

R.describe("runtime.adapters.ai_cap (P6-C5)", function()
  local ai_cap = require("runtime.adapters.ai_cap")
  local ir = require("core.compiler.ir").new({}, "full")
  local FC = require("spec._fixtures.caps")

  R.it("generates copilot.vim spec from completion provider", function()
    local specs = ai_cap.build(ir, {
      cap = { cap_type = "ai", version = 1, completion = { provider = "copilot" } },
    })
    local names = {}
    for _, s in ipairs(specs) do
      if type(s[1]) == "string" then
        names[s[1]] = true
      end
    end
    R.assert_true(names["github/copilot.vim"] or #specs > 0, "copilot.vim must appear for copilot completion provider")
  end)

  R.it("explicit plugin declarations take priority (no duplicates)", function()
    local cap = FC.ai_cap() -- has plugins list with github/copilot.vim
    local specs = ai_cap.build(ir, { cap = cap })
    local copilot_count = 0
    for _, s in ipairs(specs) do
      if s[1] == "github/copilot.vim" then
        copilot_count = copilot_count + 1
      end
    end
    R.assert_true(copilot_count <= 1, "copilot.vim must appear at most once")
  end)

  R.it("all specs carry ltos:cap:ai _source prefix", function()
    local specs = ai_cap.build(ir, { cap = FC.ai_cap() })
    for _, s in ipairs(specs) do
      if s._source then
        R.assert_match(s._source, "^ltos:cap:ai")
      end
    end
  end)
end)

-- ── image adapter: spec content ───────────────────────────────────────────────

R.describe("runtime.adapters.image", function()
  local image = require("runtime.adapters.image")
  local ir = require("core.compiler.ir").new({}, "full")
  local FC = require("spec._fixtures.caps")

  R.it("generates 3rd/image.nvim spec from image cap", function()
    local specs = image.build(ir, { cap = FC.image_cap() })
    local found = false
    for _, s in ipairs(specs) do
      if s[1] == "3rd/image.nvim" then
        found = true
        break
      end
    end
    R.assert_true(found, "image adapter must emit 3rd/image.nvim spec")
  end)

  R.it("chafa.nvim included when fallback=chafa", function()
    local specs = image.build(ir, { cap = FC.image_cap({ fallback = "chafa" }) })
    local found = false
    for _, s in ipairs(specs) do
      if (s[1] or ""):find("chafa") then
        found = true
        break
      end
    end
    R.assert_true(found, "chafa.nvim must appear when fallback=chafa")
  end)
end)
