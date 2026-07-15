-- spec/modules/capability_spec.lua
-- modules/capability: graph, registry, keybind_presets.

local R = require("spec._runner")

-- ── Graph ─────────────────────────────────────────────────────────────────────

R.describe("modules.capability.graph", function()
  local graph = require("modules.capability.graph")

  local function entry(mod_path, provides, depends)
    return {
      mod_path = mod_path,
      cap = {
        provides = provides or {},
        depends = depends or {},
      },
    }
  end

  -- ── build() ───────────────────────────────────────────────────────────────

  R.describe("build()", function()
    R.it("populates nodes and edges from modules", function()
      local g = graph.build({
        entry("a", { "feat_x" }),
        entry("b", {}, { "feat_x" }),
      })
      R.assert_not_nil(g.nodes["a"])
      R.assert_not_nil(g.nodes["b"])
    end)

    R.it("provides map tracks feature → module list", function()
      local g = graph.build({ entry("a", { "feat_x" }) })
      R.assert_not_nil(g.provides["feat_x"])
      R.assert_true(#g.provides["feat_x"] >= 1)
    end)
  end)

  -- ── topo_sort() ───────────────────────────────────────────────────────────

  R.describe("topo_sort()", function()
    R.it("simple chain: b depends on a → a comes first", function()
      local g = graph.build({
        entry("b", {}, { "feat" }),
        entry("a", { "feat" }),
      })
      local res = graph.topo_sort(g)
      R.assert_true(#res.order >= 2)
      local pos = {}
      for i, m in ipairs(res.order) do
        pos[m] = i
      end
      R.assert_true(pos["a"] < pos["b"], "a must precede b")
    end)

    R.it("independent nodes: both appear in order", function()
      local g = graph.build({
        entry("x", { "feat_x" }),
        entry("y", { "feat_y" }),
      })
      local res = graph.topo_sort(g)
      R.assert_eq(#res.order, 2)
    end)

    R.it("cycle detection: returns non-empty cycles list", function()
      local g = graph.build({
        entry("a", { "feat_a" }, { "feat_b" }),
        entry("b", { "feat_b" }, { "feat_a" }),
      })
      local res = graph.topo_sort(g)
      R.assert_true(#res.cycles > 0, "cycle must be detected")
      R.assert_true(#res.diags > 0, "cycle must produce diagnostic")
    end)

    R.it("no cycle: empty cycles list", function()
      local g = graph.build({
        entry("a", { "x" }),
        entry("b", {}, { "x" }),
      })
      local res = graph.topo_sort(g)
      R.assert_eq(#res.cycles, 0)
    end)
  end)

  -- ── validate_deps() ───────────────────────────────────────────────────────

  R.describe("validate_deps()", function()
    R.it("missing dependency → warn diagnostic", function()
      local g = graph.build({ entry("a", {}, { "feat_missing" }) })
      local res = graph.validate_deps(g)
      R.assert_not_nil(res.missing["a"])
      R.assert_true(#res.diags > 0)
    end)

    R.it("satisfied dependency → no warning", function()
      local g = graph.build({
        entry("a", { "x" }),
        entry("b", {}, { "x" }),
      })
      local res = graph.validate_deps(g)
      R.assert_true(next(res.missing) == nil)
      R.assert_eq(#res.diags, 0)
    end)
  end)

  -- ── sort() ────────────────────────────────────────────────────────────────

  R.describe("sort()", function()
    R.it("returns sorted order and diagnostic list", function()
      local order, diags = graph.sort({
        entry("b", {}, { "x" }),
        entry("a", { "x" }),
      })
      R.assert_type(order, "table")
      R.assert_type(diags, "table")
      R.assert_true(#order >= 2)
    end)
  end)
end)

-- ── CapTypeRegistry ───────────────────────────────────────────────────────────

R.describe("modules.capability.registry", function()
  local reg = require("modules.capability.registry")

  R.before_each(function() reg._reset() end)
  R.after_each(function() reg._reset() end)

  R.it("register() and is_registered()", function()
    reg.register("image", "modules.cap.image")
    R.assert_true(reg.is_registered("modules.cap.image"))
  end)

  R.it("register() is idempotent", function()
    reg.register("image", "modules.cap.image")
    reg.register("image", "modules.cap.image")
    R.assert_eq(#reg.get_by_type("image"), 1)
  end)

  R.it("get_by_type() returns modules for cap_type", function()
    reg.register("ai", "modules.cap.ai")
    reg.register("ai", "modules.ai.copilot")
    local mods = reg.get_by_type("ai")
    R.assert_eq(#mods, 2)
  end)

  R.it("get_all() returns all registered modules sorted", function()
    reg.register("image", "modules.cap.image")
    reg.register("keybind", "modules.cap.keybind")
    local all = reg.get_all()
    R.assert_eq(#all, 2)
    R.assert_true(all[1] < all[2], "get_all must be sorted")
  end)

  R.it("categories() returns distinct cap_types sorted", function()
    reg.register("image", "modules.cap.image")
    reg.register("keybind", "modules.cap.keybind")
    local cats = reg.categories()
    R.assert_eq(#cats, 2)
  end)

  R.it("register_all() batch registration", function()
    reg.register_all({
      { cap_type = "image", mod_path = "modules.cap.image" },
      { cap_type = "keybind", mod_path = "modules.cap.keybind" },
    })
    R.assert_true(reg.is_registered("modules.cap.image"))
    R.assert_true(reg.is_registered("modules.cap.keybind"))
  end)
end)

-- ── Keybind Presets ───────────────────────────────────────────────────────────

R.describe("modules.capability.keybind_presets", function()
  local presets = require("modules.capability.keybind_presets")

  R.it("is_known() returns true for built-in presets", function()
    R.assert_true(presets.is_known("vim"))
    R.assert_true(presets.is_known("helix"))
    R.assert_true(presets.is_known("emacs"))
  end)
  R.it(
    "is_known() returns false for unknown preset",
    function() R.assert_false(presets.is_known("dvorak_ultra")) end
  )
  R.it(
    "resolve('vim') returns non-empty binding list",
    function() R.assert_true(#presets.resolve("vim") >= 1) end
  )
  R.it(
    "resolve('helix') returns non-empty binding list",
    function() R.assert_true(#presets.resolve("helix") >= 1) end
  )
  R.it("resolve(nil) returns empty list", function() R.assert_eq(#presets.resolve(nil), 0) end)
  R.it(
    "resolve(unknown) returns empty list",
    function() R.assert_eq(#presets.resolve("unknown_xyz"), 0) end
  )
  R.it("known_presets() returns sorted list", function()
    local kp = presets.known_presets()
    R.assert_type(kp, "table")
    R.assert_true(#kp >= 3)
  end)
end)