# nvim-config

A Neovim configuration built on **LazyVim** with a custom compiler-inspired toolchain layer — **LTOS** (Language Toolchain Orchestration System). Lang modules are a pure declarative DSL; a six-layer architecture and five-phase compiler pipeline transform them into `lazy.nvim` plugin specs at startup.

## Requirements

| Dependency                                       | Notes                             |
| ------------------------------------------------ | --------------------------------- |
| Neovim ≥ 0.11                                    | required                          |
| Git                                              | lazy.nvim bootstrap               |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | grep / search                     |
| [fd](https://github.com/sharkdp/fd)              | file finding                      |
| A [Nerd Font](https://www.nerdfonts.com/)        | icons / glyphs                    |
| Node.js                                          | vtsls, bash-language-server, etc. |
| Python 3                                         | pyright, ruff, black, isort       |
| Rust toolchain                                   | rust_analyzer, rustfmt, clippy    |
| Go toolchain                                     | gopls, gofmt, goimports           |
| Zig toolchain                                    | zls, zigfmt                       |
| Java ≥ 17                                        | jdtls, google-java-format         |
| Kotlin toolchain                                 | kotlin-language-server, ktfmt     |
| `stylua`                                         | Lua formatter (system)            |
| `shfmt`                                          | shell formatter (system)          |
| `shellcheck`                                     | shell linter (system)             |

On **NixOS / nix-darwin**: set `vim.g.ltos_profile = "nix"` to prefer system binaries on PATH; `core/kernel/env.lua` also detects `nix` for automatic system-tool preference.

## Installation

```bash
git clone https://github.com/Redskaber/nvim-config ~/.config/nvim
nvim  # lazy.nvim bootstraps itself on first launch
```

Mason installs LSP servers, formatters, and linters automatically on first startup.

---

## LTOS — Language Toolchain Orchestration System

### Six-Layer Architecture

LTOS enforces strict layer boundaries. Each layer may only depend on layers below it; upward dependencies are forbidden.

```
┌──────────────────────────────────────────────────────────────────────┐
│  Layer 5 · app / config     config/  plugins/  modules/lang/         │
│             Zero compiler knowledge. Pure DSL declarations.          │
├──────────────────────────────────────────────────────────────────────┤
│  Layer 4 · backend          runtime/adapters/*                       │
│             Read-only IR consumers. No vim API. No DSL imports.      │
├──────────────────────────────────────────────────────────────────────┤
│  Layer 3 · strategy         toolchain/strategy/*                     │
│                              toolchain/rules  toolchain/mappings     │
│             Strategy interface: applies / resolve / priority.        │
│             No vim API access. No direct adapter calls.              │
├──────────────────────────────────────────────────────────────────────┤
│  Layer 2 · domain IR        core/domain/schema core/domain/capability│
│             Immutable CapabilitySet. Pure-function validation.       │
│             No runtime state. No side effects.                       │
├──────────────────────────────────────────────────────────────────────┤
│  Layer 1 · compiler         core/compiler/ir  core/compiler/pass     │
│                              core/compiler/cache                     │
│             CompilerContext · Phase interface · three-tier cache.    │
│             No vim API. No plugin knowledge.                         │
├──────────────────────────────────────────────────────────────────────┤
│  Layer 0 · kernel           core/kernel/bootstrap  core/kernel/env   │
│                              core/kernel/util                        │
│             Earliest inits. No dependencies on any layer above.      │
└──────────────────────────────────────────────────────────────────────┘
```

**Layer contracts (enforced by convention):**

| Boundary             | Rule                                                             |
| -------------------- | ---------------------------------------------------------------- |
| kernel → compiler    | `core/kernel/*` never import `core/compiler/*`                   |
| compiler → domain IR | `core/compiler/*` never import `core/domain/*`                   |
| domain → strategy    | `core/domain/*` never import `toolchain/*`                       |
| strategy → backend   | `toolchain/*` never import `runtime/adapters/*`                  |
| backend → vim API    | `runtime/adapters/*` never call `vim.*` directly                 |
| app → compiler       | `modules/lang/*` and `plugins/*` never import `runtime/pipeline` |

---

### Compiler Pipeline

```
modules/lang/*.lua  ──►  Pipeline (5 phases)  ──►  LazySpec[]
      (DSL / AST)                                  (codegen output)
```

#### Boot sequence

```
init.lua
  └─ core/kernel/bootstrap       (Layer 0: netrw off, leader keys)
  └─ config/lazy.lua
       └─ runtime.build()    (Layer 5 → compiler entry point)
            └─ runtime/init.lua   (profile resolution, spec-tier cache)
                 └─ runtime/pipeline.lua  (state machine + 5 phases)
```

#### State machine

Each `run()` / `debug_run()` gets its own independent state machine instance. Illegal transitions abort to `ERROR`; non-fatal diagnostics accumulate in the IR and do not halt the pipeline.

```
idle → collecting → normalizing → canonicalizing → resolving → optimizing → codegen → done
                                                                                    ↘ error
```

#### Five phases

| Phase            | SM transition                | IR layer in | IR layer out | Responsibility                                                              |
| ---------------- | ---------------------------- | ----------- | ------------ | --------------------------------------------------------------------------- |
| **collect**      | idle → collecting            | —           | AST          | Load & validate lang module DSL into `IR.caps`                              |
| **normalize**    | collecting → normalizing     | AST         | HIR          | Inject `FormatterNode.fn`; deep-copy; registry untouched                    |
| **canonicalize** | normalizing → canonicalizing | HIR         | HIR+         | Build `IR.symbols`: lsp/tool → canonical mason pkg (single source of truth) |
| **resolve**      | canonicalizing → resolving   | HIR+        | MIR          | Project `IR.symbols` → `IR.resolved` (mason/system decisions)               |
| **optimize**     | resolving → optimizing       | MIR         | LIR          | Dedup parsers, deep-merge LSP configs → `IR.merged_lsp`, `IR.all_parsers`   |
| **codegen**      | optimizing → codegen         | LIR         | SPEC         | Drive backend adapters → `LazySpec[]`                                       |

#### IR sub-layers (immutable, copy-on-write)

```
AST   raw validated capability snapshot          (collect output)
HIR   normalised — FormatterNode.fn resolved     (normalize output)
MIR   strategy resolved — mason/system decided   (resolve output)
LIR   optimised — deduped parsers, merged LSP    (optimize output)
SPEC  codegen input — all fields present         (codegen input)
```

Every phase returns a **new IR** via `ir.with()` / `ir.clone()`. Input IR is never mutated.

#### CompilerContext

```lua
---@class CompilerContext
---@field ir          IR
---@field stage       string
---@field diagnostics Diagnostic[]
---@field cache_key   string
---@field timings     table<string, number>
```

#### Phase interface (`core/pass.lua`)

```lua
---@class Phase
---@field name         string
---@field input_state  string
---@field output_state string
---@field run          fun(ir: IR): IR
---@field validate?    fun(ir: IR): Diagnostic[]
```

`run()` is pure: never mutates input, always returns a table, wrapped in `pcall` so errors become `Diagnostic` entries rather than panics.

---

### Strategy System (`toolchain/`)

Strategies encapsulate toolchain decisions behind a uniform interface, decoupled from both the compiler and the backend adapters.

```lua
---@class Strategy
---@field applies   fun(ctx, node): boolean
---@field transform fun(ctx, node): node
---@field priority  number
```

**StrategyRegistry** (`toolchain/strategy/registry.lua`) supports `register(strategy)` and `get(name)` / `list()`. Built-in strategy kinds: `formatter`.

**Toolchain resolution priority:**

1. User overrides (`vim.g.ltos_tool_overrides` or `toolchain/mappings.lua` `overrides`)
2. `system_tools` set (rustfmt, gofmt, zigfmt, fish, nixpkgs_fmt, …)
3. Nix environment (`core/env.lua` `M.is_nix`)
4. `tool_to_mason` mapping table
5. Identity fallback

---

### Three-Tier Cache (`core/cache.lua`)

Cache lives under `stdpath("cache")/ltos/`, keyed by `sha256(module_file_contents) + ":" + profile`.

| Tier   | Key unit             | Invalidation                 |
| ------ | -------------------- | ---------------------------- |
| `ast`  | per-module file hash | file content change          |
| `ir`   | IR segment hash      | upstream module change       |
| `spec` | full build hash      | any module or profile change |

Spec-tier hit skips the pipeline entirely. Specs containing function values set `_no_cache = true` and are excluded from serialization.

---

### Backend Adapters (`runtime/adapters/`)

Adapters implement the backend interface and are the only layer that produces `LazySpec[]`. They read the IR; they never write it.

```lua
---@class Backend
---@field supports fun(cap: string): boolean
---@field emit     fun(ir: IR): LazySpec[]
```

| Adapter          | Capability driven       |
| ---------------- | ----------------------- |
| `lsp.lua`        | `IR.merged_lsp`         |
| `mason.lua`      | `IR.resolved`           |
| `treesitter.lua` | `IR.all_parsers`        |
| `conform.lua`    | `IR.caps[*].formatters` |
| `lint.lua`       | `IR.caps[*].linters`    |

---

### Profiles

```lua
-- config/globals.lua
vim.g.ltos_profile = "minimal"  -- "full" (default) | "minimal" | "nix"
```

| Profile            | Modules loaded                      |
| ------------------ | ----------------------------------- |
| `"full"` (default) | all lang modules                    |
| `"minimal"`        | `lua` only                     |
| `"nix"`            | all modules, system tools preferred |

---

### User Commands

| Command              | Description                                                              |
| -------------------- | ------------------------------------------------------------------------ |
| `:LtosInfo`          | profile, pipeline state, modules, tools, strategies, per-stage timings   |
| `:LtosDebug [stage]` | foldable IR snapshot at `collect` / `normalize` / `resolve` / `optimize` |
| `:LtosIR`            | full LIR dump (post-optimize) in a scratch buffer                        |
| `:LtosTrace`         | per-phase execution timeline with ASCII bar chart                        |
| `:LtosGraph`         | module → capability dependency graph                                     |
| `:LtosDiff [a] [b]`  | structural IR diff between two stages (default: `collect` → `optimize`)  |

---

### File Structure

```
lua/
├── core/                          Layer 0–2: kernel · compiler · domain IR
│   ├── kernel/                    [L0] earliest inits, zero dependencies
│   │   ├── bootstrap.lua          netrw off, leader keys
│   │   ├── env.lua                Nix / SSH / GUI environment detection
│   │   └── util.lua               dedup, pure helpers
│   │
│   ├── compiler/                  [L1] compiler kernel; host IO via ports.lua
│   │   ├── ir.lua                 IR struct, CompilerContext, deterministic diagnostics
│   │   ├── pass.lua               Phase interface + protected run_phase()
│   │   ├── ports.lua              injectable host ports (cache/json/runtime-file)
│   │   └── cache.lua              two-tier FNV-1a content-keyed cache (ast / spec)
│   │
│   └── domain/                    [L2] domain IR, immutable value objects
│       ├── schema.lua             typed validator, error recovery, diagnostics
│       ├── capability.lua         immutable CapabilitySet: add / snapshot
│       └── icons.lua              single source of truth for glyphs
│
├── toolchain/                     Layer 3: strategy
│   ├── strategy/                  Strategy Pattern — three-file separation
│   │   ├── interface.lua          Strategy type contract (LuaLS annotations only)
│   │   ├── registry.lua           StrategyRegistry: register / get / list / bootstrap
│   │   ├── builtin.lua            built-in strategies: ruff_or_black, prettierd_or_prettier, stylua_or_lua_format
│   ├── mappings.lua               tool → mason package; system_tools set
│   └── rules.lua                  ToolchainStrategy: mason-vs-system decision rules
│
├── runtime/                       Layer 1 (orchestration) + Layer 4 (backend)
│   ├── init.lua                   orchestrator: BuildRequest, profile, two-tier cache
│   ├── build_request.lua          sole vim.g entry for compilation config
│   ├── ports_bootstrap.lua        injects vim APIs into core/compiler/ports
│   ├── pipeline.lua               state machine + 5-phase compiler kernel
│   ├── commands.lua               observability commands: LtosInfo/Debug/IR/Trace/Graph
│   ├── api.lua                    editor façade: api.editor / api.lsp / api.diagnostics / api.find
│   ├── passes/                    [L4] compiler phases (pure IR transforms, copy-on-write)
│   │   ├── collect.lua            Phase 1: IDLE→COLLECTING, DSL→AST
│   │   ├── normalize.lua          Phase 2: COLLECTING→NORMALIZING, AST→HIR
│   │   ├── canonicalize.lua       Phase 2.5: NORMALIZING→CANONICALIZING, HIR→HIR+symbols
│   │   ├── resolve.lua            Phase 3: CANONICALIZING→RESOLVING, HIR+→MIR
│   │   ├── optimize.lua           Phase 4: RESOLVING→OPTIMIZING, MIR→LIR
│   │   └── codegen.lua            Phase 5: OPTIMIZING→CODEGEN→DONE, LIR→SPEC
│   └── adapters/                  [L4] backend — read-only IR consumers
│       ├── lsp.lua
│       ├── mason.lua
│       ├── treesitter.lua
│       ├── conform.lua
│       └── lint.lua
│
├── modules/lang/                  Layer 5: DSL — pure declarations, zero side-effects
│   ├── asm.lua                    x86/x64 assembly (asm_lsp)
│   ├── c_cpp.lua                  C / C++ (clangd, clang-format, clangtidy)
│   ├── go.lua                     Go (gopls, gofmt, goimports)
│   ├── java.lua                   Java (jdtls, google-java-format, checkstyle)
│   ├── kotlin.lua                 Kotlin (kotlin_language_server, ktfmt, ktlint)
│   ├── lisp.lua                   Lisp / Clojure (clojure_lsp, cljfmt, clj-kondo)
│   ├── lua.lua                    Lua (lua_ls, stylua)
│   ├── markup.lua                 JSON/JSONC/YAML/TOML/HTML/CSS/SCSS/Markdown
│   ├── nix.lua                    Nix (nil_ls, nixpkgs_fmt — system)
│   ├── python.lua                 Python (pyright, ruff-or-black, ruff)
│   ├── rust.lua                   Rust (rust_analyzer, rustfmt — system, clippy — system)
│   ├── shell.lua                  Bash/Fish (bashls, shfmt, shellcheck)
│   ├── typescript.lua             JS/TS/JSX/TSX (vtsls, prettierd-or-prettier, eslint_d)
│   └── zig.lua                    Zig (zls, zigfmt — system)
│
├── config/                        Layer 5: app config — zero compiler knowledge
│   ├── autocmds.lua
│   ├── globals.lua                vim.g.* defaults (profile, debug flags)
│   ├── icons.lua                  re-exports core/domain/icons.lua for app layer
│   ├── keymaps.lua                editor keymaps via runtime.api façade
│   ├── lazy.lua                   lazy.nvim bootstrap + runtime.build()
│   └── options.lua                all vim.opt.* settings
│
└── plugins/                       Layer 5: UI / editor / AI — no toolchain logic
    ├── ai/ai.lua
    ├── coding/                    coding.lua · comments.lua · pairs.lua · snip.lua
    ├── editor/                    editor.lua · cursor.lua
    ├── formatting/formatting.lua
    ├── linting/linting.lua
    ├── lsp/lsp.lua
    ├── sys/                       git.lua · terminal.lua
    ├── theme/theme.lua
    ├── treesitter/treesitter.lua
    └── ui/                        ui.lua · snacks.lua
```

---

### Lang Modules (DSL)

Each file under `modules/lang/` is a pure Lua table — no `require`, no side effects, no vim API.

```lua
-- modules/lang/typescript.lua  (actual current content)
return {
  version    = 1,
  treesitter = { "javascript", "typescript", "tsx", "jsdoc" },
  lsp        = { vtsls = { settings = { ... } } },
  formatters = {
    typescript      = { { kind = "formatter", strategy = "prettierd_or_prettier" } },
    typescriptreact = { { kind = "formatter", strategy = "prettierd_or_prettier" } },
  },
  linters = {
    typescript      = { "eslint_d" },
    typescriptreact = { "eslint_d" },
  },
  -- LSP packages are resolved automatically via lsp_to_mason — never put them here.
  -- mason[] is for formatter / linter tools only.
  mason = { "prettierd", "eslint_d" },
}
```

For runtime fallback logic, use a `FormatterNode` instead of a plain string:

```lua
-- modules/lang/python.lua
formatters = {
  python = { { kind = "formatter", strategy = "ruff_or_black" } },
},
```

| Strategy                | Behavior                                             |
| ----------------------- | ---------------------------------------------------- |
| `ruff_or_black`         | prefers `ruff_format`; falls back to `isort + black` |
| `prettierd_or_prettier` | prefers `prettierd`; falls back to `prettier`        |
| `stylua_or_lua_format`  | prefers `stylua`; falls back to `lua_format`         |

Register custom strategies before the pipeline runs:

```lua
require("toolchain.strategy.registry").register({
  name     = "my_strategy",
  applies  = function(tool) return tool == "my_strategy" end,
  resolve  = function(bufnr) return { "my_formatter" } end,
  priority = 50,
})
```

### Adding a New Language

Create `lua/modules/lang/mylang.lua`:

```lua
return {
  version    = 1,
  treesitter = { "mylang" },
  lsp        = { mylang_ls = {} },          -- LSP pkg resolved via lsp_to_mason automatically
  formatters = { mylang = { "myfmt" } },
  linters    = { mylang = { "mylint" } },
  mason      = { "myfmt", "mylint" },       -- formatter/linter tools only; never LSP names here
}
```

Add `lua/modules/lang/mylang.lua` — **no manual registration required**. `ModuleProvider.discover()` auto-detects new files under `modules/lang/`.

Optional: `require("runtime.providers.registry").register("modules.lang.mylang")` for out-of-tree modules.

If the LSP server name differs from its mason package name, add an entry to `lsp_to_mason` in `lua/toolchain/mappings.lua` (or `mappings.register_lsp(server, pkg)`).
If a formatter/linter tool name differs from its mason package name, add an entry to `tool_to_mason` (or `mappings.register_tool(tool, pkg)`).

---

## Plugin Overview

Built on **LazyVim v8** (`LazyVim/LazyVim`). All plugins below are layered on top.

### UI

| Plugin                        | Purpose                                                                    |
| ----------------------------- | -------------------------------------------------------------------------- |
| `catppuccin/nvim`             | colorscheme — Mocha, transparent background                                |
| `akinsho/bufferline.nvim`     | tabline with LSP diagnostics indicators                                    |
| `nvim-lualine/lualine.nvim`   | statusline with git, diagnostics, DAP, noice status                        |
| `folke/noice.nvim`            | replaces cmdline, messages, and LSP hover UI                               |
| `nvim-mini/mini.icons`        | icon provider                                                              |
| `MunifTanjim/nui.nvim`        | UI component library (noice dependency)                                    |
| `nvim-tree/nvim-web-devicons` | file type icons                                                            |
| `folke/snacks.nvim`           | dashboard, picker, explorer, indent guides, scroll, notifier, zen, toggles |

### Editor

| Plugin                     | Purpose                              |
| -------------------------- | ------------------------------------ |
| `folke/which-key.nvim`     | keymap hints (helix preset)          |
| `lewis6991/gitsigns.nvim`  | git hunk signs, blame, diff          |
| `MagicDuck/grug-far.nvim`  | find-and-replace UI                  |
| `folke/flash.nvim`         | motion / jump                        |
| `mg979/vim-visual-multi`   | multi-cursor (`<C-n>` / `<C-d>`)     |
| `folke/trouble.nvim`       | diagnostics / quickfix list          |
| `folke/todo-comments.nvim` | highlight and search TODO/FIX/HACK/… |

### Git

| Plugin                   | Purpose                         |
| ------------------------ | ------------------------------- |
| `NeogitOrg/neogit`       | Magit-style git UI              |
| `sindrets/diffview.nvim` | diff viewer (neogit dependency) |

### LSP / Toolchain

| Plugin                            | Purpose                                                              |
| --------------------------------- | -------------------------------------------------------------------- |
| `neovim/nvim-lspconfig`           | LSP client configuration                                             |
| `mason-org/mason.nvim`            | LSP / tool installer                                                 |
| `mason-org/mason-lspconfig.nvim`  | mason ↔ lspconfig bridge                                             |
| `stevearc/conform.nvim`           | formatter engine (`formatters_by_ft` built by pipeline)              |
| `mfussenegger/nvim-lint`          | linter engine (`linters_by_ft` built by pipeline)                    |
| `nvim-treesitter/nvim-treesitter` | syntax / folds / text objects (`ensure_installed` built by pipeline) |

### Coding

| Plugin                                                                               | Purpose                                                       |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------- |
| `nvim-mini/mini.pairs`                                                               | auto-pairs                                                    |
| `folke/ts-comments.nvim`                                                             | treesitter-aware comments for 30+ languages                   |
| `nvim-mini/mini.ai`                                                                  | extended text objects (`af`, `ac`, `ao`, `at`, `ad`, `ae`, …) |
| `L3MON4D3/LuaSnip`                                                                   | snippet engine                                                |
| `hrsh7th/nvim-cmp` + `hrsh7th/cmp-emoji`                                             | completion + emoji source                                     |
| `mfussenegger/nvim-dap` + `rcarriga/nvim-dap-ui` + `theHamsta/nvim-dap-virtual-text` | debug adapter protocol                                        |

### AI

| Plugin                         | Purpose                                         |
| ------------------------------ | ----------------------------------------------- |
| `github/copilot.vim`           | GitHub Copilot (`:Copilot`)                     |
| `olimorris/codecompanion.nvim` | AI chat / inline / actions (`<leader>ai/aa/ac`) |

### Terminal

| Plugin                    | Purpose                                               |
| ------------------------- | ----------------------------------------------------- |
| `akinsho/toggleterm.nvim` | floating / horizontal terminal (`<C-t>`, `<leader>t`) |
| `nvim-tree/nvim-tree.lua` | file tree sidebar (`<leader>fe`)                      |

---

## Supported Languages

| Language                        | LSP                    | Formatter                   | Linter             |
| ------------------------------- | ---------------------- | --------------------------- | ------------------ |
| Assembly (x86/x64)              | asm_lsp                | —                           | —                  |
| C / C++                         | clangd                 | clang-format                | clangtidy (system) |
| Go                              | gopls                  | gofmt (system), goimports   | —                  |
| Java                            | jdtls                  | google-java-format          | checkstyle         |
| Kotlin                          | kotlin_language_server | ktfmt                       | ktlint             |
| Lisp / Clojure                  | clojure_lsp            | cljfmt                      | clj-kondo          |
| Lua                             | lua_ls                 | stylua                      | —                  |
| Markup (JSON/YAML/TOML/HTML/MD) | jsonls, yamlls, taplo  | taplo / prettierd           | —                  |
| Nix                             | nil_ls                 | nixpkgs_fmt (system)        | —                  |
| Python                          | pyright                | ruff-or-black               | ruff               |
| Rust                            | rust_analyzer          | rustfmt (system)            | clippy (system)    |
| Shell (Bash/Fish)               | bashls                 | shfmt, fish_indent (system) | shellcheck         |
| TypeScript / JavaScript         | vtsls                  | prettierd-or-prettier       | eslint_d           |
| Zig                             | zls                    | zigfmt (system)             | —                  |

---

## Key Bindings (selected)

| Key               | Action                    |
| ----------------- | ------------------------- |
| `<leader><space>` | smart find files (snacks) |
| `<leader>/`       | grep                      |
| `<leader>e`       | file explorer (snacks)    |
| `<leader>fe`      | nvim-tree toggle          |
| `<leader>ff`      | find files                |
| `<leader>fg`      | find git files            |
| `<leader>fr`      | recent files              |
| `<leader>sg`      | grep                      |
| `<leader>ss`      | LSP symbols               |
| `<leader>cf`      | format buffer             |
| `<leader>ca`      | code action               |
| `<leader>cr`      | rename symbol             |
| `<leader>cd`      | diagnostic float          |
| `<leader>ai`      | AI chat toggle            |
| `<leader>aa`      | AI actions                |
| `<C-n>`           | multi-cursor add next     |
| `<C-t>`           | toggle terminal           |
| `<leader>t`       | float terminal            |
| `<leader>ngg`     | Neogit UI                 |
| `<leader>z`       | zen mode                  |
| `]h` / `[h`       | next / prev git hunk      |
| `gd`              | goto definition           |
| `gr`              | references                |
| `K`               | hover                     |

> [more keymaps](./KEYMAPS.md)

---

## Options (highlights)

| Option                   | Value                             |
| ------------------------ | --------------------------------- |
| `foldmethod`             | `expr` (treesitter)               |
| `clipboard`              | `unnamedplus` (disabled over SSH) |
| `timeoutlen`             | 300ms (1000ms in VSCode)          |
| `scrolloff`              | 4                                 |
| `shiftwidth` / `tabstop` | 2                                 |
| `relativenumber`         | true                              |
| `laststatus`             | 3 (global statusline)             |
| `smoothscroll`           | true                              |

---

## Tests

```bash
just check   # layer boundary violations (scripts/check_layer_boundaries.sh)
just test    # 19 headless LTOS regression tests (scripts/run_ltos_tests.sh)
```

Coverage includes: cache ports, ir/schema deterministic diagnostics, BuildRequest, nix profile, adapter registry, pipeline `PHASE_ORDER`, `runtime.build()`, ConfigProvider, terminal API.
