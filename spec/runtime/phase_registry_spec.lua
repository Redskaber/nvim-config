-- spec/runtime/phase_registry_spec.lua
-- runtime.phase_registry: declarative after/before ordering (P6-D1).

local R = require("spec._runner")

R.describe("runtime.phase_registry", function()
  local pr = require("runtime.phase_registry")

  local function make_phase(name)
    return {
      name = name,
      input_state = "x",
      output_state = "y",
      run = function(ir)
        return require("core.compiler.ir").clone(ir)
      end,
    }
  end

  -- Restore pipeline-registered defaults after each test
  R.after_each(function()
    pr._reset()
    package.loaded["runtime.pipeline"] = nil
    require("runtime.pipeline")
  end)

  -- ── basic register / list ─────────────────────────────────────────────────

  R.describe("register() + list()", function()
    R.it("list() returns phases in priority order (lower first)", function()
      pr._reset()
      pr.register(make_phase("b"), { priority = 20 })
      pr.register(make_phase("a"), { priority = 10 })
      local list = pr.list()
      R.assert_eq(list[1].name, "a")
      R.assert_eq(list[2].name, "b")
    end)

    R.it("idempotent _reset() produces empty list", function()
      pr._reset()
      R.assert_eq(#pr.list(), 0)
      pr._reset()
      R.assert_eq(#pr.list(), 0)
    end)

    R.it("order_cache is invalidated on new register()", function()
      pr._reset()
      pr.register(make_phase("a"), { priority = 10 })
      local l1 = pr.list()
      pr.register(make_phase("b"), { priority = 5 })
      local l2 = pr.list()
      R.assert_eq(l2[1].name, "b")
      R.assert_ne(l1[1], l2[1])
    end)
  end)

  -- ── declarative after / before constraints (P6-D1) ────────────────────────

  R.describe("after / before declarative ordering", function()
    R.it("after: dependent comes after named phase regardless of priority", function()
      pr._reset()
      pr.register(make_phase("b"), { priority = 5, after = { "a" } })
      pr.register(make_phase("a"), { priority = 20 }) -- higher number but must be first
      local list = pr.list()
      local pos = {}
      for i, p in ipairs(list) do
        pos[p.name] = i
      end
      R.assert_true(pos["a"] < pos["b"], "a must precede b (after constraint)")
    end)

    R.it("before: phase comes before named phase", function()
      pr._reset()
      pr.register(make_phase("a"), { priority = 10, before = { "b" } })
      pr.register(make_phase("b"), { priority = 5 })
      local list = pr.list()
      local pos = {}
      for i, p in ipairs(list) do
        pos[p.name] = i
      end
      R.assert_true(pos["a"] < pos["b"], "a must precede b (before constraint)")
    end)

    R.it("chain of after constraints respected", function()
      pr._reset()
      pr.register(make_phase("c"), { priority = 30, after = { "b" } })
      pr.register(make_phase("b"), { priority = 20, after = { "a" } })
      pr.register(make_phase("a"), { priority = 10 })
      local list = pr.list()
      local pos = {}
      for i, p in ipairs(list) do
        pos[p.name] = i
      end
      R.assert_true(pos["a"] < pos["b"])
      R.assert_true(pos["b"] < pos["c"])
    end)

    R.it("priority used as tie-breaker within same dependency group", function()
      pr._reset()
      pr.register(make_phase("b"), { priority = 20 })
      pr.register(make_phase("a"), { priority = 10 })
      local list = pr.list()
      R.assert_eq(list[1].name, "a")
    end)
  end)

  -- ── codegen registration ──────────────────────────────────────────────────

  R.describe("register_codegen() / codegen()", function()
    R.it("register_codegen stores the codegen phase", function()
      pr._reset()
      local cg = make_phase("codegen")
      pr.register_codegen(cg)
      R.assert_eq(pr.codegen(), cg)
    end)

    R.it("phase_order() appends codegen name at end", function()
      pr._reset()
      pr.register(make_phase("collect"), { priority = 1 })
      pr.register_codegen(make_phase("codegen"))
      local order = pr.phase_order()
      R.assert_eq(order[#order], "codegen")
    end)
  end)

  -- ── default pipeline phases from pipeline.lua ─────────────────────────────

  R.describe("default pipeline phases", function()
    R.it("all 8 required phases are registered after pipeline load", function()
      local pipeline = require("runtime.pipeline")
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
      for i, p in ipairs(pipeline.PHASE_ORDER) do
        pos[p] = i
      end
      for _, name in ipairs(required) do
        R.assert_not_nil(pos[name], name .. " must be in PHASE_ORDER")
      end
    end)

    R.it("collect is always first", function()
      local pipeline = require("runtime.pipeline")
      R.assert_eq(pipeline.PHASE_ORDER[1], "collect")
    end)

    R.it("full dependency chain order preserved", function()
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
    end)

    R.it("PHASE_ORDER has >= 8 phases", function()
      R.assert_true(#require("runtime.pipeline").PHASE_ORDER >= 8)
    end)
  end)
end)
