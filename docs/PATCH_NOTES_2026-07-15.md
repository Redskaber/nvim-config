# LTOS nvim-config Complete Patch — 2026-07-15

> **Drop-in deployment package** for the `nvim-config` project.
> Supersedes `PATCH_NOTES_2026-06-26.md` (kept for history).
>
> Apply over an existing `~/.config/nvim/` (or replace that directory
> entirely) — all `.lua` source files + spec files + scripts + docs are
> included, with the patched files overriding the originals.

## Package

- **File**: `ltos-fix-2026-07-15.tar.gz`
- **Size**: ~211 KB
- **Top-level dir**: `nvim-config/` (rename to `nvim/` after extraction)
- **File count**: 191

## What changed (cumulative, 2026-06-26 → 2026-07-15)

### Round 1 — Test-fail fixes (5 files, 21 failing tests → 0)

| File | Bug | Fix |
| ------ | ----- | ----- |
| `lua/toolchain/rules.lua` | `nix_env_rule` ignored `prefer_system=false` | Skip rule when `ctx.prefer_system == false` |
| `lua/runtime/adapters/lsp.lua` | `opts = function(...)` — tests index `spec.opts.servers` | `opts = { servers = ... }` static table |
| `lua/runtime/adapters/treesitter.lua` | Same | `opts = { ensure_installed = ... }` static table |
| `lua/runtime/adapters/conform.lua` | Same + missing `default_format_opts` | Static opts + standard fields |
| `lua/runtime/adapters/lint.lua` | Same + no per-ft dedup | Static opts + construction-time dedup |

### Round 2 — P1/P2 closure (7 files)

| File | Item | Fix |
| ------ | ------ | ----- |
| `lua/core/compiler/ports.lua` | P1-10 command injection | `ensure_cache_dir` uses libuv `vim.loop.fs_mkdir` (no shell) |
| `lua/modules/capability/registry.lua` | P1-11 internal ref leak | `get_by_type` returns shallow copy |
| `lua/runtime/pipeline.lua` | P2-2 SM decoupled + P2-3 stale PHASE_ORDER + POLISH-2 | SM from `Phase.output_state`; PHASE_ORDER listener-driven; `timings()` returns copy |
| `lua/runtime/phase_registry.lua` | P2-3 support | New `add_listener()` + `_notify()` |
| `lua/modules/capability/defaults/keybind_presets.lua` | P2-6 hardcoded strings | Reference `keybind_presets_data` constants |
| `lua/runtime/output_validate.lua` | P2-1 new file | Shared post-condition validators for 8 phases |
| `lua/runtime/passes/*.lua` (8 files) | P2-1 wire output_validate | Each phase gets `output_validate = ov.<phase>` |

### Round 3 — LazyVim conform fixes (1 file, critical)

| File | Bug | Fix |
| ------ | ----- | ----- |
| `lua/runtime/adapters/conform.lua` | `spec.config` overrode LazyVim's conform config | Remove `spec.config`; register custom formatters via `opts.formatters` |
| `lua/runtime/adapters/conform.lua` | `opts.format_on_save` conflicted with LazyVim.format | Remove `opts.format_on_save`; LazyVim owns format-on-save |
| `spec/runtime/adapters_spec.lua` | Test asserted `format_on_save` exists | Changed to `R.assert_nil(opts.format_on_save)` |

Reference: <https://www.lazyvim.org/plugins/formatting>

### Round 4 — Polish (3 files, DRY + defensive coding)

| File | Item | Fix |
| ------ | ------ | ----- |
| `lua/runtime/commands.lua` | POLISH-1 hardcoded stage lists | Derive from `phase_registry.list()`; metatable live view |
| `lua/runtime/pipeline.lua` | POLISH-2 timings() leak | `timings()` returns shallow copy |
| `lua/runtime/adapters/conform.lua` | POLISH-3 config_fn guards | `pcall(require, "conform")` + `vim.api` check |

### Round 5 — plugins/ directory reorganization (2026-06-26)

Reorganized from 9 loose dirs to **11 capability-focused dirs**:

| New dir | Files | Responsibility |
| --------- | ------- | ---------------- |
| `editing/` | 6 | Text editing primitives (pairs/surround/move/comments/textobjects/visual-multi) |
| `completion/` | 3 | Completion (cmp/luasnip/snippets) |
| `syntax/` | 4 | Syntax (treesitter/context/colorizer/markdown-render) |
| `toolchain/` | 3 | LSP/lint/format engines (LTOS adapter targets) |
| `debug/` | 4 | DAP engine + per-lang adapters |
| `git/` | 2 | Version control (gitsigns/neogit) |
| `ui/` | 11 | Interface (bufferline/lualine/noice/snacks/flash/which-key/trouble/todo-comments/grug-far/icons/neo-tree-disable) |
| `system/` | 4 | Host integration (terminal/image/img-clip/persistence) |
| `theme/` | 2 | Colorscheme |
| `ai/` | 1 | AI assistant (placeholder) |
| `lang/` | 5 | Language-specific enhancements (crates/tsc/conjure/clangd_extensions/markdown-preview) |

Eliminated "drawer files": `coding/coding.lua`, `editor/editor.lua`, `ui/ui.lua` — all split into focused single-purpose files.

### Round 6 — Auto-update opt-in (2026-07-15, 3 files)

| File | Bug | Fix |
| ------ | ----- | ----- |
| `lua/core/kernel/bootstrap.lua` | `checker = { enabled = true }` ran background git-fetch on every startup | Add `vim.g.ltos_auto_update = false` (Layer 0) |
| `lua/runtime/providers/config.lua` | Hardcoded `checker = { enabled = true, notify = true }` | Derive from `vim.g.ltos_auto_update`: default disabled, opt-in enabled |
| `lua/config/globals.lua` | No documentation for the flag | Added documentation comment |

## Verification

- `bash scripts/check_layer_boundaries.sh` → **PASSED**
- Lua syntax on all 178 `.lua` files → **all OK / 0 FAIL**
- Layer boundary rules 7a-7e → **all pass**
- No LTOS runtime references in `plugins/` → **confirmed pure**

## Deploy

```bash
# Replace entire nvim config
mv ~/.config/nvim ~/.config/nvim.bak.$(date +%Y%m%d)
tar xzf ltos-fix-2026-07-15.tar.gz -C ~/.config
mv ~/.config/nvim-config ~/.config/nvim

# Verify
cd ~/.config/nvim
just check   # → Layer boundary check: PASSED
just test    # → [ltos_tests] all tests passed
```

## Configuration knobs

| Global | Default | Purpose |
| -------- | --------- | --------- |
| `vim.g.ltos_auto_update` | `false` | Enable lazy.nvim background update checker (opt-in) |
| `vim.g.lazyvim_file_explorer` | `"snacks"` | File explorer (set in bootstrap.lua) |
| `vim.g.autoformat` | `true` | Format on save (LazyVim.format) |
| `vim.g.ltos_debug` | `false` | LTOS debug logging |

To enable auto-update, add to `lua/core/kernel/bootstrap.lua`:

```lua
vim.g.ltos_auto_update = true
```

Or run `:Lazy update` / `:Lazy check` manually.
