-- spec/modules/ai_keybind_spec.lua
-- modules.ai.copilot, modules.cap.ai, modules.keybind.default:
-- DSL purity + schema conformance.

local R = require("spec._runner")

R.describe("modules.ai.copilot", function()
  local ext = require("core.domain.ext_schema")

  R.it("returns plain table with no metatable (Invariant 8)", function()
    local ok, m = pcall(require, "modules.ai.copilot")
    R.assert_true(ok, "modules.ai.copilot must load")
    R.assert_type(m, "table")
    R.assert_nil(getmetatable(m))
  end)

  R.it("declares cap_type = 'ai' and version = 1", function()
    local _, m = pcall(require, "modules.ai.copilot")
    R.assert_eq(m.cap_type, "ai")
    R.assert_eq(m.version, 1)
  end)

  R.it("passes ext_schema validation (P6-C5)", function()
    local _, m = pcall(require, "modules.ai.copilot")
    local r = ext.validate("ai", "modules.ai.copilot", m)
    R.assert_true(r.ok, "copilot DSL must pass schema: " .. ext.format_diags(r.diags))
  end)

  R.it("declares both completion and chat providers", function()
    local _, m = pcall(require, "modules.ai.copilot")
    R.assert_not_nil(m.completion)
    R.assert_not_nil(m.chat)
    R.assert_eq(m.completion.provider, "copilot")
  end)

  R.it("plugins list is non-empty and each entry has a name", function()
    local _, m = pcall(require, "modules.ai.copilot")
    R.assert_type(m.plugins, "table")
    R.assert_true(#m.plugins >= 1)
    for _, p in ipairs(m.plugins) do
      R.assert_type(p.name, "string")
      R.assert_true(#p.name > 0)
    end
  end)
end)

R.describe("modules.cap.ai", function()
  local ext = require("core.domain.ext_schema")

  R.it("pure DSL: no metatable", function()
    local _, m = pcall(require, "modules.cap.ai")
    R.assert_nil(getmetatable(m))
  end)

  R.it("passes ext_schema validation", function()
    local _, m = pcall(require, "modules.cap.ai")
    local r = ext.validate("ai", "modules.cap.ai", m)
    R.assert_true(r.ok, ext.format_diags(r.diags))
  end)
end)

R.describe("modules.keybind.default", function()
  local ext = require("core.domain.ext_schema")

  R.it("pure DSL: no metatable, cap_type=keybind", function()
    local _, m = pcall(require, "modules.keybind.default")
    R.assert_type(m, "table")
    R.assert_nil(getmetatable(m))
    R.assert_eq(m.cap_type, "keybind")
  end)

  R.it("bindings list entries have lhs and rhs", function()
    local _, m = pcall(require, "modules.keybind.default")
    if m.bindings then
      for _, b in ipairs(m.bindings) do
        R.assert_not_nil(b.lhs, "binding must have lhs")
        R.assert_not_nil(b.rhs, "binding must have rhs")
      end
    end
  end)
end)

R.describe("modules.cap.image", function()
  local ext = require("core.domain.ext_schema")

  R.it("passes ext_schema validation", function()
    local _, m = pcall(require, "modules.cap.image")
    local r = ext.validate("image", "modules.cap.image", m)
    R.assert_true(r.ok, ext.format_diags(r.diags))
  end)
end)

R.describe("modules.cap.media", function()
  local ext = require("core.domain.ext_schema")

  R.it("passes ext_schema validation", function()
    local _, m = pcall(require, "modules.cap.media")
    local r = ext.validate("media", "modules.cap.media", m)
    R.assert_true(r.ok, ext.format_diags(r.diags))
  end)
end)

R.describe("modules.cap.keybind", function()
  local ext = require("core.domain.ext_schema")

  R.it("passes ext_schema validation", function()
    local _, m = pcall(require, "modules.cap.keybind")
    local r = ext.validate("keybind", "modules.cap.keybind", m)
    R.assert_true(r.ok, ext.format_diags(r.diags))
  end)
end)