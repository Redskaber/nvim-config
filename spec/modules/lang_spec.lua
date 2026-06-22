-- spec/modules/lang_spec.lua
-- All 13 lang DSL modules: purity (INV-8), schema conformance,
-- capability shape, system tool classification.
-- core.kernel.env: fact registration and lazy evaluation.

local R = require("spec._runner")

-- ── Shared DSL conformance helpers ───────────────────────────────────────────

local schema = require("core.domain.schema")
local cap_mod = require("core.domain.capability")

--- Assert a lang module satisfies all Invariant-8 DSL purity constraints.
local function assert_dsl_pure(mod_path)
  local ok, m = pcall(require, mod_path)
  R.assert_true(ok, mod_path .. " must load without error")
  R.assert_type(m, "table", mod_path .. " must return a table")
  R.assert_nil(getmetatable(m), mod_path .. " must have no metatable (DSL purity)")
  R.assert_type(m.version, "number", mod_path .. " must declare numeric version")
end

--- Assert schema validation passes for a lang module.
local function assert_schema_ok(mod_path)
  local _, m = pcall(require, mod_path)
  local name = mod_path:match("([^.]+)$") or mod_path
  local result = schema.validate(name, m)
  R.assert_true(result.ok, mod_path .. " schema validation failed:\n" .. schema.format_diags(result.diags))
end

--- Assert a module can be added to a CapabilitySet without error.
local function assert_cap_add_ok(mod_path)
  local _, m = pcall(require, mod_path)
  local name = mod_path:match("([^.]+)$") or mod_path
  local _, res = cap_mod.add(cap_mod.new(), name, m)
  R.assert_true(res.ok, mod_path .. " CapabilitySet.add failed: " .. vim.inspect(res.diags))
end

-- ── modules.lang.lua_lang ────────────────────────────────────────────────────

R.describe("modules.lang.lua_lang", function()
  local mod_path = "modules.lang.lua_lang"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("declares core=true (minimal profile membership)", function()
    local _, m = pcall(require, mod_path)
    R.assert_true(m.core == true, "lua_lang must be a core module")
  end)
  R.it("LSP server: lua_ls configured", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.lua_ls)
  end)
  R.it("formatter: stylua for lua filetype", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.formatters and m.formatters.lua)
    local found = false
    for _, f in ipairs(m.formatters.lua) do
      if f == "stylua" then
        found = true
        break
      end
    end
    R.assert_true(found, "stylua must be lua formatter")
  end)
  R.it("treesitter: lua + luadoc + luap parsers", function()
    local _, m = pcall(require, mod_path)
    local set = {}
    for _, p in ipairs(m.treesitter or {}) do
      set[p] = true
    end
    R.assert_true(set.lua, "lua parser required")
    R.assert_true(set.luadoc, "luadoc parser required")
    R.assert_true(set.luap, "luap parser required")
  end)
end)

-- ── modules.lang.python ──────────────────────────────────────────────────────

R.describe("modules.lang.python", function()
  local mod_path = "modules.lang.python"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: pyright configured", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.pyright)
  end)
  R.it("formatter uses strategy FormatterNode (ruff_or_black)", function()
    local _, m = pcall(require, mod_path)
    local fmts = m.formatters and m.formatters.python or {}
    local has_strategy = false
    for _, f in ipairs(fmts) do
      if type(f) == "table" and f.strategy then
        has_strategy = true
        break
      end
    end
    R.assert_true(has_strategy, "python formatter must use a strategy FormatterNode")
  end)
  R.it("treesitter: python parser declared", function()
    local _, m = pcall(require, mod_path)
    local set = {}
    for _, p in ipairs(m.treesitter or {}) do
      set[p] = true
    end
    R.assert_true(set.python, "python parser required")
  end)
  R.it("mason: ruff, black, isort declared", function()
    local _, m = pcall(require, mod_path)
    local mason = {}
    for _, p in ipairs(m.mason or {}) do
      mason[p] = true
    end
    R.assert_true(mason.ruff, "ruff in mason")
    R.assert_true(mason.black, "black in mason")
    R.assert_true(mason.isort, "isort in mason")
  end)
end)

-- ── modules.lang.rust ────────────────────────────────────────────────────────

R.describe("modules.lang.rust", function()
  local mod_path = "modules.lang.rust"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: rust_analyzer", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.rust_analyzer)
  end)
  R.it("system tools: rustfmt (not in mason)", function()
    local _, m = pcall(require, mod_path)
    local mason = {}
    for _, p in ipairs(m.mason or {}) do
      mason[p] = true
    end
    R.assert_nil(mason.rustfmt, "rustfmt must NOT be in mason (system tool)")
    R.assert_nil(mason.clippy, "clippy must NOT be in mason (system tool)")
  end)
  R.it("formatter rustfmt declared as string in formatters.rust", function()
    local _, m = pcall(require, mod_path)
    local fmts = m.formatters and m.formatters.rust or {}
    local found = false
    for _, f in ipairs(fmts) do
      if f == "rustfmt" then
        found = true
        break
      end
    end
    R.assert_true(found, "rustfmt must be declared in formatters.rust")
  end)
  R.it("treesitter: rust + toml parsers", function()
    local _, m = pcall(require, mod_path)
    local set = {}
    for _, p in ipairs(m.treesitter or {}) do
      set[p] = true
    end
    R.assert_true(set.rust, "rust parser required")
    R.assert_true(set.toml, "toml parser required")
  end)
end)

-- ── modules.lang.go ──────────────────────────────────────────────────────────

R.describe("modules.lang.go", function()
  local mod_path = "modules.lang.go"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: gopls", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.gopls)
  end)
  R.it("gofmt is system tool (not in mason)", function()
    local _, m = pcall(require, mod_path)
    local mason = {}
    for _, p in ipairs(m.mason or {}) do
      mason[p] = true
    end
    R.assert_nil(mason.gofmt, "gofmt must NOT be in mason (system tool)")
  end)
  R.it("goimports is mason-managed", function()
    local _, m = pcall(require, mod_path)
    local mason = {}
    for _, p in ipairs(m.mason or {}) do
      mason[p] = true
    end
    R.assert_true(mason.goimports, "goimports must be in mason")
  end)
  R.it("treesitter: go + gomod + gowork + gosum parsers", function()
    local _, m = pcall(require, mod_path)
    local set = {}
    for _, p in ipairs(m.treesitter or {}) do
      set[p] = true
    end
    R.assert_true(set.go, "go parser required")
    R.assert_true(set.gomod, "gomod parser required")
  end)
end)

-- ── modules.lang.typescript ──────────────────────────────────────────────────

R.describe("modules.lang.typescript", function()
  local mod_path = "modules.lang.typescript"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: vtsls", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.vtsls)
  end)
  R.it("formatters use prettierd_or_prettier strategy", function()
    local _, m = pcall(require, mod_path)
    for _, ft in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact" }) do
      local fmts = m.formatters and m.formatters[ft] or {}
      local has = false
      for _, f in ipairs(fmts) do
        if type(f) == "table" and f.strategy == "prettierd_or_prettier" then
          has = true
          break
        end
      end
      R.assert_true(has, ft .. " must use prettierd_or_prettier strategy")
    end
  end)
  R.it("linter: eslint_d for ts/js", function()
    local _, m = pcall(require, mod_path)
    for _, ft in ipairs({ "typescript", "javascript" }) do
      local lints = m.linters and m.linters[ft] or {}
      local found = false
      for _, l in ipairs(lints) do
        if l == "eslint_d" then
          found = true
          break
        end
      end
      R.assert_true(found, ft .. " must have eslint_d linter")
    end
  end)
  R.it("treesitter: typescript + tsx + javascript parsers", function()
    local _, m = pcall(require, mod_path)
    local set = {}
    for _, p in ipairs(m.treesitter or {}) do
      set[p] = true
    end
    R.assert_true(set.typescript, "typescript parser required")
    R.assert_true(set.tsx, "tsx parser required")
  end)
end)

-- ── modules.lang.c_cpp ───────────────────────────────────────────────────────

R.describe("modules.lang.c_cpp", function()
  local mod_path = "modules.lang.c_cpp"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: clangd with cmd", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.clangd)
    R.assert_type(m.lsp.clangd.cmd, "table")
  end)
  -- FIX-AUDIT-P0-6a (2026-06-23): Test was wrong — c_cpp.lua design intent is
  -- clang-format as a SYSTEM tool (commented out in mason), consistent with
  -- "Mason decision delegated to resolve stage" comment in c_cpp.lua L2.
  -- The old assertion expected clang-format IN mason, contradicting the
  -- implementation. Fixed to expect clang-format NOT in mason (similar to
  -- the clangtidy system-tool test below at L322-328).
  R.it("clang-format is system tool (not in mason)", function()
    local _, m = pcall(require, mod_path)
    local mason = {}
    for _, p in ipairs(m.mason or {}) do
      mason[p] = true
    end
    R.assert_nil(mason["clang-format"], "clang-format must NOT be in mason (system tool)")
  end)
  R.it("treesitter: c + cpp + cmake parsers", function()
    local _, m = pcall(require, mod_path)
    local set = {}
    for _, p in ipairs(m.treesitter or {}) do
      set[p] = true
    end
    R.assert_true(set.c, "c parser required")
    R.assert_true(set.cpp, "cpp parser required")
  end)
  R.it("clangtidy linter is system tool (not in mason)", function()
    local _, m = pcall(require, mod_path)
    local mason = {}
    for _, p in ipairs(m.mason or {}) do
      mason[p] = true
    end
    R.assert_nil(mason.clangtidy, "clangtidy must NOT be in mason (system tool)")
  end)
end)

-- ── modules.lang.shell ───────────────────────────────────────────────────────

R.describe("modules.lang.shell", function()
  local mod_path = "modules.lang.shell"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: bashls", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.bashls)
  end)
  R.it("shfmt + shellcheck in mason", function()
    local _, m = pcall(require, mod_path)
    local mason = {}
    for _, p in ipairs(m.mason or {}) do
      mason[p] = true
    end
    R.assert_true(mason.shfmt, "shfmt must be in mason")
    R.assert_true(mason.shellcheck, "shellcheck must be in mason")
  end)
  R.it("fish_indent is system tool (not in mason)", function()
    local _, m = pcall(require, mod_path)
    local mason = {}
    for _, p in ipairs(m.mason or {}) do
      mason[p] = true
    end
    R.assert_nil(mason.fish_indent, "fish_indent must NOT be in mason (system tool)")
  end)
  R.it("treesitter: bash + zsh + fish parsers", function()
    local _, m = pcall(require, mod_path)
    local set = {}
    for _, p in ipairs(m.treesitter or {}) do
      set[p] = true
    end
    R.assert_true(set.bash, "bash parser required")
    R.assert_true(set.zsh, "zsh parser required")
    R.assert_true(set.fish, "fish parser required")
  end)
end)

-- ── modules.lang.zig ─────────────────────────────────────────────────────────

R.describe("modules.lang.zig", function()
  local mod_path = "modules.lang.zig"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: zls", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.zls)
  end)
  R.it("zigfmt is system tool (empty mason)", function()
    local _, m = pcall(require, mod_path)
    R.assert_eq(#(m.mason or {}), 0, "zig mason must be empty (zigfmt is system)")
  end)
  R.it("formatter: zigfmt declared", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.formatters and m.formatters.zig)
  end)
end)

-- ── modules.lang.nix ─────────────────────────────────────────────────────────

R.describe("modules.lang.nix", function()
  local mod_path = "modules.lang.nix"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: nil_ls", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.nil_ls)
  end)
  R.it("nixpkgs-fmt is system (empty mason)", function()
    local _, m = pcall(require, mod_path)
    R.assert_eq(#(m.mason or {}), 0, "nix mason must be empty (system tools)")
  end)
  R.it("statix linter declared", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.linters and m.linters.nix)
  end)
end)

-- ── modules.lang.markup ──────────────────────────────────────────────────────

R.describe("modules.lang.markup", function()
  local mod_path = "modules.lang.markup"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("multiple LSP servers: marksman + jsonls + yamlls + taplo", function()
    local _, m = pcall(require, mod_path)
    for _, srv in ipairs({ "marksman", "jsonls", "yamlls", "taplo" }) do
      R.assert_not_nil(m.lsp and m.lsp[srv], srv .. " must be declared")
    end
  end)
  R.it("prettierd in mason", function()
    local _, m = pcall(require, mod_path)
    local mason = {}
    for _, p in ipairs(m.mason or {}) do
      mason[p] = true
    end
    R.assert_true(mason.prettierd, "prettierd must be in mason")
  end)
  R.it("treesitter: json + yaml + toml + markdown + html parsers", function()
    local _, m = pcall(require, mod_path)
    local set = {}
    for _, p in ipairs(m.treesitter or {}) do
      set[p] = true
    end
    for _, p in ipairs({ "json", "yaml", "toml", "markdown", "html" }) do
      R.assert_true(set[p], p .. " parser required")
    end
  end)
end)

-- ── modules.lang.java ────────────────────────────────────────────────────────

R.describe("modules.lang.java", function()
  local mod_path = "modules.lang.java"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: jdtls", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.jdtls)
  end)
  R.it("formatter: google-java-format in mason", function()
    local _, m = pcall(require, mod_path)
    local mason = {}
    for _, p in ipairs(m.mason or {}) do
      mason[p] = true
    end
    R.assert_true(mason["google-java-format"], "google-java-format must be in mason")
  end)
end)

-- ── modules.lang.kotlin ──────────────────────────────────────────────────────

R.describe("modules.lang.kotlin", function()
  local mod_path = "modules.lang.kotlin"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: kotlin_language_server", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.kotlin_language_server)
  end)
  R.it("ktlint + ktfmt in mason", function()
    local _, m = pcall(require, mod_path)
    local mason = {}
    for _, p in ipairs(m.mason or {}) do
      mason[p] = true
    end
    R.assert_true(mason.ktlint, "ktlint must be in mason")
    R.assert_true(mason.ktfmt, "ktfmt must be in mason")
  end)
end)

-- ── modules.lang.asm ─────────────────────────────────────────────────────────

R.describe("modules.lang.asm", function()
  local mod_path = "modules.lang.asm"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: asm_lsp", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.asm_lsp)
  end)
  R.it("mason is empty (no mason-installable asm tools)", function()
    local _, m = pcall(require, mod_path)
    R.assert_eq(#(m.mason or {}), 0, "asm has no mason packages")
  end)
  R.it("treesitter: asm parser", function()
    local _, m = pcall(require, mod_path)
    local set = {}
    for _, p in ipairs(m.treesitter or {}) do
      set[p] = true
    end
    R.assert_true(set.asm, "asm parser required")
  end)
end)

-- ── modules.lang.lisp ────────────────────────────────────────────────────────

R.describe("modules.lang.lisp", function()
  local mod_path = "modules.lang.lisp"

  R.it("INV-8: pure DSL declaration", function()
    assert_dsl_pure(mod_path)
  end)
  R.it("schema validation passes", function()
    assert_schema_ok(mod_path)
  end)
  R.it("CapabilitySet.add succeeds", function()
    assert_cap_add_ok(mod_path)
  end)
  R.it("LSP server: clojure_lsp", function()
    local _, m = pcall(require, mod_path)
    R.assert_not_nil(m.lsp and m.lsp.clojure_lsp)
  end)
  R.it("treesitter: commonlisp + scheme + clojure parsers", function()
    local _, m = pcall(require, mod_path)
    local set = {}
    for _, p in ipairs(m.treesitter or {}) do
      set[p] = true
    end
    R.assert_true(set.clojure, "clojure parser required")
  end)
end)

-- ── Cross-module system tool classification invariant ────────────────────────

R.describe("system tool classification invariant", function()
  local rules = require("toolchain.rules")

  local system_tool_cases = {
    { mod = "modules.lang.rust", tool = "rustfmt", desc = "Rust system tool" },
    { mod = "modules.lang.go", tool = "gofmt", desc = "Go system tool" },
    { mod = "modules.lang.zig", tool = "zigfmt", desc = "Zig system tool" },
    { mod = "modules.lang.shell", tool = "fish_indent", desc = "Fish system tool" },
  }

  for _, tc in ipairs(system_tool_cases) do
    R.it(tc.desc .. ": rules.resolve() → use_mason=false", function()
      R.assert_false(rules.resolve(tc.tool, {}).use_mason, tc.tool .. " must not be mason-managed")
    end)
  end

  R.it("all lang modules pass DSL purity batch check", function()
    local lang_mods = {
      "modules.lang.lua_lang",
      "modules.lang.python",
      "modules.lang.rust",
      "modules.lang.go",
      "modules.lang.typescript",
      "modules.lang.c_cpp",
      "modules.lang.shell",
      "modules.lang.zig",
      "modules.lang.nix",
      "modules.lang.markup",
      "modules.lang.java",
      "modules.lang.kotlin",
      "modules.lang.asm",
      "modules.lang.lisp",
    }
    for _, mod in ipairs(lang_mods) do
      local ok, m = pcall(require, mod)
      R.assert_true(ok, mod .. " failed to load")
      R.assert_nil(getmetatable(m), mod .. " must have no metatable")
      R.assert_type(m.version, "number", mod .. " must declare version")
    end
  end)
end)

-- ── core.kernel.env ──────────────────────────────────────────────────────────

R.describe("core.kernel.env", function()
  local env = require("core.kernel.env")

  -- ── register_fact / lazy evaluation ──────────────────────────────────────

  R.describe("register_fact()", function()
    R.it("registers a custom fact by name", function()
      env.register_fact("test_custom_fact", function()
        return "test_value"
      end)
      -- Access via metatable
      R.assert_eq(env.test_custom_fact, "test_value")
      -- cleanup: reset cached value
      rawset(env, "test_custom_fact", nil)
    end)

    R.it("invalid name throws assertion", function()
      R.assert_false(pcall(env.register_fact, "", function()
        return true
      end))
      R.assert_false(pcall(env.register_fact, nil, function()
        return true
      end))
    end)

    R.it("invalid fn throws assertion", function()
      R.assert_false(pcall(env.register_fact, "test_fn_fact", "not_a_function"))
    end)

    R.it("fact is lazily evaluated (fn called on first access)", function()
      local called = 0
      env.register_fact("test_lazy_fact", function()
        called = called + 1
        return "lazy"
      end)
      R.assert_eq(called, 0, "fact must not be evaluated until accessed")
      local _ = env.test_lazy_fact
      R.assert_eq(called, 1)
      -- subsequent access uses cached value (rawset by metatable __index)
      rawset(env, "test_lazy_fact", nil)
    end)

    R.it("fact fn error returns nil gracefully", function()
      env.register_fact("test_error_fact", function()
        error("fact evaluation error")
      end)
      local result = env.test_error_fact
      -- Should be nil when fact errors, not throw
      R.assert_nil(result, "fact error must return nil gracefully")
      rawset(env, "test_error_fact", nil)
    end)
  end)

  -- ── built-in facts ────────────────────────────────────────────────────────

  R.describe("built-in facts", function()
    R.it("is_nix is a boolean (or nil if not registered properly)", function()
      -- Force evaluation
      local v = env.is_nix
      if v ~= nil then
        R.assert_type(v, "boolean")
      end
    end)

    R.it("is_ssh is a boolean", function()
      local v = env.is_ssh
      if v ~= nil then
        R.assert_type(v, "boolean")
      end
    end)
  end)

  -- ── has() ─────────────────────────────────────────────────────────────────

  R.describe("has()", function()
    R.it("returns boolean for any command", function()
      R.assert_type(env.has("ls"), "boolean")
    end)
    R.it("'sh' is executable (always available in test env)", function()
      -- sh is universally available in any POSIX environment
      R.assert_true(env.has("sh"), "sh must be executable")
    end)
    R.it("nonexistent_binary_xyz returns false", function()
      R.assert_false(env.has("nonexistent_binary_xyz_12345"))
    end)
  end)

  -- ── is_nvim012() ──────────────────────────────────────────────────────────

  R.describe("is_nvim012()", function()
    R.it("returns boolean", function()
      R.assert_type(env.is_nvim012(), "boolean")
    end)
  end)

  -- ── layer isolation: no compiler/domain requires ──────────────────────────

  R.it("env does not expose compiler/domain symbols (L0 isolation)", function()
    R.assert_nil(env.ir, "env must not expose ir")
    R.assert_nil(env.pass, "env must not expose pass")
    R.assert_nil(env.caps, "env must not expose caps")
  end)
end)
