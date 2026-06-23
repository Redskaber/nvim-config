-- spec/toolchain/strategy_spec.lua
-- toolchain: rules, mappings, strategy registry, conflict detection.

local R = require("spec._runner")

-- ── rules.resolve() ───────────────────────────────────────────────────────────

R.describe("toolchain.rules", function()
  local rules = require("toolchain.rules")

  -- ── system tools ──────────────────────────────────────────────────────────

  R.describe("system_tools whitelist", function()
    R.it("gofmt → use_mason=false (system managed)", function()
      R.assert_false(rules.resolve("gofmt", {}).use_mason)
    end)
    R.it("rustfmt → use_mason=false (system managed)", function()
      R.assert_false(rules.resolve("rustfmt", {}).use_mason)
    end)
    R.it("zigfmt → use_mason=false (system managed)", function()
      R.assert_false(rules.resolve("zigfmt", {}).use_mason)
    end)
    R.it("fish_indent → use_mason=false", function()
      R.assert_false(rules.resolve("fish_indent", {}).use_mason)
    end)
    R.it("git → use_mason=false", function()
      R.assert_false(rules.resolve("git", {}).use_mason)
    end)
  end)

  -- ── identity fallback ─────────────────────────────────────────────────────

  R.describe("identity fallback", function()
    R.it("unknown tool → use_mason=true, pkg=tool name", function()
      local r = rules.resolve("my_unknown_tool_xyz", {})
      R.assert_true(r.use_mason)
      R.assert_eq(r.pkg, "my_unknown_tool_xyz")
    end)
  end)

  -- ── explicit mappings ─────────────────────────────────────────────────────

  R.describe("explicit tool → mason mappings", function()
    R.it("ruff_format → mason pkg = 'ruff'", function()
      local r = rules.resolve("ruff_format", {})
      R.assert_true(r.use_mason)
      R.assert_eq(r.pkg, "ruff")
    end)
    R.it("clang-format → mapped package", function()
      local env = require("core.kernel.env")
      -- FIX-NIX-AWARE (2026-06-23): on NixOS with system clang-format,
      -- nix_env_rule wins (use_mason=false). Only assert mason mapping
      -- on non-Nix systems or when clang-format is not on PATH.
      if env.is_nix and env.has("clang-format") then
        -- Nix system binary takes precedence — assert system path
        local r = rules.resolve("clang-format", {})
        R.assert_false(r.use_mason, "on Nix with system clang-format, use_mason should be false")
        R.assert_nil(r.pkg, "on Nix with system clang-format, pkg should be nil")
      else
        -- Non-Nix or no system clang-format — assert mason mapping
        local r = rules.resolve("clang-format", {})
        R.assert_true(r.use_mason)
        R.assert_eq(r.pkg, "clang-format")
      end
    end)
  end)

  -- ── user overrides ────────────────────────────────────────────────────────

  R.describe("user overrides (highest priority)", function()
    R.it("override use_mason=false forces system path", function()
      local r = rules.resolve("ruff", { ruff = { use_mason = false, pkg = nil } })
      R.assert_false(r.use_mason)
    end)
    R.it("override use_mason=true with custom pkg", function()
      local r = rules.resolve("mytool", { mytool = { use_mason = true, pkg = "my-mason-pkg" } })
      R.assert_true(r.use_mason)
      R.assert_eq(r.pkg, "my-mason-pkg")
    end)
  end)

  -- ── nix / prefer_system context ───────────────────────────────────────────

  R.describe("prefer_system context (nix profile)", function()
    R.it("prefer_system=false → no forced system override", function()
      -- stylua is not a system tool, so with prefer_system=false it should be mason
      local r = rules.resolve("stylua", {}, { prefer_system = false })
      R.assert_true(r.use_mason)
    end)
  end)

  -- ── use_mason() convenience ───────────────────────────────────────────────

  R.describe("use_mason() convenience wrapper", function()
    R.it("returns boolean", function()
      R.assert_type(rules.use_mason("stylua", {}, {}), "boolean")
    end)
    R.it("gofmt → false", function()
      R.assert_false(rules.use_mason("gofmt", {}))
    end)
    R.it("unknown tool → true", function()
      R.assert_true(rules.use_mason("unknown_tool_abc", {}))
    end)
  end)
end)

-- ── toolchain.mappings ────────────────────────────────────────────────────────

R.describe("toolchain.mappings", function()
  local mappings = require("toolchain.mappings")

  -- ── lsp_pkg() ─────────────────────────────────────────────────────────────

  R.describe("lsp_pkg()", function()
    R.it("lua_ls → lua-language-server", function()
      R.assert_eq(mappings.lsp_pkg("lua_ls"), "lua-language-server")
    end)
    R.it("rust_analyzer → rust-analyzer", function()
      R.assert_eq(mappings.lsp_pkg("rust_analyzer"), "rust-analyzer")
    end)
    R.it("unknown server → identity (server name as pkg)", function()
      R.assert_eq(mappings.lsp_pkg("my_custom_lsp"), "my_custom_lsp")
    end)
  end)

  -- ── tool_pkg() ────────────────────────────────────────────────────────────

  R.describe("tool_pkg()", function()
    R.it("system tool → nil", function()
      R.assert_nil(mappings.tool_pkg("rustfmt"))
    end)
    R.it("ruff_format → ruff", function()
      R.assert_eq(mappings.tool_pkg("ruff_format"), "ruff")
    end)
  end)

  -- ── resolve() ─────────────────────────────────────────────────────────────

  R.describe("resolve()", function()
    R.it("system tool → use_mason=false", function()
      R.assert_false(mappings.resolve("git").use_mason)
      R.assert_false(mappings.resolve("gofmt").use_mason)
    end)
    R.it("regular tool → use_mason=true", function()
      R.assert_true(mappings.resolve("ruff").use_mason)
    end)
    R.it("ruff_format → pkg=ruff", function()
      local r = mappings.resolve("ruff_format")
      R.assert_true(r.use_mason)
      R.assert_eq(r.pkg, "ruff")
    end)
  end)

  -- ── register extension API ────────────────────────────────────────────────

  R.describe("register_lsp / register_tool", function()
    R.it("register_lsp() adds entry to lsp_to_mason", function()
      mappings.register_lsp("test_lsp_xyz", "test-lsp-pkg")
      R.assert_eq(mappings.lsp_pkg("test_lsp_xyz"), "test-lsp-pkg")
      -- cleanup
      mappings.lsp_to_mason["test_lsp_xyz"] = nil
    end)
    R.it("register_tool() adds entry to tool_to_mason", function()
      mappings.register_tool("test_tool_xyz", "test-tool-pkg")
      R.assert_eq(mappings.tool_pkg("test_tool_xyz"), "test-tool-pkg")
      -- cleanup
      mappings.tool_to_mason["test_tool_xyz"] = nil
    end)
  end)
end)

-- ── strategy registry ─────────────────────────────────────────────────────────

R.describe("toolchain.strategy.registry", function()
  local reg = require("toolchain.strategy.registry")

  R.before_each(function()
    -- ensure bootstrapped before each test
    reg.bootstrap()
  end)

  R.it("bootstrap() registers built-in strategies", function()
    local list = reg.list()
    R.assert_true(#list >= 3)
  end)

  R.it("ruff_or_black strategy is registered", function()
    R.assert_not_nil(reg.get("ruff_or_black"))
  end)

  R.it("prettierd_or_prettier strategy is registered", function()
    R.assert_not_nil(reg.get("prettierd_or_prettier"))
  end)

  R.it("stylua_or_lua_format strategy is registered", function()
    R.assert_not_nil(reg.get("stylua_or_lua_format"))
  end)

  R.it("get() returns nil for unknown strategy", function()
    R.assert_nil(reg.get("nonexistent_strategy_xyz"))
  end)

  R.it("each strategy has resolve function", function()
    for _, name in ipairs(reg.list()) do
      local s = reg.get(name)
      R.assert_type(s.resolve, "function", name .. ".resolve must be a function")
    end
  end)

  R.it("each strategy has name and priority", function()
    for _, name in ipairs(reg.list()) do
      local s = reg.get(name)
      R.assert_type(s.name, "string", name .. ".name must be a string")
      R.assert_type(s.priority, "number", name .. ".priority must be a number")
    end
  end)

  R.it("list() is sorted", function()
    local list = reg.list()
    for i = 2, #list do
      R.assert_true(list[i - 1] <= list[i], "list must be sorted")
    end
  end)

  R.it("register() after lock() throws", function()
    -- bootstrap() calls lock(); subsequent register should error
    R.assert_false(pcall(reg.register, "new_strat", function()
      return {}
    end))
  end)

  R.it("resolve() multi-dispatch finds strategy by name", function()
    local s = reg.resolve("formatter", "ruff_or_black")
    R.assert_not_nil(s)
    R.assert_eq(s.name, "ruff_or_black")
  end)
end)

-- ── strategy.builtin ─────────────────────────────────────────────────────────

R.describe("toolchain.strategy.builtin", function()
  local builtin = require("toolchain.strategy.builtin")

  R.it("bootstrap() accepts a registry-like object", function()
    local registered = {}
    local fake_registry = {
      -- FIX-AUDIT-STRATEGY (2026-06-23): register is called as
      -- registry.register(strategy) (function call, no self).
      register = function(s)
        registered[#registered + 1] = s.name
      end,
    }
    builtin.bootstrap(fake_registry)
    R.assert_true(#registered >= 3)
  end)

  R.it("all built-in strategies have applies() function", function()
    local registered = {}
    builtin.bootstrap({
      register = function(s)
        registered[#registered + 1] = s
      end,
    })
    for _, s in ipairs(registered) do
      R.assert_type(s.applies, "function", s.name .. ".applies must be a function")
    end
  end)
end)

-- ── conflict detection ────────────────────────────────────────────────────────

R.describe("toolchain.strategy.conflict", function()
  local conflict = require("toolchain.strategy.conflict")

  local function make_strategy(name, priority, applies_tool)
    return {
      name = name,
      priority = priority,
      applies = function(t)
        return t == (applies_tool or name)
      end,
      resolve = function()
        return { name }
      end,
    }
  end

  -- ── find_applicable() ─────────────────────────────────────────────────────

  R.describe("find_applicable()", function()
    R.it("returns strategies that apply to the tool", function()
      local s1 = make_strategy("a", 10, "tool")
      local s2 = make_strategy("b", 20, "other")
      local s3 = make_strategy("c", 30, "tool")
      local applicable = conflict.find_applicable("tool", { s1, s2, s3 })
      R.assert_eq(#applicable, 2)
    end)
    R.it("returns empty list when none apply", function()
      local applicable = conflict.find_applicable("xyz", {
        make_strategy("a", 10, "not_xyz"),
      })
      R.assert_eq(#applicable, 0)
    end)
    R.it("gracefully skips strategies that throw in applies()", function()
      local broken = {
        name = "broken",
        priority = 50,
        applies = function()
          error("boom")
        end,
        resolve = function()
          return {}
        end,
      }
      local applicable = conflict.find_applicable("tool", { broken })
      R.assert_eq(#applicable, 0, "broken strategy must be skipped")
    end)
  end)

  -- ── detect() ──────────────────────────────────────────────────────────────

  R.describe("detect()", function()
    R.it("no conflict for strategies with different priorities", function()
      local has_conflict = conflict.detect({
        make_strategy("a", 10),
        make_strategy("b", 20),
      })
      R.assert_false(has_conflict)
    end)
    R.it("conflict detected for same priority", function()
      local has_conflict = conflict.detect({
        make_strategy("a", 10),
        make_strategy("b", 10),
      })
      R.assert_true(has_conflict)
    end)
  end)

  -- ── resolve() ─────────────────────────────────────────────────────────────

  R.describe("resolve()", function()
    R.it("single strategy → winner = that strategy", function()
      local s = make_strategy("only", 10)
      local r = conflict.resolve("tool", { s })
      R.assert_eq(r.winner.name, "only")
      R.assert_eq(r.resolution, conflict.RESOLUTION.PRIORITY)
    end)

    R.it("highest priority wins", function()
      local s1 = make_strategy("low", 10)
      local s2 = make_strategy("high", 50)
      local r = conflict.resolve("tool", { s1, s2 })
      R.assert_eq(r.winner.name, "high")
    end)

    R.it("empty strategies → winner=nil", function()
      local r = conflict.resolve("tool", {})
      R.assert_nil(r.winner)
    end)

    R.it("same priority without compose → AMBIGUOUS resolution", function()
      local s1 = make_strategy("a", 10)
      local s2 = make_strategy("b", 10)
      local r = conflict.resolve("tool", { s1, s2 })
      R.assert_eq(r.resolution, conflict.RESOLUTION.AMBIGUOUS)
      R.assert_nil(r.winner)
    end)

    R.it("same priority with compose=true → COMPOSE resolution", function()
      local s1 = make_strategy("a", 10)
      local s2 = make_strategy("b", 10)
      local r = conflict.resolve("tool", { s1, s2 }, true)
      R.assert_eq(r.resolution, conflict.RESOLUTION.COMPOSE)
      R.assert_not_nil(r.winner)
    end)
  end)

  -- ── Invariant 15: conflict.lua must not write strategy registry ───────────

  R.describe("Invariant 15", function()
    R.it("conflict.resolve() does not mutate StrategyRegistry", function()
      local reg = require("toolchain.strategy.registry")
      local before = reg.list()
      conflict.resolve("tool", {
        make_strategy("a", 10),
        make_strategy("b", 20),
      })
      local after = reg.list()
      R.assert_eq(#before, #after, "registry must not be mutated by conflict analysis")
    end)
  end)
end)