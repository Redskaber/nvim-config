-- spec/toolchain/mappings_data_spec.lua
-- toolchain.mappings: complete data integrity, extension API, resolve pipeline.
-- modules.capability.schema: generic capability schema validator.

local R = require("spec._runner")

-- ── toolchain.mappings: full data integrity ───────────────────────────────────

R.describe("toolchain.mappings: full data integrity", function()
  local mappings = require("toolchain.mappings")

  -- ── lsp_to_mason completeness ──────────────────────────────────────────────

  R.describe("lsp_to_mason completeness", function()
    local required_entries = {
      { server = "lua_ls", pkg = "lua-language-server" },
      { server = "rust_analyzer", pkg = "rust-analyzer" },
      { server = "pyright", pkg = "pyright" },
      { server = "gopls", pkg = "gopls" },
      { server = "vtsls", pkg = "vtsls" },
      { server = "bashls", pkg = "bash-language-server" },
      { server = "nil_ls", pkg = "nil" },
      { server = "jsonls", pkg = "json-lsp" },
      { server = "yamlls", pkg = "yaml-language-server" },
      { server = "taplo", pkg = "taplo" },
      { server = "clangd", pkg = "clangd" },
      { server = "zls", pkg = "zls" },
      { server = "jdtls", pkg = "jdtls" },
      { server = "kotlin_language_server", pkg = "kotlin-language-server" },
      { server = "clojure_lsp", pkg = "clojure-lsp" },
      { server = "asm_lsp", pkg = "asm-lsp" },
    }

    for _, entry in ipairs(required_entries) do
      R.it(
        entry.server .. " → " .. entry.pkg,
        function()
          R.assert_eq(
            mappings.lsp_pkg(entry.server),
            entry.pkg,
            entry.server .. " must map to " .. entry.pkg
          )
        end
      )
    end
  end)

  -- ── tool_to_mason completeness ────────────────────────────────────────────

  R.describe("tool_to_mason completeness", function()
    local required_entries = {
      { tool = "ruff_format", pkg = "ruff" },
      { tool = "google-java-format", pkg = "google-java-format" },
      { tool = "ktfmt", pkg = "ktfmt" },
      { tool = "ktlint", pkg = "ktlint" },
      { tool = "clang-format", pkg = "clang-format" },
      { tool = "checkstyle", pkg = "checkstyle" },
      { tool = "prettierd", pkg = "prettierd" },
      { tool = "prettier", pkg = "prettier" },
      { tool = "goimports", pkg = "goimports" },
      { tool = "shfmt", pkg = "shfmt" },
      { tool = "shellcheck", pkg = "shellcheck" },
    }

    for _, entry in ipairs(required_entries) do
      R.it(
        entry.tool .. " → " .. entry.pkg,
        function() R.assert_eq(mappings.tool_pkg(entry.tool), entry.pkg) end
      )
    end
  end)

  -- ── system_tools classification ───────────────────────────────────────────

  R.describe("system_tools classification", function()
    local system_tools = {
      "rustup",
      "nix",
      "git",
      "make",
      "cc",
      "rustfmt",
      "clippy",
      "gofmt",
      "zigfmt",
      "fish_indent",
      "fish",
      "nixpkgs_fmt",
      "clangtidy",
    }

    for _, tool in ipairs(system_tools) do
      R.it(
        tool .. " is marked system (tool_pkg returns nil)",
        function()
          R.assert_nil(
            mappings.tool_pkg(tool),
            tool .. " must return nil from tool_pkg (system tool)"
          )
        end
      )
    end

    R.it("lsp_pkg() for system server falls back to identity", function()
      -- No lsp servers are in system_tools, but unknown server uses identity
      R.assert_eq(mappings.lsp_pkg("unknown_server_xyz"), "unknown_server_xyz")
    end)
  end)

  -- ── resolve() ────────────────────────────────────────────────────────────

  R.describe("resolve()", function()
    R.it("system tool → use_mason=false, pkg=nil", function()
      local r = mappings.resolve("git")
      R.assert_false(r.use_mason)
      R.assert_nil(r.pkg)
    end)

    R.it("mapped tool → use_mason=true, correct pkg", function()
      local r = mappings.resolve("ruff_format")
      R.assert_true(r.use_mason)
      R.assert_eq(r.pkg, "ruff")
    end)

    R.it("unknown tool → use_mason=true, pkg=tool name (identity)", function()
      local r = mappings.resolve("unknown_tool_abc_xyz")
      R.assert_true(r.use_mason)
      R.assert_eq(r.pkg, "unknown_tool_abc_xyz")
    end)
  end)

  -- ── register extension API ────────────────────────────────────────────────

  R.describe("register extension API", function()
    R.it("register_lsp() adds entry and is reflected in lsp_pkg()", function()
      local test_server = "test_server_ext_" .. math.random(1e6)
      mappings.register_lsp(test_server, "test-server-pkg")
      R.assert_eq(mappings.lsp_pkg(test_server), "test-server-pkg")
      mappings.lsp_to_mason[test_server] = nil -- cleanup
    end)

    R.it("register_tool() adds entry and is reflected in tool_pkg()", function()
      local test_tool = "test_tool_ext_" .. math.random(1e6)
      mappings.register_tool(test_tool, "test-tool-pkg")
      R.assert_eq(mappings.tool_pkg(test_tool), "test-tool-pkg")
      mappings.tool_to_mason[test_tool] = nil -- cleanup
    end)

    R.it("register_override() stores override for use by rules", function()
      local test_tool = "test_override_ext_" .. math.random(1e6)
      mappings.register_override(test_tool, { use_mason = false, pkg = nil })
      R.assert_not_nil(mappings.overrides[test_tool])
      R.assert_false(mappings.overrides[test_tool].use_mason)
      mappings.overrides[test_tool] = nil -- cleanup
    end)
  end)

  -- ── no cross-contamination ────────────────────────────────────────────────

  R.describe("table isolation", function()
    R.it("lsp_to_mason and system_tools have no overlap", function()
      for server in pairs(mappings.lsp_to_mason) do
        R.assert_nil(
          mappings.system_tools[server],
          "LSP server " .. server .. " must not appear in system_tools"
        )
      end
    end)

    R.it("all lsp_to_mason values are non-empty strings", function()
      for server, pkg in pairs(mappings.lsp_to_mason) do
        R.assert_type(
          pkg,
          "string",
          "lsp_to_mason[" .. server .. "] must be string, got " .. type(pkg)
        )
        R.assert_true(#pkg > 0, "lsp_to_mason[" .. server .. "] must not be empty")
      end
    end)

    R.it("all tool_to_mason values are non-empty strings", function()
      for tool, pkg in pairs(mappings.tool_to_mason) do
        R.assert_type(pkg, "string")
        R.assert_true(#pkg > 0)
      end
    end)
  end)
end)

-- ── modules.capability.schema ─────────────────────────────────────────────────

R.describe("modules.capability.schema", function()
  local schema = require("modules.capability._schema")

  -- ── validate() shape ─────────────────────────────────────────────────────

  R.describe("validate()", function()
    R.it("returns { ok, diags } table", function()
      local result = schema.validate("test_mod", { cap_type = "image", version = 1 })
      R.assert_type(result, "table")
      R.assert_not_nil(result.ok)
      R.assert_type(result.diags, "table")
    end)

    R.it("non-table input → ok=false with message", function()
      local result = schema.validate("test_mod", "not_a_table")
      R.assert_false(result.ok)
      R.assert_true(#result.diags > 0)
    end)

    R.it("missing cap_type → ok=false", function()
      local result = schema.validate("test_mod", { version = 1 })
      R.assert_false(result.ok)
      local found = false
      for _, msg in ipairs(result.diags) do
        if type(msg) == "string" and msg:find("cap_type") then
          found = true
          break
        end
      end
      R.assert_true(found, "missing cap_type must produce diagnostic mentioning cap_type")
    end)

    R.it("missing version → ok=false", function()
      local result = schema.validate("test_mod", { cap_type = "image" })
      R.assert_false(result.ok)
    end)

    R.it("valid minimal image cap → ok=true", function()
      local result = schema.validate("test_mod", {
        cap_type = "image",
        version = 1,
        backend = "kitty",
      })
      R.assert_true(result.ok)
    end)

    R.it("valid minimal keybind cap → ok=true", function()
      local result = schema.validate("test_mod", {
        cap_type = "keybind",
        version = 1,
        preset = "vim",
      })
      R.assert_true(result.ok)
    end)

    R.it("keybind with invalid binding (missing lhs) → ok=false", function()
      local result = schema.validate("test_mod", {
        cap_type = "keybind",
        version = 1,
        bindings = { { rhs = "cmd" } }, -- missing lhs
      })
      R.assert_false(result.ok)
    end)

    R.it("keybind with known preset does not add negative diag", function()
      local result = schema.validate("test_mod", {
        cap_type = "keybind",
        version = 1,
        preset = "helix",
      })
      R.assert_true(result.ok)
      R.assert_eq(#result.diags, 0)
    end)

    R.it("image with non-string backend entry → ok=false", function()
      local result = schema.validate("test_mod", {
        cap_type = "image",
        version = 1,
        backends = { "kitty", 42 },
      })
      R.assert_false(result.ok)
    end)
  end)

  -- ── integration: all default cap modules pass ─────────────────────────────

  R.describe("all default cap modules pass capability schema", function()
    local cap_mods = {
      "modules.cap.image",
      "modules.cap.media",
      "modules.cap.ai",
      "modules.cap.keybind",
      "modules.editor.image",
      "modules.ai.copilot",
      "modules.keybind.default",
    }

    for _, mod_path in ipairs(cap_mods) do
      R.it(mod_path .. " passes capability schema", function()
        local ok, m = pcall(require, mod_path)
        R.assert_true(ok, mod_path .. " must load")
        local result = schema.validate(mod_path, m)
        R.assert_true(
          result.ok,
          mod_path .. " failed capability schema: " .. vim.inspect(result.diags)
        )
      end)
    end
  end)
end)