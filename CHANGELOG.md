# CHANGELOG

## [2026-06-26] — 测试失败修复 + P1/P2 闭环

### 测试失败修复（5 文件，21 用例归零）

- **[TEST-BUG-1]** `toolchain/rules.lua` `nix_env_rule` — 不再无视 `prefer_system=false`
  - 修复前：Nix 主机上 `stylua` 在 `$PATH` 时被强制分类为 system tool，无视 BuildRequest 的 opt-out
  - 修复后：`ctx.prefer_system == false` 时跳过该规则，stylua 正确分类为 mason-managed
  - 影响：`runtime.passes_spec` 2 用例 + `toolchain.strategy_spec` 1 用例

- **[TEST-BUG-2]** 4 个 runtime adapter 的 `opts` 从 lazy function 改为静态 table
  - `lsp.lua` / `treesitter.lua` / `conform.lua` / `lint.lua` 均使用 `opts = function(_, opts) ... end`
  - 测试和下游消费者直接索引 `spec.opts.<field>` → `attempt to index field 'opts' (a function value)`
  - 修复：改为 `opts = { ... }` 静态表，构造时一次性计算
  - `conform.lua` custom-strategy formatter 注册从 opts 函数体迁到 `config` 函数（仿 `mason.lua`）
  - `conform.lua` 补齐 `default_format_opts` / `format_on_save` 字段
  - `lint.lua` 构造期去重 per-filetype linters
  - 影响：`runtime.adapters_spec` 12 用例 + `integration.full_pipeline_spec` 6 用例

### P1 闭环（剩余 2 项）

- **[P1-10]** `core/compiler/ports.lua` `ensure_cache_dir` 不再 shell out
  - 修复前：`os.execute('mkdir -p "' .. dir:gsub('"','\\"') .. '"')` — 命令注入风险
  - 修复后：libuv `vim.loop.fs_mkdir` 递归创建，无 shell，无注入
  - `ports_bootstrap.lua` 运行时覆盖（`vim.fn.mkdir(dir, "p")`）保持不变

- **[P1-11]** `modules/capability/registry.lua` `get_by_type` 返回浅拷贝
  - 修复前：`return _registry[cap_type] or {}` — 调用方可 `table.insert` 污染注册表
  - 修复后：始终返回新列表，调用方可自由 mutate

### P2 闭环（4 项）

- **[P2-2]** `runtime/pipeline.lua` SM 转移改从 Phase.output_state 派生
  - 修复前：`PHASE_NEXT_SM` 硬编码表与 Phase 元数据脱耦——`collect_ext.input_state="collecting"` 但 SM 在 collect 后已被推到 `normalizing`，不一致
  - 修复后：删除 `PHASE_NEXT_SM`，新增 `next_sm_state_for(phase, current_state)` 函数：side phase（`output_state == input_state`）不 transition；no-op（`output_state == current_state`）不 transition；否则 transition 到 `output_state`
  - 不变量：`phase[i]` 完成后 SM 状态 == `phase[i+1].input_state`（7 个转换全部满足）
  - codegen 的 SM transition 也改用同一函数（一致性）

- **[P2-3]** `runtime/pipeline.lua` `M.PHASE_ORDER` 改为 listener 驱动的实时表
  - 修复前：`M.PHASE_ORDER = phase_registry.phase_order()` — require 时快照，运行时动态注册 phase 后陈旧
  - 第一次尝试：metatable proxy（`__index`/`__len`/`__pairs`/`__ipairs`）— 但 LuaJIT 的 `#` 和 `ipairs()` 不可靠地触发 `__len`/`__ipairs`，破坏 9 个用 `ipairs(PHASE_ORDER)` 和 `#PHASE_ORDER` 的测试
  - 最终方案：`M.PHASE_ORDER` 是普通表，`phase_registry` 新增 `add_listener()` 注册回调；`register`/`register_codegen`/`_reset` 触发所有 listener；pipeline.lua 的 listener 就地清空+重填 `M.PHASE_ORDER`（保持表身份稳定）
  - `_reset()` 同时清空 listeners，避免测试中 `package.loaded` 重载累积陈旧 listener

- **[P2-6]** `modules/capability/defaults/keybind_presets.lua` 引用 data 模块
  - 修复前：硬编码 `"vim"` / `"helix"` / `"emacs"` 字符串作为 table key
  - 修复后：使用 `core.domain.keybind_presets_data.VIM` / `.HELIX` / `.EMACS` 常量
  - 运行时值不变（`presets_data.VIM == "vim"`），向后兼容

- **[P2-1]** 8 个 phase 定义 `output_validate` 后置条件（P6-D2）
  - 新增 `lua/runtime/output_validate.lua` 共享验证器模块
  - 每个 phase 的 `output_validate` 检查 stage 字段未回退 + 下游 phase 所需字段存在
  - 失败非致命：`pass.run_phase()` 降级为 warn diagnostic 追加到 IR
  - 8 个 phase 全部接线：collect / normalize / canonicalize / resolve / optimize / codegen / collect_ext / cap_resolve

### POLISH 闭环（3 项）

- **[POLISH-1]** `runtime/commands.lua` debug stage 列表从 phase registry 派生
  - 修复前：`VALID_DEBUG_STAGES` 表 + 4 个 `complete` 函数各自硬编码 `{collect, normalize, canonicalize, resolve, optimize}`——DRY 违反，新增/重命名 phase 需手动同步 5 处
  - 修复后：新增 `debug_stages()` 从 `phase_registry.list()` 派生，过滤掉 side phase（`input_state == output_state`，即 collect_ext/cap_resolve）和 codegen（terminal）；`VALID_DEBUG_STAGES` 改为 metatable live view；`M.refresh_debug_stages()` 支持动态 phase 注册后刷新缓存
  - 影响：新增/重命名 phase 自动反映到 `:LtosDebug`/`:LtosIR`/`:LtosDiff` tab-completion 和校验

- **[POLISH-2]** `runtime/pipeline.lua` `timings()` 返回浅拷贝
  - 修复前：`return _last_build_timings` 直接返回内部表引用——调用方可 `t.collect = 999` 污染内部状态
  - 修复后：返回 shallow copy，与 P1-11 `registry.get_by_type` 模式一致

- **[POLISH-3]** `runtime/adapters/conform.lua` config_fn 防御性 guard + 文档化 INV-13 边界
  - 新增 `pcall(require, "conform")` 防御 headless 测试场景（conform 未加载时 config_fn 不崩溃）
  - 新增 `vim.api` 可用性检查（headless 单元测试场景）
  - 注释明确 `vim.api` 调用位于 config_fn 的 format() 闭包内（format-time，非 build()），符合 INV-13

### 语言工具插件补充（5 文件，贵精不贵多）

新增 `plugins/lang/` 目录，按语言组织编辑增强插件。严格遵守职责分离：

- **LTOS adapter**（`runtime/adapters/`）继续负责 LSP/formatter/linter/mason/treesitter
- **plugins/lang/** 只负责编辑层增强（DAP/依赖管理/编译检查），纯 LazySpec，零 LTOS 引用

| 文件 | 插件 | 语言 | 职责 |
| ------ | ------ | ------ | ------ |
| `plugins/lang/go.lua` | `leoluz/nvim-dap-go` | Go | Delve DAP 集成（debug go test） |
| `plugins/lang/python.lua` | `mfussenegger/nvim-dap-python` | Python | debugpy DAP 集成（mason 自动检测） |
| `plugins/lang/lua.lua` | `jbyuki/one-small-step-for-vimkind` | Lua | Lua DAP（attach 到 nvim 实例调试 config） |
| `plugins/lang/rust.lua` | `Saecki/crates.nvim` | Rust | Cargo.toml 依赖版本管理/升级 |
| `plugins/lang/typescript.lua` | `dmmulroy/tsc.nvim` | TypeScript | tsc 后台编译检查 + trouble 集成 |

**第二轮补充**（3 文件，覆盖剩余高频语言）：

| 文件 | 插件 | 语言 | 职责 |
| ------ | ------ | ------ | ------ |
| `plugins/lang/c_cpp.lua` | `p00f/clangd_extensions.nvim` | C/C++ | clangd 增强（source/header 切换 + inlay hints） |
| `plugins/lang/lisp.lua` | `Olical/conjure` | Lisp 系 | REPL 评估（Clojure/Scheme/Common Lisp，REPL 驱动开发核心） |
| `plugins/lang/markup.lua` | `iamcco/markdown-preview.nvim` | Markdown | 浏览器实时预览（补 render-markdown 的 in-editor 渲染） |

**未补充的语言**（违反"贵精"原则，跳过）：

- `asm` — 汇编生态在 nvim 无成熟专用插件
- `java` — nvim-java 太重（违反贵精），jdtls 已由 LTOS adapter 管
- `kotlin` — 缺少成熟 nvim 专用插件
- `nix` — nix-ide.nvim 已过时（被 nil_ls 取代）
- `shell` — bashls+shfmt+shellcheck 工具链已完整
- `zig` — 生态在 nvim 中较新，暂无成熟插件

所有插件按 `ft` 懒加载，不增加启动开销。`plugins/init.lua` 自动发现（globpath `lua/plugins/**/*.lua`）。

### 通用性插件补充（4 文件，覆盖高频编辑工作流）

补充通用编辑增强插件，严格遵守职责分离：纯 LazySpec，零 LTOS 引用。

| 文件 | 插件 | 职责 | 选型理由 |
| ------ | ------ | ------ | ---------- |
| `plugins/coding/surround.lua` | `nvim-mini/mini.surround` | Surround 操作（sa/sd/sr 添加/删除/替换括号引号标签） | 与 mini.ai/mini.pairs 同生态；每天高频；~150 LOC |
| `plugins/coding/move.lua` | `nvim-mini/mini.move` | 行/块移动（Alt+j/k 上下移动） | 与 mini 生态一致；自动重缩进；~80 LOC |
| `plugins/coding/colorizer.lua` | `NvChad/nvim-colorizer.lua` | 颜色代码高亮（#hex/rgb()/hsl()/CSS/tailwind） | 2024+ 高性能 Lua 实现；前端/CSS/markdown 刚需 |
| `plugins/treesitter/context.lua` | `nvim-treesitter/nvim-treesitter-context` | Sticky context header（滚动时顶部固定函数签名） | "我现在在哪个函数里"高频问题；extmarks 实现零滚动开销 |

**刻意跳过的通用插件**（违反"贵精"或与现有重复）：

- `Comment.nvim` / `vim-commentary` — `ts-comments.nvim` 已覆盖（2024+ treesitter 感知注释）
- `nvim-spectre` — `grug-far.nvim` 已覆盖项目级查找替换
- `refactoring.nvim` — 较重，违反贵精原则
- `trim.nvim` — 尾空格清理可用 `vim.g` 选项或 autocmd 替代

### plugins/ 目录架构重组（职责分离/能力分类/层级关系）

将原来的 9 个松散目录（coding/editor/lsp/linting/formatting/sys/treesitter/ui/ai）重组为 **11 个职责清晰的层级目录**，每个文件一个能力（max cohesion）。

**重组原则**：

- **职责分离**：每个文件只负责一个能力（如 `surround.lua` 只管 surround 操作）
- **能力分类**：按插件功能而非"放置位置"分类（DAP 插件从 lang/ 移到 debug/）
- **层级关系**：editing < syntax < toolchain < debug < git < ui < system（从核心编辑到系统集成）

**旧 → 新目录映射**：

| 旧目录 | 新目录 | 文件数 | 职责 |
| -------- | -------- | -------- | ------ |
| coding/ | editing/ | 6 | 文本编辑原语（pairs/surround/move/comments/textobjects/visual-multi） |
| coding/ | completion/ | 3 | 补全（cmp/luasnip/snippets） |
| coding/ | syntax/ | 4 | 语法（treesitter/context/colorizer/markdown-render） |
| lsp/ linting/ formatting/ | toolchain/ | 3 | 工具链引擎（LSP/lint/format — LTOS adapter 目标） |
| coding/ (DAP 部分) + lang/ (DAP 部分) | debug/ | 4 | 调试（DAP 引擎 + per-lang 适配器） |
| sys/git + editor/ (gitsigns) | git/ | 2 | 版本控制（gitsigns/neogit） |
| editor/ (UI 部分) + ui/ | ui/ | 11 | 界面（bufferline/lualine/noice/snacks/flash/which-key/trouble/todo-comments/grug-far/icons/neo-tree-disable） |
| sys/ (terminal/img) + ui/ (persistence) + coding/ (img-clip) | system/ | 4 | 系统集成（terminal/image/img-clip/persistence） |
| theme/ | theme/ | 2 | 配色（不变） |
| ai/ | ai/ | 1 | AI 助手（不变，占位） |
| lang/ (非 DAP) | lang/ | 5 | 语言专用增强（crates/tsc/conjure/clangd_extensions/markdown-preview） |

**消除的"抽屉文件"**：

- `coding/coding.lua`（6 个无关插件）→ 拆分到 editing/ + completion/ + syntax/ + system/ + debug/
- `editor/editor.lua`（7 个无关插件）→ 拆分到 ui/（flash/which-key/trouble/todo-comments/grug-far/neo-tree-disable）+ git/（gitsigns）
- `ui/ui.lua`（8 个无关插件）→ 拆分到 ui/（bufferline/lualine/noice/icons/snacks）+ system/（persistence）

**DAP 职责归位**：`lang/{go,python,lua}.lua` 中的 DAP 插件移到 `debug/{dap-go,dap-python,dap-lua}.lua`，因为 DAP 是调试能力，不是语言工具链。lang/ 现只保留与语言工具链无关的增强（依赖管理/编译检查/REPL/预览）。

### FIX-LAZYVIM-CONFORM：移除 conform.nvim 的 spec.config

**Bug**：`runtime/adapters/conform.lua` 设置了 `spec.config = config_fn`，覆盖了 LazyVim 自带的 conform config 函数，导致：

- `format_on_save` 自动格式化不工作
- LazyVim 的 `<leader>cf` 格式化快捷键失效
- LSP 格式化集成丢失

**根因**：LazyVim 的 conform spec 有自己的 `config` 函数，负责：

1. 调用 `require("conform").setup(opts)`
2. 通过 `LazyVim.format` 连接 `format_on_save` autocmd
3. 提供 `<leader>cf` 快捷键和 LSP format 集成

设置 `spec.config` 会**覆盖**这个函数。

**修复**（参考 <https://www.lazyvim.org/plugins/formatting）：>

- 移除 `spec.config`，不再覆盖 LazyVim config
- 自定义 strategy formatter（如 `ruff_or_black`）改通过 `opts.formatters` 静态表注册
- `opts.formatters[strategy_name] = { format = function(self, ctx, lines) ... end }` 是 conform.nvim 的标准自定义 formatter API
- LazyVim 的 config 调用 `conform.setup(opts)` 时自动注册这些 formatter
- `format` 闭包在 build 时捕获 `strategy_fn`，在 format-time 执行（延迟求值）

### FIX-LAZYVIM-FORMAT-ON-SAVE：移除 conform.nvim 的 opts.format_on_save

**Bug**：`runtime/adapters/conform.lua` 设置了 `opts.format_on_save = { timeout_ms = 500, lsp_fallback = true }`，与 LazyVim 的 format-on-save 机制冲突。

**根因**：LazyVim 通过 `LazyVim.format`（一个 `BufWritePre` autocmd 调用 `conform.format()`）管理保存时格式化。设置 `opts.format_on_save` 会创建**第二个** format-on-save hook，导致：

- 双重格式化尝试（LazyVim hook + conform hook）
- LSP/conform 竞态条件
- 格式化行为不可预测

**修复**（参考 <https://www.lazyvim.org/plugins/formatting）：>

- 移除 `opts.format_on_save`，完全交由 LazyVim 管理
- 更新 `spec/runtime/adapters_spec.lua` 测试：从断言 `format_on_save` 存在改为断言其**不存在**（`R.assert_nil(opts.format_on_save)`）
- 测试描述更新为 `default_format_opts present (format_on_save owned by LazyVim)`

### 不变量合规率

| 阶段 | 合规率 |
|------|--------|
| 2026-06-23 P1 后 | 14/15 |
| 2026-06-26 本轮后 | 15/15 ✅ |

### 测试结果

```
suites=28  passed=1066  failed=0  skipped=0
[ltos_tests] all 1066 passed
```

（1059 + 7 POLISH-1/POLISH-2 回归用例）

### 修复文件清单（本轮 15 文件）

| 文件 | 修复 | 类别 |
| ------ | ------ | ------ |
| `lua/toolchain/rules.lua` | nix_env_rule 尊重 prefer_system=false | TEST-BUG-1 |
| `lua/runtime/adapters/lsp.lua` | opts 改静态表 | TEST-BUG-2 |
| `lua/runtime/adapters/treesitter.lua` | opts 改静态表 | TEST-BUG-2 |
| `lua/runtime/adapters/conform.lua` | opts 改静态表 + config 迁移 + 补字段 + 防御 guard | TEST-BUG-2, POLISH-3 |
| `lua/runtime/adapters/lint.lua` | opts 改静态表 + 构造期去重 | TEST-BUG-2 |
| `lua/core/compiler/ports.lua` | ensure_cache_dir 改 libuv | P1-10 |
| `lua/modules/capability/registry.lua` | get_by_type 返回浅拷贝 | P1-11 |
| `lua/runtime/pipeline.lua` | PHASE_ORDER listener 实时表 + SM 从 output_state 派生 + timings() 浅拷贝 | P2-2, P2-3, POLISH-2 |
| `lua/runtime/phase_registry.lua` | 新增 add_listener() +_notify() | P2-3 |
| `lua/runtime/commands.lua` | debug stages 从 phase registry 派生 | POLISH-1 |
| `lua/modules/capability/defaults/keybind_presets.lua` | 引用 data 模块常量 | P2-6 |
| `lua/runtime/output_validate.lua` | 新增共享验证器 | P2-1 |
| `lua/runtime/passes/{collect,normalize,canonicalize,resolve,optimize,codegen,collect_ext,cap_resolve}.lua` | 接线 output_validate | P2-1 |
| `spec/runtime/p2_regression_spec.lua` | 新增 40 个回归用例（P1/P2/P2-2/POLISH-1/POLISH-2） | 测试 |
| `scripts/ltos_tests.lua` | 注册 p2_regression_spec | 测试 |

---

## [2026-06-23] — 审计修复版（P0 + P1）

### P0 修复（5 个，1 个误报）

- **[P0-1]** cap_resolve.lua:43 — 修正 adapter.build 调用签名（恢复 P3 能力层功能）
- **[P0-2]** plugins/ai/ai.lua — 注释 LIVE spec（消除与 copilot.lua 重复）
- **[P0-3]** editor.lua — ❌ 误报（终端显示 [h 被吞）
- **[P0-4]** lifecycle.lua:55 — 修正运算符优先级（RUNNING→ERROR 恢复）
- **[P0-5]** conflict.lua — 三处修复（compose 合并 / diag 收集 / 越层迁移 + 移除 notify_warn）
- **[P0-6]** python.lua + lang_spec.lua — 测试与实现对齐

### P1 修复（5 个，1 个回退）

- **[P1-1]** collect.lua — vim.api → ports.resolve_runtime_file（INV-2/10）
- **[P1-2a]** collect_ext.lua — require-time → setup()（P6-C2）
- **[P1-2b]** pipeline.lua — ❌ 回退（测试套件需要 require-time init）
- **[P1-3]** store.lua — 原子写入（.tmp + rename）
- **[P1-4]** policy.lua — is_cacheable 环检测
- **[P1-5]** lifecycle.lua — 迁移到 domain.diagnostic

### 新增护栏

- 6 个回归测试（cap_spec.lua 内容验证）
- 5 个 layer boundary check 规则（7a-7e）
- check 脚本 pipefail 修复 + 注释过滤修复

### 不变量合规率

| 阶段 | 合规率 |
|------|--------|
| 修复前 | 11/15 |
| P0 后 | 13/15 |
| P1 后 | 14/15 |

---

## [v5.4.7] — 基线版本

- 七层架构（kernel/compiler/domain/strategy/runtime/app/cap DSL）
- 双状态机（lifecycle + pipeline）
- 8-phase 编译流水线
- 两级增量缓存（FNV-1a 内容 hash）
- DIP 抽象层
- 14 个语言模块 + 7 个能力模块
- 30 个 spec 文件，~880 个测试用例

