-- lua/spec/modules/capability_spec.lua (shim)
local R = require("spec._runner")

return {
  test_graph_topo = function()
    local graph = require("modules.capability.graph")
    local g = graph.build({
      { mod_path = "a", cap = { provides = { "x" }, depends = { "y" } } },
      { mod_path = "b", cap = { provides = { "y" } } },
    })
    local res = graph.topo_sort(g)
    R.assert_true(#res.order >= 2)
  end,

  test_keybind_presets = function()
    local presets = require("modules.capability.keybind_presets")
    R.assert_true(presets.is_known("vim"))
    R.assert_true(presets.is_known("helix"))
    R.assert_true(#presets.resolve("vim") >= 1)
    R.assert_eq(#presets.resolve("unknown_xyz"), 0)
  end,

  test_capability_registry = function()
    local reg = require("modules.capability.registry")
    R.assert_true(reg.is_registered("modules.cap.image"))
  end,
}
