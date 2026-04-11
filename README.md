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
| **normalize** | `IR.caps` | strategy refs injected into `FormatterNode` |
| **resolve** | `IR.caps` | `IR.resolved` — per-tool mason/system decision |
| **optimize** | `IR.resolved` | `IR.merged_lsp`, `IR.all_parsers` — deduped |
| **codegen** | full IR | `LazySpec[]` consumed by lazy.nvim |

The pipeline runs through a state machine (`idle → collecting → normalizing → resolving → optimizing → codegen → done`). Illegal transitions enter the `error` state; the pipeline always returns the most complete spec list possible rather than crashing.

### Pipeline Caching

Results are cached to disk keyed by `sha256` of all lang module contents. On subsequent startups the pipeline is skipped entirely on a cache hit. Cache is invalidated automatically when any lang module changes.

## File Structure

```
~/.config/nvim/
├── init.lua                        # entry point
└── lua/
    ├── core/
    │   ├── bootstrap.lua           # earliest inits
    │   ├── capability.lua          # central registry (add/all)
    │   ├── cache.lua               # sha256-keyed pipeline cache
    │   ├── env.lua                 # Nix / system environment detection
    │   ├── icons.lua               # internal icon set
    │   ├── ir.lua                  # IR struct + stage field contracts
    │   ├── schema.lua              # AST node validation, fail-fast
    │   └── util.lua                # dedup, misc helpers
    ├── config/
    │   ├── autocmds.lua
    │   ├── globals.lua
    │   ├── keymaps.lua             # imports runtime.api only
    │   ├── lazy.lua                # bootstrap lazy.nvim + runtime.build()
    │   └── options.lua
    ├── modules/
    │   └── lang/                   # pure DSL — zero side-effects
    │       ├── c_cpp.lua
    │       ├── go.lua
    │       ├── lua_lang.lua
    │       ├── markup.lua
    │       ├── nix.lua
    │       ├── python.lua
    │       ├── rust.lua
    │       ├── shell.lua
    │       ├── typescript.lua
    │       └── zig.lua
    ├── runtime/
    │   ├── init.lua                # orchestrator, profile, cache integration
    │   ├── pipeline.lua            # state machine + 5-stage pipeline
    │   ├── commands.lua            # :LtosDebug, :LtosInfo
    │   ├── api.lua                 # unified facade for keymaps
    │   └── adapters/
    │       ├── lsp.lua
    │       ├── mason.lua
    │       ├── treesitter.lua
    │       ├── conform.lua
    │       └── lint.lua
    ├── toolchain/
    │   ├── mappings.lua            # tool → mason package name, overrides
    │   ├── rules.lua               # ToolchainStrategy: mason vs system
    │   └── strategies/
    │       ├── init.lua            # FormatterStrategy registry
    │       └── formatters.lua      # ruff_or_black, prettierd_or_prettier
    └── plugins/                    # UI / editor / AI — no toolchain logic
        ├── ai.lua
        ├── coding.lua
        ├── colorscheme.lua
        ├── editor.lua
        ├── formatting.lua
        ├── linting.lua
        ├── lsp.lua
        ├── snacks.lua
        ├── treesitter.lua
        └── ui.lua
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

For formatters that need runtime fallback logic, a `FormatterNode` table can be used instead of a plain string. The `normalize` stage resolves the strategy to a concrete tool list at runtime:

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

Plain strings and `FormatterNode` entries can be mixed freely in the same list. Use `FormatterNode` only when you need runtime tool selection; otherwise plain strings are simpler and equally valid.

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
2. `always_system` list (rustfmt, gofmt, zigfmt, fish, nixpkgs_fmt, …)
3. Nix environment detection (`core/env.lua`)
4. `tool_to_mason` mapping table
5. Identity fallback (tool name = mason package name)

Tools that ship with their language toolchain (rustfmt, gofmt, zigfmt) are always marked `always_system` and never installed via mason.

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
| `:LtosInfo` | Show active profile, pipeline state, registered modules and tool count |
| `:LtosDebug [stage]` | Dump IR snapshot at `collect`/`normalize`/`resolve`/`optimize` in a scratch buffer |

## Adding a New Language

Create `lua/modules/lang/mylang.lua`:

```lua
return {
  treesitter = { "mylang" },
  lsp        = { mylang_ls = {} },
  formatters = { mylang = { "myfmt" } },
  linters    = { mylang = { "mylint" } },
  mason      = { "mylang-language-server" },
}
```

Then add the module path to `LANG_MODULES` in `lua/runtime/init.lua`. The pipeline handles the rest.

## Supported Languages

| Language | LSP | Formatter | Linter |
|----------|-----|-----------|--------|
| C / C++ | clangd | clang-format | clangtidy |
| Go | gopls | gofmt | — |
| Lua | lua_ls | stylua | — |
| Markup (JSON/YAML/TOML/HTML/MD) | jsonls, yamlls, taplo | taplo / prettierd-or-prettier | — |
| Nix | nil_ls | nixpkgs_fmt | — |
| Python | pyright | ruff-or-black | ruff |
| Rust | rust_analyzer | rustfmt | clippy |
| Shell | — | shfmt | shellcheck |
| TypeScript / JavaScript | vtsls | prettierd-or-prettier | eslint |
| Zig | zls | zigfmt | — |

## Tests

```bash
# Formatter strategy unit tests
nvim --headless -l spec/toolchain/strategies_spec.lua

# :LtosInfo command integration tests
nvim --headless -l spec/runtime/commands_spec.lua
```


