-- scripts/ltos_tests.lua
-- Entry point: loads modular spec suites (spec/*.lua).

require("runtime.ports_bootstrap").setup()

local runner = require("spec._runner")

local SPEC_MODULES = {
  "spec.core.compiler_spec",
  "spec.runtime.pipeline_spec",
  "spec.modules.capability_spec",
  "spec.toolchain.strategy_spec",
}

local passed, failed = runner.run_modules(SPEC_MODULES)

if failed > 0 then
  error(("[ltos_tests] %d passed, %d failed"):format(passed, failed))
end

vim.notify(("[ltos_tests] %d/%d passed"):format(passed, passed + failed), vim.log.levels.INFO)
