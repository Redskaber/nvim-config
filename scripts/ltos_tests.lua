-- scripts/ltos_tests.lua
-- LTOS Unified Test Entry Point
-- Drives ALL spec suites under spec/ and lua/spec/ (backward-compat shim).
-- Usage:
--   nvim --headless -l scripts/ltos_tests.lua           (all suites)
--   nvim --headless -l scripts/ltos_tests.lua -- --tags unit
--   nvim --headless -l scripts/ltos_tests.lua -- --suite core

require("runtime.ports_bootstrap").setup()

-- ── Parse CLI args ────────────────────────────────────────────────────────────

local _args = _G.arg or {}
local _tags = {}
local _suite_filter = nil
local _fail_fast = false
local _verbose = true

for i = 1, #_args do
  local a = _args[i]
  if a == "--tags" and _args[i + 1] then
    for t in _args[i + 1]:gmatch("[^,]+") do
      _tags[#_tags + 1] = t
    end
  elseif a == "--suite" and _args[i + 1] then
    _suite_filter = _args[i + 1]
  elseif a == "--fail-fast" then
    _fail_fast = true
  elseif a == "--quiet" then
    _verbose = false
  end
end

-- ── Spec catalogue ────────────────────────────────────────────────────────────
-- Each entry: { suite = "name", module = "require.path" }

local SPEC_CATALOGUE = {
  -- core layer
  { suite = "core", module = "spec.core.ir_spec" },
  { suite = "core", module = "spec.core.diagnostic_spec" },
  { suite = "core", module = "spec.core.invariants_spec" },
  { suite = "core", module = "spec.core.util_spec" },
  { suite = "core", module = "spec.core.cache_spec" },
  { suite = "core", module = "spec.core.schema_spec" },
  { suite = "core", module = "spec.core.capability_spec" },
  { suite = "core", module = "spec.core.pass_spec" },
  { suite = "core", module = "spec.core.ext_schema_spec" },

  -- modules layer
  { suite = "modules", module = "spec.modules.graph_spec" },
  { suite = "modules", module = "spec.modules.capability_spec" },
  { suite = "modules", module = "spec.modules.lifecycle_spec" },
  { suite = "modules", module = "spec.modules.ai_keybind_spec" },

  -- runtime layer (passes + adapters)
  { suite = "runtime", module = "spec.runtime.phase_registry_spec" },
  { suite = "runtime", module = "spec.runtime.normalize_spec" },
  { suite = "runtime", module = "spec.runtime.canonicalize_spec" },
  { suite = "runtime", module = "spec.runtime.resolve_spec" },
  { suite = "runtime", module = "spec.runtime.optimize_spec" },
  { suite = "runtime", module = "spec.runtime.collect_ext_spec" },
  { suite = "runtime", module = "spec.runtime.cap_resolve_spec" },
  { suite = "runtime", module = "spec.runtime.codegen_spec" },
  { suite = "runtime", module = "spec.runtime.cap_adapters_spec" },
  { suite = "runtime", module = "spec.runtime.pipeline_spec" },
  { suite = "runtime", module = "spec.runtime.lifecycle_spec" },
  { suite = "runtime", module = "spec.runtime.commands_spec" },

  -- toolchain layer
  { suite = "toolchain", module = "spec.toolchain.rules_spec" },
  { suite = "toolchain", module = "spec.toolchain.mappings_spec" },
  { suite = "toolchain", module = "spec.toolchain.strategies_spec" },
  { suite = "toolchain", module = "spec.toolchain.conflict_spec" },

  -- integration (end-to-end golden tests)
  { suite = "integration", module = "spec.integration.build_request_spec" },
  { suite = "integration", module = "spec.integration.full_pipeline_spec" },
  { suite = "integration", module = "spec.integration.layer_boundary_spec" },
}

-- ── Filter by suite ───────────────────────────────────────────────────────────

local modules_to_run = {}
for _, entry in ipairs(SPEC_CATALOGUE) do
  if not _suite_filter or entry.suite == _suite_filter then
    modules_to_run[#modules_to_run + 1] = entry.module
  end
end

if #modules_to_run == 0 then
  vim.notify("[ltos_tests] no suites matched filter: " .. tostring(_suite_filter), vim.log.levels.WARN)
  os.exit(1)
end

-- ── Run ───────────────────────────────────────────────────────────────────────

local runner = require("spec._runner")

local passed, failed, skipped = runner.run_modules_compat(modules_to_run, {
  tags = #_tags > 0 and _tags or nil,
  verbose = _verbose,
  fail_fast = _fail_fast,
})

-- Summary banner
print(
  string.format("\n[ltos_tests] suites=%d  passed=%d  failed=%d  skipped=%d", #modules_to_run, passed, failed, skipped)
)

if failed > 0 then
  vim.notify(("[ltos_tests] %d test(s) FAILED"):format(failed), vim.log.levels.ERROR)
  os.exit(1)
end

vim.notify(("[ltos_tests] all %d passed"):format(passed), vim.log.levels.INFO)
