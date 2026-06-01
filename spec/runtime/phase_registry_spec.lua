-- spec/runtime/phase_registry_spec.lua
-- PhaseRegistry: declarative after/before ordering (P6-D1).

local R = require("spec._runner")

R.describe("runtime.phase_registry", function()
  local pr = require("runtime.phase_registry")

  local function make_phase(name)
    return {
      name = name,
      input_state = "x",
      output_state = "y",
      run = function(ir)
        return ir
      end,
    }
  end

  -- restore default state after each test
  R.after_each(function()
    pr._reset()
    -- re-register defaults by re-requiring pipeline (which calls register_default_phases)
    package.loaded["runtime.pipeline"] = nil
    require("runtime.pipeline")
  end)

  R.describe("register() + list()", function()
    R.it("list() returns phases in priority order", function()
      pr._reset()
      pr.register(make_phase("b"), { priority = 20 })
      pr.register(make_phase("a"), { priority = 10 })
      local list = pr.list()
      R.assert_eq(list[1].name, "a")
      R.assert_eq(list[2].name, "b")
    end)

    R.it("after constraint: named phase comes before dependent", function()
      pr._reset()
      pr.register(make_phase("b"), { priority = 20, after = { "a" } })
      pr.register(make_phase("a"), { priority = 10 })
      local list = pr.list()
      local pos = {}
      for i, p in ipairs(list) do
        pos[p.name] = i
      end
      R.assert_true(pos["a"] < pos["b"])
    end)

    R.it("before constraint: phase comes before named", function()
      pr._reset()
      pr.register(make_phase("a"), { priority = 10, before = { "b" } })
      pr.register(make_phase("b"), { priority = 5 })
      local list = pr.list()
      local pos = {}
      for i, p in ipairs(list) do
        pos[p.name] = i
      end
      R.assert_true(pos["a"] < pos["b"])
    end)

    R.it("idempotent reset", function()
      pr._reset()
      R.assert_eq(#pr.list(), 0)
      pr._reset()
      R.assert_eq(#pr.list(), 0)
    end)
  end)

  R.describe("codegen registration", function()
    R.it("register_codegen() stores codegen phase", function()
      pr._reset()
      local cg = make_phase("codegen")
      pr.register_codegen(cg)
      R.assert_eq(pr.codegen(), cg)
    end)

    R.it("phase_order() appends codegen at end", function()
      pr._reset()
      pr.register(make_phase("collect"), { priority = 1 })
      pr.register_codegen(make_phase("codegen"))
      local order = pr.phase_order()
      R.assert_eq(order[#order], "codegen")
    end)
  end)

  R.describe("default pipeline phases", function()
    R.it("all 8 required phases are registered", function()
      -- pipeline.lua calls register_default_phases at load time
      local pipeline = require("runtime.pipeline")
      local order = pipeline.PHASE_ORDER
      local required = {
        "collect",
        "collect_ext",
        "normalize",
        "canonicalize",
        "resolve",
        "optimize",
        "cap_resolve",
        "codegen",
      }
      local pos = {}
      for i, p in ipairs(order) do
        pos[p] = i
      end
      for _, name in ipairs(required) do
        R.assert_not_nil(pos[name], name .. " must be in PHASE_ORDER")
      end
    end)

    R.it("collect is first", function()
      local pipeline = require("runtime.pipeline")
      R.assert_eq(pipeline.PHASE_ORDER[1], "collect")
    end)

    R.it(
      "dependency order preserved: collect < collect_ext < normalize < canonicalize < resolve < optimize < cap_resolve < codegen",
      function()
        local pipeline = require("runtime.pipeline")
        local pos = {}
        for i, p in ipairs(pipeline.PHASE_ORDER) do
          pos[p] = i
        end
        local chain = {
          "collect",
          "collect_ext",
          "normalize",
          "canonicalize",
          "resolve",
          "optimize",
          "cap_resolve",
          "codegen",
        }
        for i = 1, #chain - 1 do
          R.assert_true(pos[chain[i]] < pos[chain[i + 1]], chain[i] .. " must precede " .. chain[i + 1])
        end
      end
    )
  end)
end)
