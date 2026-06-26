-- path: scripts/ltos_tests.lua
-- LTOS Unified Test Entry Point v4
--
-- FIX for E5113 "loop or previous error loading module 'spec._runner'":
--
-- CAUSE: The original script used:
--     prepend_path(ROOT .. "/spec/?.lua")
-- This causes require("spec._runner") to search for:
--     ROOT/spec/spec/_runner.lua   ← double "spec/" — file does not exist
-- Lua's require() then caches the failure in package.loaded["spec._runner"] = false.
-- Every subsequent require("spec._runner") (from spec files) immediately returns the
-- cached failure: "loop or previous error loading module 'spec._runner'".
--
-- FIX: Use loadfile() to load spec/_runner.lua directly, bypassing require()
-- entirely, then inject the result into package.loaded["spec._runner"].
-- This means:
--   (a) No double-spec path bug — we use an absolute path via ROOT.
--   (b) No circular-load risk — package.loaded is set BEFORE any spec file runs.
--   (c) nvim's rtp-based searcher (which looks in lua/spec/) is irrelevant.
--
-- Path layout:
--   ROOT/spec/_runner.lua          → loaded via loadfile, registered as "spec._runner"
--   ROOT/spec/core/ir_spec.lua     → require("spec.core.ir_spec") via ROOT/?.lua
--   ROOT/lua/core/compiler/ir.lua  → require("core.compiler.ir")  via ROOT/lua/?.lua
--
-- Usage (via run_ltos_tests.sh / just test):
--   nvim --headless -u NONE --cmd "set rtp^=$ROOT" \
--       "+luafile $ROOT/scripts/ltos_tests.lua" +qa
--
-- Usage with args (suite/tag filtering):
--   nvim --headless -u NONE --cmd "set rtp^=$ROOT" \
--       "+lua _G.arg={'--suite','core'}" \
--       "+luafile $ROOT/scripts/ltos_tests.lua" +qa

-- ── 1. Resolve project root from this script's path ──────────────────────────

local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  return src:match("^(.*)/[^/]+$") or "."
end

local SCRIPTS_DIR = script_dir()                       -- …/nvim-config/scripts
local ROOT        = SCRIPTS_DIR:match("^(.*)/[^/]+$") -- …/nvim-config
              or SCRIPTS_DIR

-- ── 2. Fix package.path ───────────────────────────────────────────────────────
--
-- Correct entries (lowest to highest priority, prepended in reverse):
--
--   ROOT/lua/?.lua    → require("core.compiler.ir") etc.
--   ROOT/?.lua        → require("spec.core.ir_spec") → ROOT/spec/core/ir_spec.lua
--
-- DO NOT add ROOT/spec/?.lua — that would cause double-spec resolution:
--   require("spec._runner") → ROOT/spec/spec/_runner.lua  ← WRONG

local function prepend_path(p)
  if not package.path:find(p, 1, true) then
    package.path = p .. ";" .. package.path
  end
end

prepend_path(ROOT .. "/lua/?/init.lua")
prepend_path(ROOT .. "/lua/?.lua")
prepend_path(ROOT .. "/?/init.lua")
prepend_path(ROOT .. "/?.lua")

-- ── 3. Pre-load spec._runner via loadfile() ───────────────────────────────────
--
-- We load spec/_runner.lua with an absolute path, bypassing require() entirely.
-- Then we register the result in package.loaded["spec._runner"] so that all
-- spec files' `local R = require("spec._runner")` calls return this table
-- immediately without any filesystem search.
--
-- This also means package.loaded["spec._runner"] is NEVER false (failure sentinel),
-- which eliminates the "loop or previous error" condition entirely.

-- Clear any cached failure from a previous (failed) require attempt.
package.loaded["spec._runner"] = nil

local runner_path  = ROOT .. "/spec/_runner.lua"
local runner_chunk, load_err = loadfile(runner_path)

if not runner_chunk then
  io.stderr:write(
    "[ltos_tests] FATAL: cannot loadfile spec/_runner.lua\n" ..
    "  path: " .. runner_path .. "\n" ..
    "  err:  " .. tostring(load_err) .. "\n"
  )
  os.exit(1)
end

local ok, runner_or_err = pcall(runner_chunk)
if not ok then
  io.stderr:write(
    "[ltos_tests] FATAL: spec/_runner.lua raised an error during execution:\n" ..
    "  " .. tostring(runner_or_err) .. "\n"
  )
  os.exit(1)
end

-- runner_or_err is now the module table returned by spec/_runner.lua
package.loaded["spec._runner"] = runner_or_err

-- ── 4. Bootstrap runtime ─────────────────────────────────────────────────────

require("runtime.ports_bootstrap").setup()
require("runtime.types_bootstrap").setup()

-- FIX-AUDIT-P1-2a (2026-06-23): collect_ext.setup() registers default cap
-- modules. Without this, cap_spec.lua "registered() >= 5 defaults" test fails.
-- pipeline.lua does NOT need setup() — it keeps require-time init (orchestrator).
require("runtime.passes.collect_ext").setup()

-- FIX-DEPLOY-TEST (2026-06-23): also setup cap_registry and adapter_registry
-- so cap_resolve tests can find registered adapters.
require("runtime.adapters.registry").setup()
require("runtime.adapters.cap_registry").setup()

-- ── 5. Spec catalogue ────────────────────────────────────────────────────────
-- Tags: unit | integration | slow | core | modules | runtime | toolchain

local SPEC_CATALOGUE = {
  -- core (L0–L2)
  { suite = "core", module = "spec.core.util_spec",        tags = { "unit", "core" } },
  { suite = "core", module = "spec.core.diagnostic_spec",  tags = { "unit", "core" } },
  { suite = "core", module = "spec.core.ir_spec",          tags = { "unit", "core" } },
  { suite = "core", module = "spec.core.pass_spec",        tags = { "unit", "core" } },
  { suite = "core", module = "spec.core.capability_spec",  tags = { "unit", "core" } },
  { suite = "core", module = "spec.core.schema_spec",      tags = { "unit", "core" } },
  { suite = "core", module = "spec.core.ext_schema_spec",  tags = { "unit", "core" } },
  { suite = "core", module = "spec.core.cache_spec",       tags = { "unit", "core" } },
  { suite = "core", module = "spec.core.invariants_spec",  tags = { "unit", "core" } },
  { suite = "core", module = "spec.core.types_spec",       tags = { "unit", "core" } },
  -- modules (L5–L6)
  { suite = "modules", module = "spec.modules.capability_spec", tags = { "unit", "modules" } },
  { suite = "modules", module = "spec.modules.ai_keybind_spec", tags = { "unit", "modules" } },
  { suite = "modules", module = "spec.modules.lang_spec",       tags = { "unit", "modules" } },
  -- runtime (L4)
  { suite = "runtime", module = "spec.runtime.phase_registry_spec", tags = { "unit", "runtime" } },
  { suite = "runtime", module = "spec.runtime.passes_spec",         tags = { "unit", "runtime" } },
  { suite = "runtime", module = "spec.runtime.pipeline_spec",       tags = { "unit", "runtime" } },
  { suite = "runtime", module = "spec.runtime.lifecycle_spec",      tags = { "unit", "runtime" } },
  { suite = "runtime", module = "spec.runtime.adapters_spec",       tags = { "unit", "runtime" } },
  { suite = "runtime", module = "spec.runtime.cap_spec",            tags = { "unit", "runtime" } },
  { suite = "runtime", module = "spec.runtime.infra_spec",          tags = { "unit", "runtime" } },
  { suite = "runtime", module = "spec.runtime.commands_spec",       tags = { "unit", "runtime" } },
  { suite = "runtime", module = "spec.runtime.p2_regression_spec",  tags = { "unit", "runtime" } },
  -- toolchain (L3)
  { suite = "toolchain", module = "spec.toolchain.strategy_spec",      tags = { "unit", "toolchain" } },
  { suite = "toolchain", module = "spec.toolchain.mappings_data_spec", tags = { "unit", "toolchain" } },
  -- integration
  { suite = "integration", module = "spec.integration.build_request_spec",
    tags = { "integration" } },
  { suite = "integration", module = "spec.integration.layer_boundary_spec",
    tags = { "integration" } },
  { suite = "integration", module = "spec.integration.full_pipeline_spec",
    tags = { "integration", "slow" } },
  { suite = "integration", module = "spec.integration.pipeline_invariants_spec",
    tags = { "integration", "slow" } },
}

-- ── 6. CLI parsing ───────────────────────────────────────────────────────────

local function parse_args(raw)
  local o = {
    tags      = {},
    suite     = nil,
    fail_fast = false,
    verbose   = true,
    list_only = false,
  }
  local i = 1
  while i <= #raw do
    local a = raw[i]
    if     a == "--tags"  and raw[i + 1] then
      i = i + 1
      for t in raw[i]:gmatch("[^,]+") do o.tags[#o.tags + 1] = t end
    elseif a == "--suite" and raw[i + 1] then
      i = i + 1; o.suite = raw[i]
    elseif a == "--fail-fast" then o.fail_fast = true
    elseif a == "--quiet"     then o.verbose   = false
    elseif a == "--list"      then o.list_only = true
    end
    i = i + 1
  end
  return o
end

local function filter_catalogue(cat, opts)
  local tf = nil
  if #opts.tags > 0 then
    tf = {}
    for _, t in ipairs(opts.tags) do tf[t] = true end
  end
  local r = {}
  for _, e in ipairs(cat) do
    if opts.suite and e.suite ~= opts.suite then goto c end
    if tf then
      local m = false
      for _, t in ipairs(e.tags or {}) do
        if tf[t] then m = true; break end
      end
      if not m then goto c end
    end
    r[#r + 1] = e
    ::c::
  end
  return r
end

-- ── 7. Summary printer ───────────────────────────────────────────────────────

local function print_summary(rows)
  local W = 72
  print(""); print(string.rep("─", W))
  print(string.format("  %-44s  %5s  %5s  %5s", "Module", "PASS", "FAIL", "SKIP"))
  print(string.rep("─", W))
  local tp, tf, ts = 0, 0, 0
  for _, r in ipairs(rows) do
    local icon = r.f > 0 and "✗" or "✓"
    local disp = r.name:gsub("^spec%.", "")
    print(string.format("  %s %-42s  %5d  %5d  %5d", icon, disp, r.p, r.f, r.s))
    tp = tp + r.p; tf = tf + r.f; ts = ts + r.s
  end
  print(string.rep("─", W))
  print(string.format("  %-44s  %5d  %5d  %5d", "TOTAL", tp, tf, ts))
  print(string.rep("─", W))
end

-- ── 8. Main ──────────────────────────────────────────────────────────────────

local opts     = parse_args(_G.arg or {})
local filtered = filter_catalogue(SPEC_CATALOGUE, opts)

if opts.list_only then
  print("LTOS Spec Catalogue — " .. #SPEC_CATALOGUE .. " suites\n")
  local last = nil
  for _, e in ipairs(SPEC_CATALOGUE) do
    if e.suite ~= last then print("  [" .. e.suite .. "]"); last = e.suite end
    print(string.format("    %-52s  %s",
      e.module, table.concat(e.tags or {}, ",")))
  end
  print(""); os.exit(0)
end

if #filtered == 0 then
  vim.notify("[ltos_tests] no suites matched filters", vim.log.levels.WARN)
  os.exit(1)
end

-- runner is already in package.loaded from step 3 — no require() needed.
local runner = package.loaded["spec._runner"]

local rows       = {}
local tp, tf, ts = 0, 0, 0

for _, entry in ipairs(filtered) do
  local suite = runner.run_suite(entry.module, nil)
  rows[#rows + 1] = {
    name = entry.module,
    p    = suite.passed,
    f    = suite.failed,
    s    = suite.skipped,
  }
  tp = tp + suite.passed
  tf = tf + suite.failed
  ts = ts + suite.skipped
  if opts.fail_fast and suite.failed > 0 then
    vim.notify("[ltos_tests] FAIL_FAST", vim.log.levels.ERROR); break
  end
end

print_summary(rows)
print(string.format(
  "\n[ltos_tests] suites=%d  passed=%d  failed=%d  skipped=%d",
  #filtered, tp, tf, ts
))

if tf > 0 then
  vim.notify(("[ltos_tests] %d test(s) FAILED"):format(tf), vim.log.levels.ERROR)
  os.exit(1)
end
vim.notify(("[ltos_tests] all %d passed"):format(tp), vim.log.levels.INFO)
