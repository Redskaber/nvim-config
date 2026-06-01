-- spec/integration/full_pipeline_spec.lua
-- End-to-end golden tests: full pipeline → LazySpec[] shape contracts.

local R = require("spec._runner")

R.describe("integration: full pipeline", function()
  local pipeline = require("runtime.pipeline")

  -- All 5 lang adapter plugins must appear for any single-language run
  local REQUIRED_PLUGINS = {
    "neovim/nvim-lspconfig",
    "mason-org/mason.nvim",
    "nvim-treesitter/nvim-treesitter",
    "stevearc/conform.nvim",
    "mfussenegger/nvim-lint",
  }

  local function plugin_set(specs)
    local s = {}
    for _, spec in ipairs(specs) do
      if type(spec[1]) == "string" then
        s[spec[1]] = true
      end
    end
    return s
  end

  R.describe("lua_lang", function()
    local specs, ir

    R.before_each(function()
      specs, ir = pipeline.run({ "modules.lang.lua_lang" }, "full")
    end)

    R.it("all 5 lang adapter plugins present", function()
      local ps = plugin_set(specs)
      for _, name in ipairs(REQUIRED_PLUGINS) do
        R.assert_true(ps[name], "missing plugin: " .. name)
      end
    end)

    R.it("all LTOS specs have _source with 'ltos:' prefix", function()
      local count = 0
      for _, s in ipairs(specs) do
        if s._source then
          R.assert_match(s._source, "^ltos:")
          count = count + 1
        end
      end
      R.assert_true(count >= 5)
    end)

    R.it("IR.caps.lua_lang survives to final IR", function()
      R.assert_not_nil(ir.caps.lua_lang)
    end)

    R.it("no diagnostics at error severity", function()
      R.assert_no_errors(ir)
    end)
  end)

  R.describe("rust (system tools)", function()
    R.it("rustfmt NOT in mason ensure_installed", function()
      local specs = pipeline.run({ "modules.lang.rust" }, "full")
      for _, s in ipairs(specs) do
        if s[1] == "mason-org/mason.nvim" then
          local ei = s.opts and s.opts.ensure_installed or {}
          for _, pkg in ipairs(ei) do
            R.assert_ne(pkg, "rustfmt", "rustfmt must not be mason-managed")
          end
          return
        end
      end
    end)
  end)

  R.describe("multi-language dedup", function()
    R.it("no duplicate parsers in treesitter ensure_installed", function()
      local specs = pipeline.run({
        "modules.lang.lua_lang",
        "modules.lang.python",
        "modules.lang.typescript",
      }, "full")
      for _, s in ipairs(specs) do
        if s[1] == "nvim-treesitter/nvim-treesitter" then
          local ei = s.opts and s.opts.ensure_installed or {}
          local seen = {}
          for _, p in ipairs(ei) do
            R.assert_true(not seen[p], "duplicate parser: " .. p)
            seen[p] = true
          end
          return
        end
      end
    end)

    R.it("no duplicate LSP servers in mason-lspconfig ensure_installed", function()
      local specs = pipeline.run({
        "modules.lang.lua_lang",
        "modules.lang.python",
      }, "full")
      for _, s in ipairs(specs) do
        if s[1] == "mason-org/mason-lspconfig.nvim" then
          local ei = s.opts and s.opts.ensure_installed or {}
          local seen = {}
          for _, sv in ipairs(ei) do
            R.assert_true(not seen[sv], "duplicate server: " .. sv)
            seen[sv] = true
          end
          return
        end
      end
    end)
  end)

  R.describe("cap modules integration", function()
    R.it("image.nvim appears when cap module registered", function()
      local collect_ext = require("runtime.passes.collect_ext")
      collect_ext.register({ "modules.cap.image" })
      local specs = pipeline.run({ "modules.lang.lua_lang" }, "full")
      local found = false
      for _, s in ipairs(specs) do
        if s[1] == "3rd/image.nvim" then
          found = true
          break
        end
      end
      R.assert_true(found, "image.nvim must appear from cap module")
    end)
  end)

  R.describe("BuildRequest passthrough", function()
    R.it("build_request in IR.meta after full run", function()
      local _, ir = pipeline.run({ "modules.lang.lua_lang" }, "full")
      R.assert_not_nil(ir.meta.build_request)
      R.assert_type(ir.meta.build_request.profile, "string")
    end)
  end)
end)
