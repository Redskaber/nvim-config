# LTOS — Language Toolchain Orchestration System

A compiler-inspired Neovim configuration framework. Lang modules are the "source language" (DSL); a five-stage pipeline compiles them into lazy.nvim plugin specs (the "target code").

## Architecture

```
modules/lang/*.lua   →   Pipeline (5 stages)   →   lazy.nvim specs
     (DSL)                                           (codegen output)
```

### Layer Overview

```
┌─────────────────────────────────────────────┐
│  Entry: init.lua → core/bootstrap.lua       │
│         → config/lazy.lua                  │
└──────────────────┬──────────────────────────┘
                   │ runtime.build()
┌──────────────────▼──────────────────────────┐
│  Orchestration: runtime/init.lua            │
│  Pipeline:      runtime/pipeline.lua        │
│  (State Machine + 5-stage execution)        │
└──┬──────┬──────┬──────┬──────┬──────────────┘
   │      │      │      │      │
collect normalize resolve optimize codegen
┌──▼──────▼──────▼──────▼──────▼──────────────┐
│  IR Layer: core/ir.lua + core/schema.lua    │
└──┬───────────────────────────────────────────┘
   │
┌──▼───────────────────────────────────────────┐
│  Declaration: core/capability.lua (Registry) │
│  modules/lang/*.lua  (pure DSL, no effects)  │
└──┬───────────────────────────────────────────┘
   │
┌──▼───────────────────────────────────────────┐
│  Toolchain: toolchain/rules.lua              │
│             toolchain/mappings.lua           │
│             toolchain/strategies/            │
└──┬───────────────────────────────────────────┘
   │
┌──▼───────────────────────────────────────────┐
│  Adapters: runtime/adapters/{lsp,mason,      │
│            treesitter,conform,lint}.lua      │
└──┬───────────────────────────────────────────┘
   │ LazySpec[]
┌──▼───────────────────────────────────────────┐
│  Plugins: plugins/*.lua  (UI/editor/AI)      │
│  Facade:  runtime/api.lua + config/keymaps   │
└──────────────────────────────────────────────┘
```

### Pipeline Stages

| Stage | Input | Output |
|-------|-------|--------|
| **collect** | `modules/lang/*.lua` module paths | `IR.caps` — validated capability registry |
| **normalize** | `IR.caps` | `FormatterNode.fn` injected (deep-copy; registry untouched) |
| **resolve** | `IR.caps` | `IR.resolved` — per-tool mason/system decision |
| **optimize** | `IR.resolved` | `IR.merged_lsp`, `IR.all_parsers` — deduped |
| **codegen** | full IR | `LazySpec[]` consumed by lazy.nvim |

The pipeline runs through a state machine (`idle → collecting → normalizing → resolving → optimizing → codegen → done`). Each `run()` and `debug_run()` call gets its own independent state machine instance — no global state is shared between calls.

### Pipeline Caching

Results are cached to disk keyed by `sha256` of all lang module contents. On subsequent startups the pipeline is skipped entirely on a cache hit. Cache is invalidated automatically when any lang module changes. Specs containing function values (e.g. dynamic formatter strategies) set `_no_cache = true` and are excluded from serialization.

## File Structure

```
~/.config/nvim/
├── init.lua                        # entry point
└── lua/
    ├── core/
    │   ├── bootstrap.lua           # earliest inits
    │   ├── capability.lua          # central registry (add/all/reset)
    │   ├── cache.lua               # sha256-keyed pipeline cache
    │   ├── env.lua                 # Nix / system environment detection
    │   ├── ir.lua                  # IR struct + stage field contracts
    │   ├── schema.lua              # AST node validation, fail-fast
    │   └── util.lua                # dedup, misc helpers
    ├── config/
    │   ├── autocmds.lua
    │   ├── globals.lua
    │   ├── icons.lua               # single source of truth for glyphs
    │   ├── keymaps.lua             # imports runtime.api only
    │   ├── lazy.lua                # bootstrap lazy.nvim + runtime.build()
    │   └── options.lua
    ├── modules/
    │   └── lang/                   # pure DSL — zero side-effects
    │       ├── c_cpp.lua
    │       ├── go.lua
    │       ├── lua_lang.lua
    │       ├── markup.lua          # owns: json/jsonc/yaml/toml/html/css/scss/md
    │       ├── nix.lua
    │       ├── python.lua
    │       ├── rust.lua
    │       ├── shell.lua
    │       ├── typescript.lua      # owns: js/ts/jsx/tsx only
    │       └── zig.lua
    ├── runtime/
    │   ├── init.lua                # orchestrator, profile, cache integration
    │   ├── pipeline.lua            # state machine + 5-stage pipeline
    │   ├── commands.lua            # :LtosDebug, :LtosInfo
    │   ├── api.lua                 # unified facade; pluggable terminal backend
    │   └── adapters/
    │       ├── lsp.lua
    │       ├── mason.lua
    │       ├── treesitter.lua
    │       ├── conform.lua
    │       └── lint.lua
    ├── toolchain/
    │   ├── mappings.lua            # tool → mason pkg; unified system_tools set
    │   ├── rules.lua               # ToolchainStrategy: mason vs system
    │   └── strategies/
    │       ├── init.lua            # FormatterStrategy registry
    │       └── formatters.lua      # ruff_or_black, prettierd_or_prettier
    ├── plugins/                    # UI / editor / AI — no toolchain logic
    │   ├── ai.lua
    │   ├── coding.lua
    │   ├── colorscheme.lua
    │   ├── editor.lua
    │   ├── formatting.lua
    │   ├── linting.lua
    │   ├── lsp.lua
    │   ├── snacks.lua
    │   ├── treesitter.lua
    │   └── ui.lua
    └── spec/                       # headless test suites
        ├── core/
        │   └── schema_spec.lua
        ├── runtime/
            ├── commands_spec.lua
        │   └── pipeline_spec.lua
        └── toolchain/
            ├── mappings_spec.lua
            └── strategies_spec.lua
```

## Lang Modules (DSL)

Each file under `modules/lang/` is a pure Lua table — no `require`, no side effects. The pipeline's `collect` stage loads and validates them.

```lua
-- modules/lang/typescript.lua  — plain strings, fully compatible with conform.nvim
return {
  treesitter = { "javascript", "typescript", "tsx" },
  lsp        = { vtsls = { settings = { ... } } },
  formatters = {
    typescript      = { "prettierd" },
    typescriptreact = { "prettierd" },
  },
  linters = { typescript = { "eslint" } },
  mason   = { "vtsls", "prettierd" },
}
```

Formatter values are plain strings by default — exactly what conform.nvim's `formatters_by_ft` expects. The pipeline passes them through unchanged.

### FormatterNode (optional)

For formatters that need runtime fallback logic, a `FormatterNode` table can be used instead of a plain string. The `normalize` stage resolves the strategy to a `fn` field on a **deep copy** — the shared registry tables are never mutated:

```lua
-- modules/lang/python.lua  — strategy-based, resolves at runtime
formatters = {
  python = { { kind = "formatter", strategy = "ruff_or_black" } },
},
```

| Strategy | Behavior |
|----------|----------|
| `ruff_or_black` | prefers `ruff_format`; falls back to `isort + black` |
| `prettierd_or_prettier` | prefers `prettierd`; falls back to `prettier` |

Plain strings and `FormatterNode` entries can be mixed freely in the same list.

Register custom strategies in `toolchain/strategies/`:

```lua
local strategies = require("toolchain.strategies")
strategies.register("my_strategy", function(bufnr)
  return { "my_formatter" }
end)
```

## Toolchain Resolution

`toolchain/rules.lua` implements the `ToolchainStrategy` interface. Resolution priority:

1. User overrides (`vim.g.ltos_tool_overrides` or `toolchain/mappings.lua` `overrides`)
2. `system_tools` set — unified list of binaries that must never be mason-managed
3. Nix environment detection (`core/env.lua`)
4. `tool_to_mason` mapping table (only entries whose name differs from the mason package)
5. Identity fallback (tool name = mason package name)

Tools that ship with their language toolchain (rustfmt, gofmt, zigfmt) and system tools (fish, nixpkgs_fmt, git, …) are all declared in `mappings.system_tools` and never installed via mason.

## Terminal Backend (pluggable)

The `runtime.api` terminal facade dispatches to the backend named in `vim.g.ltos_terminal_backend` (default: `"toggleterm"`). To swap the terminal plugin without editing `api.lua`:

```lua
-- e.g. in plugins/ui.lua or globals.lua
require("runtime.api").terminal.register("snacks_term", {
  float      = function() Snacks.terminal() end,
  horizontal = function() Snacks.terminal(nil, { win = { position = "bottom" } }) end,
})
vim.g.ltos_terminal_backend = "snacks_term"
```

## Profiles

Set `vim.g.ltos_profile` before startup to control which modules are loaded:

| Profile | Modules |
|---------|---------|
| `"full"` (default) | all lang modules |
| `"minimal"` | core modules only (`lua_lang`) |
| `"nix"` | all modules, system tools preferred |

```lua
-- globals.lua
vim.g.ltos_profile = "minimal"
```

## User Commands

| Command | Description |
|---------|-------------|
| `:LtosInfo` | Show active profile, pipeline state, registered modules, tool count, and per-stage timings |
| `:LtosDebug [stage]` | Dump foldable IR snapshot at `collect`/`normalize`/`resolve`/`optimize` |

## Adding a New Language

Create `lua/modules/lang/mylang.lua`:

```lua
return {
  treesitter = { "mylang" },
  lsp        = { mylang_ls = {} },
  formatters = { mylang = { "myfmt" } },
  linters    = { mylang = { "mylint" } },
  mason      = { "mylang-language-server" },  -- formatter/linter tools only; LSP resolved via mappings
}
```

Then add the module path to `LANG_MODULES` in `lua/runtime/init.lua`. The pipeline handles the rest.

> **Note:** Do not list LSP mason package names in `mason = {}`. They are resolved automatically from `toolchain/mappings.lsp_to_mason`. Only formatter and linter tool names belong in `mason`.

## Supported Languages

| Language | LSP | Formatter | Linter |
|----------|-----|-----------|--------|
| C / C++ | clangd | clang-format | clangtidy |
| Go | gopls | gofmt | — |
| Lua | lua_ls | stylua | — |
| Markup (JSON/YAML/TOML/HTML/MD) | jsonls, yamlls, taplo | taplo / prettierd | — |
| Nix | nil_ls | nixpkgs_fmt | — |
| Python | pyright | ruff-or-black | ruff |
| Rust | rust_analyzer | rustfmt | clippy |
| Shell | — | shfmt | shellcheck |
| TypeScript / JavaScript | vtsls | prettierd | eslint |
| Zig | zls | zigfmt | — |

## Tests

```bash
# Schema edge-case unit tests
nvim --headless -l spec/core/schema_spec.lua

# Toolchain mappings unit tests
nvim --headless -l spec/toolchain/mappings_spec.lua

# Formatter strategy unit tests
nvim --headless -l spec/toolchain/strategies_spec.lua

# Pipeline integration tests
nvim --headless -l spec/runtime/pipeline_spec.lua

# :LtosInfo command integration tests
nvim --headless -l spec/runtime/commands_spec.lua
```
