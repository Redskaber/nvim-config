# 配置参考 (Configuration Reference)

All `vim.g.*` knobs exposed by the nvim-config (LTOS) project. Each row lists the
default, where it is set (file:line), and which module consumes it. Knobs marked
**Layer 0** MUST be set before `require("config.lazy")` runs `lazy.setup()`;
everything else can be edited in `lua/config/globals.lua`.

## 1. LTOS 运行时旋钮 (LTOS runtime knobs)

| Knob | Default | Set in | Purpose |
| ------ | --------- | -------- | --------- |
| `vim.g.ltos_profile` | `"full"` | globals.lua:32 (commented) | Profile selection: `full` / `minimal` / `nix`. Consumed by `runtime/init.lua`, passed into `BuildRequest.from_vim` (build_request.lua:40). |
| `vim.g.ltos_debug` | `false` | globals.lua:33 (commented); also derived from `LTOS_DEBUG` at globals.lua:58 | Master debug switch. Read by build_request.lua:20 and ports_bootstrap.lua:31. |
| `vim.g.ltos_debug_cache` | `nil` | globals.lua:59 (from `LTOS_DEBUG`) | Cache-layer debug logging. Read by build_request.lua:21 and ports_bootstrap.lua:31. |
| `vim.g.ltos_debug_ir` | `nil` | globals.lua:60 (from `LTOS_DEBUG`) | Set by `LTOS_DEBUG=ir`; currently not consumed by BuildRequest (reserved for future IR-level debug logging). |
| `vim.g.ltos_debug_perf` | `nil` | globals.lua:61 (from `LTOS_DEBUG`) | Performance profiling. Read by build_request.lua:22. |
| `vim.g.ltos_debug_trace` | `nil` | globals.lua:62 (from `LTOS_DEBUG`) | Pipeline trace logging. Read by build_request.lua:23. |
| `vim.g.ltos_tool_overrides` | `{}` | globals.lua:34 (commented) | Per-tool `{ use_mason, pkg }` overrides. Read by build_request.lua:41. |
| `vim.g.ltos_terminal_backend` | `"toggleterm"` | globals.lua:35 (commented) | Terminal backend selection. |
| `vim.g.ltos_picker_backend` | `nil` (auto) | `api.lua:92` | Picker backend: `"snacks"` / `"telescope"`. nil → auto-detect. |
| `vim.g.ltos_base_mason_tools` | `{ "codespell" }` | globals.lua:36 (commented) | Base Mason tool list. Read by build_request.lua:46 (falls back to `DEFAULT_BASE_TOOLS`). |
| `vim.g.ltos_base_parsers` | `nil` | globals.lua:37 (commented) | Base treesitter parsers. Read by build_request.lua:51 (nil → adapter uses `DEFAULT_BASE_PARSERS`). |
| `vim.g.ltos_disabled_plugins` | `DEFAULT_DISABLED_PLUGINS` (gzip, matchit, matchparen, netrwPlugin, tarPlugin, tohtml, tutor, zipPlugin) | globals.lua:38 (commented) | lazy.nvim `performance.rtp.disabled_plugins`. Read by providers/config.lua:51. |
| `vim.g.ltos_auto_update` | `false` | **bootstrap.lua:37 (Layer 0)** | Enable lazy.nvim background checker. Read by providers/config.lua:57. **Layer 0** — `build_setup_opts()` runs before `globals.lua` loads. |
| `vim.g.ltos_debug_invariants` | `nil` | (no default) | Enable `core.compiler.invariants`. Read by ports_bootstrap.lua:40. |

## 2. LazyVim 特性标志 (LazyVim feature flags)

| Knob | Default | Set in | Purpose |
| ------ | --------- | -------- | --------- |
| `vim.g.lazyvim_file_explorer` | `"snacks"` | **bootstrap.lua:28 (Layer 0)** | File explorer choice. **Layer 0** — LazyVim reads it during spec construction inside `lazy.setup()`; setting it later in `globals.lua` is too late. |
| `vim.g.lazyvim_picker` | `"auto"` | globals.lua:18 | Picker: `telescope` / `fzf` / `auto`. |
| `vim.g.lazyvim_cmp` | `"auto"` | globals.lua:19 | Completion engine: `nvim-cmp` / `blink.cmp` / `auto`. |
| `vim.g.autoformat` | `true` | globals.lua:16 | Format-on-save toggle. |
| `vim.g.snacks_animate` | `true` | globals.lua:17 | Snacks animation toggle. |
| `vim.g.ai_cmp` | `true` | globals.lua:20 | AI completion suggestions in cmp. |
| `vim.g.deprecation_warnings` | `false` | globals.lua:21 | Show LazyVim deprecation warnings. |
| `vim.g.trouble_lualine` | `true` | globals.lua:22 | Trouble statusline integration. |
| `vim.g.root_spec` | `{ "lsp", { ".git", "lua", "Cargo.toml", "pyproject.toml" }, "cwd" }` | globals.lua:25 | Root detection order: LSP → project markers → cwd. |
| `vim.g.root_lsp_ignore` | `{ "copilot" }` | globals.lua:26 | LSP servers to skip when finding root. |
| `vim.g.markdown_recommended_style` | `0` | globals.lua:29 | Disable LazyVim's markdown indent override (we ship our own). |

## 3. 其他全局变量 (Other globals)

| Knob | Default | Set in | Purpose |
| ------ | --------- | -------- | --------- |
| `vim.g.image_doc_trash_cmd` | `"rm"` | globals.lua:8 | Snacks.image trash command. Set to `"trash"` if `trash-cli` is installed (avoids healthcheck error). |
| `vim.g.mapleader` | `" "` (space) | **bootstrap.lua:18 (Layer 0)** | Leader key. **Layer 0** — must be set before plugins parse keymaps. |
| `vim.g.maplocalleader` | `"\\"` | **bootstrap.lua:19 (Layer 0)** | Local leader key. **Layer 0**. |
| `vim.g.loaded_netrw` | `1` | **bootstrap.lua:14 (Layer 0)** | Disable netrw so Snacks/neo-tree can manage directories. **Layer 0**. |
| `vim.g.loaded_netrwPlugin` | `1` | **bootstrap.lua:15 (Layer 0)** | Disable netrw plugin. **Layer 0**. |

## 4. 环境变量 (Environment variables)

| Variable | Values | Set in | Purpose |
|----------|--------|--------|---------|
| `LTOS_DEBUG` | `trace`, `ir`, `cache`, `perf` (comma-separated, order-independent) | shell env, parsed at globals.lua:52-62 | Sets the corresponding `vim.g.ltos_debug_*` flags. Setting any flag also flips `vim.g.ltos_debug = true` (master switch). |

## 覆盖方式 (How to override)

### Layer 0 旋钮 (must set before `lazy.setup()`)

Edit `lua/core/kernel/bootstrap.lua`, or set in `init.lua` before
`require("config.lazy")`:

```lua
-- init.lua
vim.g.ltos_auto_update = true       -- enable lazy.nvim background checker
vim.g.lazyvim_file_explorer = "snacks"
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
require("config.lazy")
```

Knobs that MUST be Layer 0:

- `loaded_netrw`, `loaded_netrwPlugin` — disable netrw before anything loads it.
- `mapleader`, `maplocalleader` — must be set before plugins parse keymaps.
- `lazyvim_file_explorer` — LazyVim reads it at spec-construction time inside
  `lazy.setup()`; setting it later in `globals.lua` leaves the default neo-tree
  spec in place and Snacks keymaps get overridden.
- `ltos_auto_update` — `build_setup_opts()` in `providers/config.lua` reads it
  during `lazy.setup()`, which runs before `globals.lua` is sourced.

### globals.lua 旋钮 (runtime, loaded by `options.lua` inside `lazy.setup()`)

Uncomment or modify the corresponding line in `lua/config/globals.lua`:

```lua
vim.g.ltos_profile          = "minimal"
vim.g.ltos_debug            = true
vim.g.ltos_tool_overrides   = { lua = { use_mason = false, pkg = "lua-language-server" } }
vim.g.ltos_terminal_backend = "toggleterm"
vim.g.ltos_base_mason_tools = { "codespell", "stylua" }
vim.g.ltos_base_parsers     = { "bash", "c", "lua", "python", "vim", "vimdoc" }
vim.g.ltos_disabled_plugins = { "gzip", "matchit", "matchparen", "netrwPlugin",
                                "tarPlugin", "tohtml", "tutor", "zipPlugin" }
```

### LTOS_DEBUG 环境变量

Set in the shell before launching nvim:

```sh
LTOS_DEBUG=trace,cache nvim     # one-off
export LTOS_DEBUG=perf,ir       # session-wide
```

Valid flags: `trace`, `ir`, `cache`, `perf` (comma-separated, order-independent).
Any non-empty value with at least one recognized flag also enables the master
`vim.g.ltos_debug = true` switch (see globals.lua:58).

### Manual plugin update

When `vim.g.ltos_auto_update = false` (default), update plugins manually:

```vim
:Lazy check    " check for updates without applying
:Lazy update   " apply all pending updates
```

