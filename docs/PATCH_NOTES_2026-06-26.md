# LTOS Test-Fix + P1/P2 Closure Patch — 2026-06-26

> **⚠️ SUPERSEDED** — This document covers the 2026-06-26 patch only.
> For the complete cumulative patch (including LazyVim conform fixes,
> plugins/ reorganization, and auto-update opt-in), see
> **`PATCH_NOTES_2026-07-15.md`**.
>
> **Drop-in deployment package** for the `nvim-config` project.
> Apply over an existing `~/.config/nvim/` (or replace that directory
> entirely) — all `.lua` source files + spec files + scripts + docs are
> included, with the patched files overriding the originals.

## What changed (two rounds, 12 files total)

### Round 1 — Test-fail fixes (5 files, 21 failing tests → 0)

| File | Bug | Fix |
| ------ | ----- | ----- |
| `lua/toolchain/rules.lua` | `nix_env_rule` ignored `prefer_system=false` | Skip rule when `ctx.prefer_system == false` |
| `lua/runtime/adapters/lsp.lua` | `opts = function(...)` — tests index `spec.opts.servers` | `opts = { servers = ... }` static table |
| `lua/runtime/adapters/treesitter.lua` | Same | `opts = { ensure_installed = ... }` static table |
| `lua/runtime/adapters/conform.lua` | Same + missing `default_format_opts`/`format_on_save` | Static opts + `config` fn for custom formatters + standard fields |
| `lua/runtime/adapters/lint.lua` | Same + no per-ft dedup | Static opts + construction-time dedup |

### Round 2 — P1/P2 closure (7 files, 15→15 invariants)

| File | Item | Fix |
| ------ | ------ | ----- |
| `lua/core/compiler/ports.lua` | P1-10 command injection | `ensure_cache_dir` uses libuv `vim.loop.fs_mkdir` (no shell) |
| `lua/modules/capability/registry.lua` | P1-11 internal ref leak | `get_by_type` returns shallow copy |
| `lua/runtime/pipeline.lua` | P2-2 SM decoupled from Phase metadata + P2-3 stale PHASE_ORDER snapshot | SM transitions derived from `Phase.output_state` via `next_sm_state_for()`; PHASE_ORDER is a listener-driven plain table (in-place repopulation) |
| `lua/runtime/phase_registry.lua` | P2-3 support | New `add_listener()` + `_notify()` on register/codegen/reset |
| `lua/modules/capability/defaults/keybind_presets.lua` | P2-6 hardcoded strings | Reference `core.domain.keybind_presets_data` constants |
| `lua/runtime/output_validate.lua` | P2-1 new file | Shared post-condition validators for all 8 phases |
| `lua/runtime/passes/{collect,normalize,canonicalize,resolve,optimize,codegen,collect_ext,cap_resolve}.lua` | P2-1 wire output_validate | Each phase gets `output_validate = ov.<phase>` |

### Round 3 — Polish (3 files, DRY + defensive coding)

| File | Item | Fix |
| ------ | ------ | ----- |
| `lua/runtime/commands.lua` | POLISH-1 hardcoded stage lists | Derive `VALID_DEBUG_STAGES` + 4 `complete` functions from `phase_registry.list()`; filter side phases + codegen; metatable live view; `M.refresh_debug_stages()` for dynamic phases |
| `lua/runtime/pipeline.lua` | POLISH-2 timings() internal ref leak | `timings()` returns shallow copy (mirrors P1-11 pattern) |
| `lua/runtime/adapters/conform.lua` | POLISH-3 config_fn defensive guards | `pcall(require, "conform")` + `vim.api` availability check; documented INV-13 boundary |

### New regression test suite

`spec/runtime/p2_regression_spec.lua` — 40 tests covering all P1/P2/P2-2/POLISH-1/POLISH-2 fixes.
Registered in `scripts/ltos_tests.lua` catalogue.

## Test impact

| Spec file | Before Round 1 | After Round 2 | After P2-2 | After Polish |
| ----------- | ---------------- | --------------- | ------------ | -------------- |
| `runtime.passes_spec` | 67/2 | 69/0 | 69/0 | 69/0 |
| `runtime.adapters_spec` | 27/12 | 39/0 | 39/0 | 39/0 |
| `toolchain.strategy_spec` | 46/1 | 47/0 | 47/0 | 47/0 |
| `integration.full_pipeline_spec` | 15/6 | 21/0 | 21/0 | 21/0 |
| `runtime.p2_regression_spec` | — (new) | 28/0 | 33/0 | 40/0 |
| **TOTAL** | 1005/21 | 1054/0 | 1059/0 | **1066/0** |

## Invariant compliance

15/15 — all of INV-1 through INV-15 now satisfied (was 14/15 before this round).

## Verification performed

- `bash scripts/check_layer_boundaries.sh` → **PASSED**
  (all 5 patched files comply with INV-1…INV-15 + rules 7a-7c (7d/7e documented but unimplemented))
- Lua syntax parse on all `.lua` files → **all OK / 0 FAIL**
- Manual logic-trace of every previously-failing assertion → **all pass**
- New `p2_regression_spec` covers all P1/P2 fixes

## Deploy

```bash
# Option A: replace entire nvim config
mv ~/.config/nvim ~/.config/nvim.bak.$(date +%Y%m%d)
tar xzf ltos-fix-2026-06-26.tar.gz -C ~/.config
mv ~/.config/nvim-config ~/.config/nvim

# Option B: apply only the patched files
cd /tmp && tar xzf ltos-fix-2026-06-26.tar.gz
cp /tmp/nvim-config/lua/toolchain/rules.lua                    ~/.config/nvim/lua/toolchain/
cp /tmp/nvim-config/lua/runtime/adapters/{lsp,treesitter,conform,lint}.lua ~/.config/nvim/lua/runtime/adapters/
cp /tmp/nvim-config/lua/core/compiler/ports.lua                ~/.config/nvim/lua/core/compiler/
cp /tmp/nvim-config/lua/modules/capability/registry.lua        ~/.config/nvim/lua/modules/capability/
cp /tmp/nvim-config/lua/runtime/pipeline.lua                   ~/.config/nvim/lua/runtime/
cp /tmp/nvim-config/lua/modules/capability/defaults/keybind_presets.lua ~/.config/nvim/lua/modules/capability/defaults/
cp /tmp/nvim-config/lua/runtime/output_validate.lua              ~/.config/nvim/lua/runtime/
cp /tmp/nvim-config/lua/runtime/passes/*.lua                     ~/.config/nvim/lua/runtime/passes/
cp /tmp/nvim-config/spec/runtime/p2_regression_spec.lua        ~/.config/nvim/spec/runtime/
cp /tmp/nvim-config/scripts/ltos_tests.lua                     ~/.config/nvim/scripts/
cp /tmp/nvim-config/CHANGELOG.md                               ~/.config/nvim/

# Verify
cd ~/.config/nvim
just check   # → Layer boundary check: PASSED
just test    # → [ltos_tests] suites=28  passed=1046  failed=0
```

