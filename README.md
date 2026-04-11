# nvim-config

A Neovim configuration built on **LazyVim** with a custom compiler-inspired toolchain layer called **LTOS** (Language Toolchain Orchestration System). Lang modules are a pure DSL; a five-stage pipeline compiles them into lazy.nvim plugin specs at startup.

## Requirements

| Dependency                                       | Notes                    |
| ------------------------------------------------ | ------------------------ |
| Neovim ≥ 0.11                                    | required                 |
| Git                                              | lazy.nvim bootstrap      |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | grep / search            |
| [fd](https://github.com/sharkdp/fd)              | file finding             |
| A [Nerd Font](https://www.nerdfonts.com/)        | icons / glyphs           |
| Node.js                                          | many LSP servers         |
| Python 3                                         | pyright, ruff, etc.      |
| Rust toolchain                                   | rust_analyzer, rustfmt   |
| Go toolchain                                     | gopls, gofmt             |
| Zig toolchain                                    | zls, zigfmt              |
| `stylua`                                         | Lua formatter (system)   |
| `shfmt`                                          | shell formatter (system) |
| `shellcheck`                                     | shell linter (system)    |

On **NixOS / nix-darwin**: tools detected via `core/env.lua` (`M.is_nix`). System-managed binaries are never installed via mason.

## Installation

```bash
git clone https://github.com/Redskaber/nvim-config ~/.config/nvim
nvim  # lazy.nvim bootstraps itself on first launch
```

Mason installs LSP servers, formatters, and linters automatically on first startup.

## Plugin Overview

This config is built on **LazyVim v8** (`LazyVim/LazyVim`) as the base distribution. All plugins below are layered on top.

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

## LTOS — Language Toolchain Orchestration System

The toolchain layer compiles lang module DSL into lazy.nvim specs via a five-stage pipeline.

### Architecture

```
modules/lang/*.lua   →   Pipeline (5 stages)   →   lazy.nvim specs
     (DSL)                                           (codegen output)
```

```
┌─────────────────────────────────────────────┐
│  Entry: init.lua                            │
│    → core/bootstrap.lua  (earliest inits)   │
│    → config/lazy.lua     (lazy.nvim setup)  │
└──────────────────┬──────────────────────────┘
                   │ runtime.build()
┌──────────────────▼──────────────────────────┐
│  Orchestration: runtime/init.lua            │
│  Pipeline:      runtime/pipeline.lua        │
│  Pass runner:   core/pass.lua               │
└──┬──────┬──────┬──────┬──────┬──────────────┘
   │      │      │      │      │
collect normalize resolve optimize codegen
┌──▼──────▼──────▼──────▼──────▼──────────────┐
│  IR: core/ir.lua  ·  Schema: core/schema.lua │
└──┬───────────────────────────────────────────┘
   │
┌──▼───────────────────────────────────────────┐
│  Registry: core/capability.lua               │
│  DSL:      modules/lang/*.lua                │
└──┬───────────────────────────────────────────┘
   │
┌──▼───────────────────────────────────────────┐
│  Toolchain: toolchain/rules.lua              │
│             toolchain/mappings.lua           │
│             toolchain/strategies/            │
└──┬───────────────────────────────────────────┘
   │
┌──▼───────────────────────────────────────────┐
│  Adapters: runtime/adapters/                 │
│    lsp · mason · treesitter · conform · lint │
└──────────────────────────────────────────────┘
```

### Pipeline Stages

| Stage         | Input                      | Output                                                      |
| ------------- | -------------------------- | ----------------------------------------------------------- |
| **collect**   | `modules/lang/*.lua` paths | `IR.caps` — validated capability registry                   |
| **normalize** | `IR.caps`                  | `FormatterNode.fn` injected (deep-copy; registry untouched) |
| **resolve**   | `IR.caps`                  | `IR.resolved` — per-tool mason/system decision              |
| **optimize**  | `IR.resolved`              | `IR.merged_lsp`, `IR.all_parsers` — deduped                 |
| **codegen**   | full IR                    | `LazySpec[]` consumed by lazy.nvim                          |

State machine: `idle → collecting → normalizing → resolving → optimizing → codegen → done`. Each `run()` / `debug_run()` gets its own independent instance.

Each stage is a **Pass** (`core/pass.lua`): `{ name, run(IR)→IR, validate?(IR)→CompileError[] }`. Passes are pure — they never mutate the input IR.

### Pipeline Caching

Three-tier cache (`ast` / `ir` / `spec`) under `stdpath("cache")/ltos/`, keyed by `sha256(module_file_contents) + ":" + profile`. Cache hit skips the pipeline entirely. Specs with function values set `_no_cache = true` and are excluded from serialization.

### File Structure

```
lua/
├── core/
│   ├── bootstrap.lua       earliest inits (netrw, etc.)
│   ├── capability.lua      registry: add / snapshot / reset
│   ├── cache.lua           three-tier sha256-keyed cache
│   ├── env.lua             Nix / SSH / GUI detection
│   ├── ir.lua              IR struct, clone, validate, error helpers
│   ├── pass.lua            Pass interface + protected run_pass()
│   ├── schema.lua          capability validation, fail-fast
│   └── util.lua            dedup, misc helpers
├── config/
│   ├── autocmds.lua
│   ├── globals.lua         vim.g.* defaults
│   ├── icons.lua           single source of truth for glyphs
│   ├── keymaps.lua         editor keymaps via runtime.api facade
│   ├── lazy.lua            lazy.nvim bootstrap + runtime.build()
│   └── options.lua         all vim.opt.* settings
├── modules/lang/           pure DSL — zero side-effects
│   ├── c_cpp.lua
│   ├── go.lua
│   ├── lua_lang.lua
│   ├── markup.lua          json/jsonc/yaml/toml/html/css/scss/md
│   ├── nix.lua
│   ├── python.lua
│   ├── rust.lua
│   ├── shell.lua
│   ├── typescript.lua      js/ts/jsx/tsx
│   └── zig.lua
├── runtime/
│   ├── init.lua            orchestrator: profile, cache, build()
│   ├── pipeline.lua        state machine + 5-stage pipeline
│   ├── commands.lua        :LtosDebug, :LtosInfo
│   ├── api.lua             unified facade: format, picker, terminal, lsp, diagnostics
│   └── adapters/
│       ├── lsp.lua
│       ├── mason.lua
│       ├── treesitter.lua
│       ├── conform.lua
│       └── lint.lua
├── toolchain/
│   ├── mappings.lua        tool → mason pkg; system_tools set
│   ├── rules.lua           ToolchainStrategy: mason vs system
│   └── strategies/
│       ├── init.lua        FormatterStrategy registry
│       └── formatters.lua  bootstrap(registry): ruff_or_black, prettierd_or_prettier
└── plugins/                UI / editor / AI — no toolchain logic
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

### Lang Modules (DSL)

Each file under `modules/lang/` is a pure Lua table — no `require`, no side effects.

```lua
-- modules/lang/typescript.lua
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

Register custom strategies before the pipeline runs:

```lua
require("toolchain.strategies").register("my_strategy", function(bufnr)
  return { "my_formatter" }
end)
```

### Toolchain Resolution Priority

1. User overrides (`vim.g.ltos_tool_overrides` or `toolchain/mappings.lua` `overrides`)
2. `system_tools` set (rustfmt, gofmt, zigfmt, fish, nixpkgs_fmt, git, …)
3. Nix environment (`core/env.lua` `M.is_nix`)
4. `tool_to_mason` mapping table
5. Identity fallback

### Profiles

```lua
-- config/globals.lua
vim.g.ltos_profile = "minimal"  -- or "full" (default) or "nix"
```

| Profile            | Modules loaded                      |
| ------------------ | ----------------------------------- |
| `"full"` (default) | all lang modules                    |
| `"minimal"`        | `lua_lang` only                     |
| `"nix"`            | all modules, system tools preferred |

### User Commands

| Command              | Description                                                        |
| -------------------- | ------------------------------------------------------------------ |
| `:LtosInfo`          | profile, state, modules, tools, strategies, per-stage timings      |
| `:LtosDebug [stage]` | foldable IR snapshot at `collect`/`normalize`/`resolve`/`optimize` |

### Terminal Backend (pluggable)

```lua
require("runtime.api").terminal.register("snacks_term", {
  float      = function() Snacks.terminal() end,
  horizontal = function() Snacks.terminal(nil, { win = { position = "bottom" } }) end,
})
vim.g.ltos_terminal_backend = "snacks_term"
```

### Adding a New Language

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

Add the module path to `LANG_MODULES` in `lua/runtime/init.lua`. LSP mason packages are resolved automatically — only formatter/linter tool names belong in `mason = {}`.

---

## Supported Languages

| Language                        | LSP                   | Formatter         | Linter     |
| ------------------------------- | --------------------- | ----------------- | ---------- |
| C / C++                         | clangd                | clang-format      | clangtidy  |
| Go                              | gopls                 | gofmt             | —          |
| Lua                             | lua_ls                | stylua            | —          |
| Markup (JSON/YAML/TOML/HTML/MD) | jsonls, yamlls, taplo | taplo / prettierd | —          |
| Nix                             | nil_ls                | nixpkgs_fmt       | —          |
| Python                          | pyright               | ruff-or-black     | ruff       |
| Rust                            | rust_analyzer         | rustfmt           | clippy     |
| Shell                           | —                     | shfmt             | shellcheck |
| TypeScript / JavaScript         | vtsls                 | prettierd         | eslint     |
| Zig                             | zls                   | zigfmt            | —          |

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
nvim --headless -l spec/core/schema_spec.lua
nvim --headless -l spec/core/ir_spec.lua
nvim --headless -l spec/toolchain/mappings_spec.lua
nvim --headless -l spec/toolchain/strategies_spec.lua
nvim --headless -l spec/runtime/pipeline_spec.lua
nvim --headless -l spec/runtime/commands_spec.lua
```
