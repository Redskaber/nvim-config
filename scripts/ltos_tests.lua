-- scripts/ltos_tests.lua
-- Targeted tests for AUDIT remediation (run via nvim --headless).

require("runtime.ports_bootstrap").setup()

local function assert_eq(a, b, msg)
  if a ~= b then
    error(("%s: expected %s, got %s"):format(msg or "assert_eq", tostring(b), tostring(a)))
  end
end

local function assert_true(v, msg)
  if not v then
    error(msg or "assert_true failed")
  end
end

local function test_cache_version_unified()
  local v = require("core.compiler.cache.version")
  assert_eq(v.CACHE_VERSION, v.SCHEMA_VERSION, "cache version unified")
  assert_true(v.CACHE_VERSION >= 5, "version >= 5")
end

local function test_schema_diag_idempotent()
  local schema = require("core.domain.schema")
  local r1 = schema.validate("mod", { formatters = { lua = { 123 } } })
  local r2 = schema.validate("mod", { formatters = { lua = { 123 } } })
  assert_true(#r1.diags > 0 and #r2.diags > 0, "schema produces diags")
  assert_eq(r1.diags[1].code, r2.diags[1].code, "schema codes are path-deterministic")
end

local function test_rules_no_vimg()
  local rules = require("toolchain.rules")
  local r = rules.resolve("gofmt", {})
  assert_eq(r.use_mason, false, "gofmt is system tool")
  local r2 = rules.resolve("ruff", { ruff = { use_mason = false, pkg = nil } })
  assert_eq(r2.use_mason, false, "override injected via param")
end

local function test_mappings_register()
  local mappings = require("toolchain.mappings")
  mappings.register_tool("test_tool_xyz", "test-pkg-xyz")
  assert_eq(mappings.tool_to_mason["test_tool_xyz"], "test-pkg-xyz", "register_tool")
  mappings.register_lsp("test_lsp_xyz", "test-lsp-pkg")
  assert_eq(mappings.lsp_to_mason["test_lsp_xyz"], "test-lsp-pkg", "register_lsp")
end

local function test_env_lazy_facts()
  package.loaded["core.kernel.env"] = nil
  local env = require("core.kernel.env")
  env.register_fact("test_fact_abc", function()
    return 42
  end)
  assert_eq(env.test_fact_abc, 42, "register_fact lazy value")
  assert_eq(env.test_fact_abc, 42, "register_fact memoised")
end

local function test_module_provider_discover()
  local provider = require("runtime.providers.interface")
  local mods = provider.discover()
  assert_true(#mods >= 10, "discover finds lang modules")
  local found_python = false
  for _, m in ipairs(mods) do
    if m == "modules.lang.python" then
      found_python = true
    end
  end
  assert_true(found_python, "python module discovered")
end

local function test_provider_registry_minimal()
  local registry = require("runtime.providers.registry")
  local full = registry.resolve("full")
  local minimal = registry.resolve("minimal")
  assert_true(#full > #minimal, "minimal profile filters modules")
  local has_lua = false
  for _, m in ipairs(minimal) do
    if m == "modules.lang.lua_lang" then
      has_lua = true
    end
  end
  assert_true(has_lua, "minimal keeps lua_lang")
end

local function test_adapter_registry()
  local reg = require("runtime.adapters.registry")
  local list = reg.list()
  assert_true(#list >= 5, "adapters registered")
  assert_eq(list[1], "runtime.adapters.lsp", "lsp adapter first by priority")
end

local function test_pipeline_phase_order()
  local pipeline = require("runtime.pipeline")
  assert_eq(#pipeline.PHASE_ORDER, 8, "eight phases")
  assert_eq(pipeline.PHASE_ORDER[1], "collect", "collect first")
end

local function test_runtime_build()
  local runtime = require("runtime")
  local specs = runtime.build()
  assert_true(type(specs) == "table" and #specs > 0, "build produces specs")
  local modules = runtime.lang_modules()
  assert_true(#modules > 0, "lang_modules resolved")
end

local function test_config_provider()
  local cfg = require("runtime.providers.config")
  local opts = cfg.build_setup_opts({ { "test/plugin", _source = "test" } })
  assert_true(type(opts.spec) == "table" and #opts.spec >= 3, "config spec composed")
  assert_true(type(opts.performance.rtp.disabled_plugins) == "table", "disabled_plugins present")
end

local function test_debug_run_signature()
  local runtime = require("runtime")
  local pipeline = require("runtime.pipeline")
  local ir, specs = pipeline.debug_run(runtime.lang_modules(), "optimize")
  assert_true(ir ~= nil and ir.stage ~= nil, "debug_run returns ir")
  -- specs may be empty table when stop_before codegen; optimize returns before codegen
  assert_true(specs == nil or type(specs) == "table", "debug_run second return is table or nil")
end

local function test_ir_diag_idempotent()
  local ir = require("core.compiler.ir")
  local d1 = ir.diag("collect", "mod.a", "same message", "error")
  local d2 = ir.diag("collect", "mod.a", "same message", "error")
  assert_eq(d1.code, d2.code, "ir diag codes deterministic")
  assert_true(d1.code:match("^E%x+") ~= nil, "ir diag code format")
end

local function test_compiler_ports()
  local ports = require("core.compiler.ports")
  local dir = ports.cache_dir()
  assert_true(type(dir) == "string" and #dir > 0, "ports cache_dir configured")
  local store = require("core.compiler.cache.store")
  assert_true(store.tier_files().ast:find("ast_cache"), "tier paths from ports")
end

local function test_terminal_set_default()
  local api = require("runtime.api")
  api.terminal_set_default("test_terminal_xyz")
  api.terminal_register("test_terminal_xyz", { float = function() end })
  -- get_terminal is internal; verify register + set_default exist
  assert_true(type(api.terminal.set_default) == "function", "terminal set_default API")
end

local function test_build_request()
  local br = require("runtime.build_request")
  vim.g.ltos_profile = "nix"
  vim.g.ltos_tool_overrides = { test_br_tool = { use_mason = false, pkg = nil } }
  local req = br.from_vim("nix", { "modules.lang.python" })
  assert_eq(req.profile, "nix", "build_request profile")
  assert_true(req.prefer_system, "nix prefer_system")
  assert_eq(req.overrides.test_br_tool.use_mason, false, "build_request overrides")
  vim.g.ltos_profile = nil
  vim.g.ltos_tool_overrides = nil
end

local function test_nix_profile_rules()
  local rules = require("toolchain.rules")
  local ctx = { prefer_system = true }
  if vim.fn.executable("git") == 1 then
    local r = rules.resolve("git", {}, ctx)
    assert_eq(r.use_mason, false, "nix profile prefers system git")
  end
end

local function test_two_tier_cache()
  local store = require("core.compiler.cache.store")
  local files = store.tier_files()
  assert_true(files.ast ~= nil, "ast tier exists")
  assert_true(files.spec ~= nil, "spec tier exists")
  assert_true(files.ir == nil, "ir tier removed from tier_files")
end

local function test_nix_profile_modules()
  local registry = require("runtime.providers.registry")
  local full = registry.resolve("full")
  local nix = registry.resolve("nix")
  assert_eq(#nix, #full, "nix profile same module count as full")
end

local function test_collect_ext_populates()
  local collect_ext = require("runtime.passes.collect_ext")
  local ir_mod = require("core.compiler.ir")
  local mods = collect_ext.registered()
  assert_true(#mods >= 5, "collect_ext has default cap modules")
  local ir = collect_ext.pass.run(ir_mod.new({ "modules.lang.lua_lang" }, "full"))
  assert_true(ir.ext_caps ~= nil, "ext_caps initialized")
  assert_true(next(ir.ext_caps.image) ~= nil, "image caps collected")
end

local function test_cap_registry()
  local reg = require("runtime.adapters.cap_registry")
  local list = reg.list()
  assert_true(#list >= 4, "cap adapters registered")
  assert_true(reg.get("image") ~= nil, "image adapter resolved")
end

local function test_lifecycle_sm()
  local lc = require("runtime.lifecycle")
  lc._reset()
  assert_eq(lc.state(), "BOOT", "lifecycle starts at BOOT")
  assert_true(lc.transition("SCHEMA_LOAD"), "BOOT→SCHEMA_LOAD")
  assert_true(lc.transition("COMPILE"), "SCHEMA_LOAD→COMPILE")
  assert_true(lc.is_ready() == false, "not ready before EMIT/READY")
  assert_true(lc.transition("EMIT"), "COMPILE→EMIT")
  assert_true(lc.transition("READY"), "EMIT→READY")
  assert_true(lc.is_ready(), "ready after READY")
end

local function test_mappings_resolve()
  local mappings = require("toolchain.mappings")
  local git = mappings.resolve("git")
  assert_eq(git.use_mason, false, "git is system tool")
  local ruff = mappings.resolve("ruff")
  assert_eq(ruff.use_mason, true, "ruff uses mason")
  assert_true(ruff.pkg ~= nil, "ruff has pkg")
end

local function test_cache_key_includes_caps()
  local key_mod = require("core.compiler.cache.key")
  local lang = { "modules.lang.python" }
  local caps = require("runtime.passes.collect_ext").registered()
  local k1 = key_mod.compute(lang, "full", caps)
  local k2 = key_mod.compute(lang, "full", {})
  assert_true(k1 ~= k2, "cap modules affect cache key")
end

local tests = {
  test_cache_version_unified,
  test_schema_diag_idempotent,
  test_ir_diag_idempotent,
  test_rules_no_vimg,
  test_mappings_register,
  test_env_lazy_facts,
  test_module_provider_discover,
  test_provider_registry_minimal,
  test_adapter_registry,
  test_pipeline_phase_order,
  test_compiler_ports,
  test_terminal_set_default,
  test_build_request,
  test_nix_profile_rules,
  test_two_tier_cache,
  test_nix_profile_modules,
  test_collect_ext_populates,
  test_cap_registry,
  test_lifecycle_sm,
  test_mappings_resolve,
  test_cache_key_includes_caps,
  test_runtime_build,
  test_config_provider,
  test_debug_run_signature,
}

local passed = 0
local failed = 0
for _, fn in ipairs(tests) do
  local ok, err = pcall(fn)
  if not ok then
    failed = failed + 1
    vim.notify("[ltos_tests] FAIL " .. tostring(fn) .. ": " .. tostring(err), vim.log.levels.ERROR)
  else
    passed = passed + 1
  end
end

if failed > 0 then
  error(("[ltos_tests] %d/%d passed, %d failed"):format(passed, #tests, failed))
end

vim.notify(("[ltos_tests] %d/%d passed"):format(passed, #tests), vim.log.levels.INFO)