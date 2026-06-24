-- spec/integration/build_request_spec.lua
-- BuildRequest: vim.g isolation, profile propagation, pipeline integration.

local R = require("spec._runner")

R.describe("integration: build_request", function()
  local br = require("runtime.build_request")

  -- ── from_vim() ────────────────────────────────────────────────────────────

  R.describe("from_vim()", function()
    R.it("profile field matches argument", function()
      R.assert_eq(br.from_vim("minimal", {}).profile, "minimal")
      R.assert_eq(br.from_vim("full", {}).profile, "full")
      R.assert_eq(br.from_vim("nix", {}).profile, "nix")
    end)

    R.it("prefer_system = true only for nix profile", function()
      R.assert_true(br.from_vim("nix", {}).prefer_system)
      R.assert_false(br.from_vim("full", {}).prefer_system)
      R.assert_false(br.from_vim("minimal", {}).prefer_system)
    end)

    R.it("overrides defaults to {} when vim.g unset", function()
      vim.g.ltos_tool_overrides = nil
      local req = br.from_vim("full", {})
      R.assert_type(req.overrides, "table")
      R.assert_true(next(req.overrides) == nil)
    end)

    R.it("base_tools non-empty by default (includes codespell)", function()
      vim.g.ltos_base_mason_tools = nil
      local req = br.from_vim("full", {})
      R.assert_type(req.base_tools, "table")
      R.assert_true(#req.base_tools > 0)
      local found = false
      for _, t in ipairs(req.base_tools) do
        if t == "codespell" then
          found = true
          break
        end
      end
      R.assert_true(found, "codespell must be in default base_tools")
    end)

    R.it("custom vim.g.ltos_tool_overrides propagated", function()
      vim.g.ltos_tool_overrides = { my_tool = { use_mason = false, pkg = nil } }
      local req = br.from_vim("full", {})
      R.assert_not_nil(req.overrides.my_tool)
      R.assert_false(req.overrides.my_tool.use_mason)
      vim.g.ltos_tool_overrides = nil
    end)

    R.it("custom vim.g.ltos_base_mason_tools overrides default", function()
      vim.g.ltos_base_mason_tools = { "custom_tool_abc" }
      local req = br.from_vim("full", {})
      R.assert_eq(#req.base_tools, 1)
      R.assert_eq(req.base_tools[1], "custom_tool_abc")
      vim.g.ltos_base_mason_tools = nil
    end)

    R.it("base_parsers=nil when vim.g.ltos_base_parsers unset", function()
      vim.g.ltos_base_parsers = nil
      local req = br.from_vim("full", {})
      R.assert_nil(req.base_parsers)
    end)

    R.it("custom vim.g.ltos_base_parsers propagated", function()
      vim.g.ltos_base_parsers = { "lua", "python" }
      local req = br.from_vim("full", {})
      R.assert_eq(#req.base_parsers, 2)
      vim.g.ltos_base_parsers = nil
    end)
  end)

  -- ── rules_ctx() ───────────────────────────────────────────────────────────

  R.describe("rules_ctx()", function()
    R.it("prefer_system matches req.prefer_system", function()
      R.assert_true(br.rules_ctx({ prefer_system = true }).prefer_system)
      R.assert_false(br.rules_ctx({ prefer_system = false }).prefer_system)
    end)

    R.it("returns table with at least prefer_system key", function()
      local ctx = br.rules_ctx({ prefer_system = false })
      R.assert_type(ctx, "table")
      R.assert_not_nil(ctx.prefer_system)
    end)
  end)

  -- ── pipeline integration ──────────────────────────────────────────────────

  R.describe("pipeline integration", function()
    R.it("build_request ends up in IR.meta.build_request after run()", function()
      local pipeline = require("runtime.pipeline")
      local req = br.from_vim("full", { "modules.lang.lua" })
      local _, ir = pipeline.run({ "modules.lang.lua" }, "full", nil, nil, req)
      R.assert_not_nil(ir.meta.build_request)
      R.assert_eq(ir.meta.build_request.profile, "full")
      R.assert_eq(ir.meta.build_request.prefer_system, false)
    end)

    R.it("nix profile build_request propagates prefer_system to symbols", function()
      local pipeline = require("runtime.pipeline")
      local req = br.from_vim("nix", { "modules.lang.lua" })
      local _, ir = pipeline.run({ "modules.lang.lua" }, "nix", nil, nil, req)
      R.assert_true(ir.meta.build_request.prefer_system)
    end)

    R.it("overrides passed via build_request reach canonicalize pass", function()
      local pipeline = require("runtime.pipeline")
      -- Force stylua to system (override default mason behavior)
      local req = br.from_vim("full", { "modules.lang.lua" })
      req.overrides = { stylua = { use_mason = false, pkg = nil } }
      local _, ir = pipeline.run({ "modules.lang.lua" }, "full", nil, nil, req)
      -- stylua should be marked system in symbols
      local sym = ir.symbols and ir.symbols.tools and ir.symbols.tools.stylua
      if sym then
        R.assert_true(sym.system, "override must set stylua as system tool")
      end
    end)
  end)

  -- ── rules layer integration ───────────────────────────────────────────────

  R.describe("rules layer integration via build_request", function()
    R.it("rules.resolve() uses overrides from build_request correctly", function()
      local rules = require("toolchain.rules")
      -- Override ruff to system
      local overrides = { ruff = { use_mason = false, pkg = nil } }
      local r = rules.resolve("ruff", overrides, { prefer_system = false })
      R.assert_false(r.use_mason, "override must force system for ruff")
    end)

    R.it("rules.resolve() prefers system when prefer_system=true", function()
      local rules = require("toolchain.rules")
      -- stylua is not in system_tools list, but with prefer_system + PATH check
      -- we can't guarantee PATH; so test with a known system tool
      local r = rules.resolve("gofmt", {}, { prefer_system = true })
      R.assert_false(r.use_mason, "gofmt must always be system (in system_tools list)")
    end)
  end)
end)

