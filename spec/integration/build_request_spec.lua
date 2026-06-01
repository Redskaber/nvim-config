-- spec/integration/build_request_spec.lua
-- BuildRequest: vim.g isolation + profile propagation through pipeline.

local R = require("spec._runner")

R.describe("integration: build_request", function()
  local br = require("runtime.build_request")

  R.describe("from_vim()", function()
    R.it("profile field matches argument", function()
      local req = br.from_vim("minimal", {})
      R.assert_eq(req.profile, "minimal")
    end)

    R.it("prefer_system=true only for 'nix' profile", function()
      R.assert_true(br.from_vim("nix", {}).prefer_system)
      R.assert_false(br.from_vim("full", {}).prefer_system)
      R.assert_false(br.from_vim("minimal", {}).prefer_system)
    end)

    R.it("overrides defaults to {} when vim.g.ltos_tool_overrides unset", function()
      vim.g.ltos_tool_overrides = nil
      local req = br.from_vim("full", {})
      R.assert_type(req.overrides, "table")
      R.assert_true(next(req.overrides) == nil)
    end)

    R.it("base_tools defaults to DEFAULT when vim.g.ltos_base_mason_tools unset", function()
      vim.g.ltos_base_mason_tools = nil
      local req = br.from_vim("full", {})
      R.assert_type(req.base_tools, "table")
      R.assert_true(#req.base_tools > 0)
    end)

    R.it("custom overrides propagated", function()
      vim.g.ltos_tool_overrides = { my_tool = { use_mason = false, pkg = nil } }
      local req = br.from_vim("full", {})
      R.assert_not_nil(req.overrides.my_tool)
      R.assert_false(req.overrides.my_tool.use_mason)
      vim.g.ltos_tool_overrides = nil
    end)
  end)

  R.describe("rules_ctx()", function()
    R.it("prefer_system matches profile", function()
      R.assert_true(br.rules_ctx({ prefer_system = true }).prefer_system)
      R.assert_false(br.rules_ctx({ prefer_system = false }).prefer_system)
    end)
  end)

  R.describe("pipeline integration", function()
    R.it("build_request ends up in IR.meta.build_request", function()
      local pipeline = require("runtime.pipeline")
      local req = br.from_vim("full", { "modules.lang.lua_lang" })
      local _, ir = pipeline.run({ "modules.lang.lua_lang" }, "full", nil, nil, req)
      R.assert_not_nil(ir.meta.build_request)
      R.assert_eq(ir.meta.build_request.profile, "full")
    end)
  end)
end)
