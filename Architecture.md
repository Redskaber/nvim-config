# LTOS · v4 架构组织结构

> Language Toolchain Orchestration System — nvim-config v4 架构设计文档  
> 设计原则：管道式 · 层级化 · 增量模式 · 依赖倒置 · 生命周期 · 策略管理 · 状态机 · 边界明确

---

## 一、架构总览

```
nvim-config/
├── init.lua                        # 启动入口（两行：kernel.bootstrap + config.lazy）
│
├── lua/
│   ├── core/                       # Layer 0–2：kernel + compiler + domain IR
│   │   ├── kernel/                 # Layer 0 — 最早初始化，零依赖
│   │   │   ├── bootstrap.lua       # netrw off、leader keys（唯一职责）
│   │   │   ├── env.lua             # 运行时环境检测（is_nix / is_ssh / has()）
│   │   │   └── util.lua            # 纯函数工具（dedup / merge / basename）
│   │   │
│   │   ├── compiler/               # Layer 1 — 编译器内核，无 vim API，无插件知识
│   │   │   ├── ir.lua              # IR 值类型 + CompilerContext + Diagnostic
│   │   │   ├── pass.lua            # Phase 接口 + run_phase() 受保护执行
│   │   │   └── cache.lua           # 三层缓存（ast / ir / spec），部分失效
│   │   │
│   │   └── domain/                 # Layer 2 — 领域 IR，不可变值对象，纯函数验证
│   │       ├── schema.lua          # DSL 验证器（FormatterNode / SchemaDiagnostic）
│   │       ├── capability.lua      # CapabilitySet 构建器（snapshot / add / reset）
│   │       └── icons.lua           # 图标单一真相源（diagnostics / git / todo）
│   │
│   ├── toolchain/                  # Layer 3：策略层，无 vim API，无适配器调用
│   │   ├── strategy/               # Strategy Pattern — 接口/注册/实现三分离
│   │   │   ├── interface.lua       # Strategy 接口定义（契约，纯类型注解）
│   │   │   ├── registry.lua        # 策略注册中心（register / get / list / bootstrap）
│   │   │   └── builtin.lua         # 内置策略实现（ruff_or_black / prettierd_or_prettier）
│   │   │
│   │   ├── mappings.lua            # LSP→Mason 包名映射 + system_tools 白名单
│   │   └── rules.lua               # 工具链解析引擎（override→system→nix→mapping→identity）
│   │
│   ├── runtime/                    # Layer 4：编译器驱动 + 后端适配器
│   │   ├── init.lua                # 编排器：模块注册、profile 解析、三层缓存协调
│   │   ├── pipeline.lua            # 五阶段流水线 + 状态机（独立实例/次运行）
│   │   ├── api.lua                 # 编辑器门面（picker / lsp / diagnostics / terminal）
│   │   ├── commands.lua            # LTOS 用户命令（LtosDebug/Info/IR/Trace/Graph）
│   │   │
│   │   ├── passes/                 # 编译阶段（纯 IR 变换，copy-on-write）
│   │   │   ├── collect.lua         # Phase 1：IDLE→COLLECTING，DSL→AST
│   │   │   ├── normalize.lua       # Phase 2：COLLECTING→NORMALIZING，AST→HIR
│   │   │   ├── resolve.lua         # Phase 3：NORMALIZING→RESOLVING，HIR→MIR
│   │   │   ├── optimize.lua        # Phase 4：RESOLVING→OPTIMIZING，MIR→LIR
│   │   │   └── codegen.lua         # Phase 5：OPTIMIZING→CODEGEN→DONE，LIR→SPEC
│   │   │
│   │   └── adapters/               # 后端适配器（只读 IR，驱动 lazy.nvim 插件）
│   │       ├── lsp.lua             # IR.merged_lsp → nvim-lspconfig + mason-lspconfig LazySpec
│   │       ├── mason.lua           # IR.resolved → mason.nvim LazySpec
│   │       ├── treesitter.lua      # IR.all_parsers → nvim-treesitter LazySpec
│   │       ├── conform.lua         # IR.caps.formatters → conform.nvim LazySpec
│   │       └── lint.lua            # IR.caps.linters → nvim-lint LazySpec
│   │
│   ├── modules/                    # Layer 5：纯 DSL 声明，零编译器知识
│   │   └── lang/
│   │       ├── c_cpp.lua
│   │       ├── go.lua
│   │       ├── lua_lang.lua
│   │       ├── markup.lua
│   │       ├── nix.lua
│   │       ├── python.lua
│   │       ├── rust.lua
│   │       ├── shell.lua
│   │       ├── typescript.lua
│   │       └── zig.lua
│   │
│   ├── config/                     # Layer 5：Neovim 运行时配置（LazyVim 扩展点）
│   │   ├── lazy.lua                # lazy.nvim 引导 + runtime.build() 调用
│   │   ├── autocmds.lua            # 自定义 autocmd
│   │   ├── globals.lua             # vim.g.* 全局开关（autoformat / picker / cmp）
│   │   ├── icons.lua               # re-exports core/domain/icons.lua（app 层入口）
│   │   ├── keymaps.lua             # 编辑器级键映射（仅通过 runtime.api）
│   │   └── options.lua             # vim.opt.* 设置（fold / clipboard / scroll）
│   │
│   └── plugins/                    # Layer 5：静态插件声明（引擎占位，opts 由适配器注入）
│       ├── ai/ai.lua
│       ├── coding/                 # coding.lua · comments.lua · pairs.lua · snip.lua
│       ├── editor/                 # editor.lua · cursor.lua
│       ├── formatting/formatting.lua
│       ├── linting/linting.lua
│       ├── lsp/lsp.lua
│       ├── sys/                    # git.lua · terminal.lua
│       ├── theme/theme.lua
│       ├── treesitter/treesitter.lua
│       └── ui/                     # ui.lua · snacks.lua
│
├── spec/                           # 测试套件（nvim --headless -l）
│   ├── core/
│   │   ├── schema_spec.lua
│   │   ├── ir_spec.lua
│   │   └── pass_spec.lua
│   ├── toolchain/
│   │   ├── mappings_spec.lua
│   │   └── strategies_spec.lua
│   └── runtime/
│       ├── pipeline_spec.lua
│       └── commands_spec.lua
│
├── scripts/
│   └── check_layer_boundaries.sh  # 层边界违规检测脚本（CI 集成）
│
└── README.md
```

---

## 二、六层架构（严格单向依赖）

```
Layer 5  app / config      modules/lang/*  plugins/*  config/*
         ────────────────────────────────────────────────────
         纯 DSL 声明 / LazyVim 配置扩展点。零编译器知识。
         只允许向下依赖 Layer 4（runtime.build）。

Layer 4  runtime           runtime/init  runtime/pipeline
         runtime/passes/*  runtime/adapters/*  runtime/commands  runtime/api
         ────────────────────────────────────────────────────
         编译器驱动层 + 后端适配器。
         passes 只调用 core.*；adapters 只读 IR，驱动 lazy.nvim API。

Layer 3  strategy          toolchain/strategy/*  toolchain/rules  toolchain/mappings
         ────────────────────────────────────────────────────
         策略接口：applies / resolve / priority。
         无 vim API 访问。无适配器直接调用。

Layer 2  domain IR         core/domain/schema  core/domain/capability  core/domain/icons
         ────────────────────────────────────────────────────
         不可变 CapabilitySet。纯函数验证。
         无运行时状态。无副作用。

Layer 1  compiler          core/compiler/ir  core/compiler/pass  core/compiler/cache
         ────────────────────────────────────────────────────
         CompilerContext · Phase 接口 · 三层缓存。
         无 vim API。无插件知识。

Layer 0  kernel            core/kernel/bootstrap  core/kernel/env  core/kernel/util
         ────────────────────────────────────────────────────
         最早初始化。无任何上层依赖。
```

**层边界契约（违反即为架构违规）：**

| 边界                | 规则                                                            |
| ------------------- | --------------------------------------------------------------- |
| kernel → compiler   | `core/kernel/*` 不得 require `core/compiler/*`                  |
| compiler → domain   | `core/compiler/*` 不得 require `core/domain/*`                  |
| domain → toolchain  | `core/domain/*` 不得 require `toolchain/*`                      |
| strategy → adapters | `toolchain/*` 不得 require `runtime/adapters/*`                 |
| adapters → vim API  | `runtime/adapters/*` 不得直接调用编辑器 API                     |
| app → compiler      | `modules/lang/*` 和 `plugins/*` 不得 require `runtime/pipeline` |

---

## 三、编译器流水线（五阶段 + 状态机）

### 3.1 状态机设计

每次 `pipeline.run()` / `pipeline.debug_run()` 得到**独立状态机实例**（工厂函数 `new_sm()`）。

```
IDLE → COLLECTING → NORMALIZING → RESOLVING → OPTIMIZING → CODEGEN → DONE
                                                                    ↘ ERROR
```

**状态转换表（完整）：**

| 当前状态    | 允许转换到              | 触发条件                        |
| ----------- | ----------------------- | ------------------------------- |
| idle        | collecting              | `pipeline.run()` 开始           |
| collecting  | normalizing, error      | collect phase 完成 / 失败       |
| normalizing | resolving, error        | normalize phase 完成 / 失败     |
| resolving   | optimizing, error       | resolve phase 完成 / 失败       |
| optimizing  | codegen, error          | optimize phase 完成 / 失败      |
| codegen     | done, error             | codegen build 完成 / 失败       |
| done        | —                       | 终态                            |
| error       | —                       | 终态（非法 transition 也到此）  |

### 3.2 IR 子层（不可变，copy-on-write）

```
DSL 表（modules/lang/*.lua）
    │
    ▼  Phase 1: collect      IDLE → COLLECTING
   AST  原始已验证的 CapabilitySet 快照
    │
    ▼  Phase 2: normalize    COLLECTING → NORMALIZING
   HIR  FormatterNode.fn 已注入（策略已解析为闭包）
    │
    ▼  Phase 3: resolve      NORMALIZING → RESOLVING
   MIR  mason vs system 决策已完成（IR.resolved）
    │
    ▼  Phase 4: optimize     RESOLVING → OPTIMIZING
   LIR  treesitter 去重、LSP 深合并（IR.merged_lsp / IR.all_parsers）
    │
    ▼  Phase 5: codegen      OPTIMIZING → CODEGEN → DONE
  SPEC  全字段就绪，驱动适配器 → LazySpec[]
```

**IR schema 表（各阶段字段）：**

| 字段           | 类型                        | 首次出现 | 说明                              |
| -------------- | --------------------------- | -------- | --------------------------------- |
| `stage`        | `"AST"\|"HIR"\|"MIR"\|"LIR"\|"SPEC"` | AST | 当前 IR 子层标识         |
| `caps`         | `table<string, Capability>` | AST      | 验证后的能力快照                  |
| `diagnostics`  | `Diagnostic[]`              | AST      | 累积诊断（不中断流水线）          |
| `meta`         | `IRMeta`                    | AST      | 构建元数据（模块列表、时间戳）    |
| `profile`      | `string`                    | AST      | 构建 profile（full/minimal/nix）  |
| `resolved`     | `IRResolved`                | MIR      | mason/system 决策结果             |
| `merged_lsp`   | `table<string, table>`      | LIR      | 去重合并后的 LSP 配置             |
| `all_parsers`  | `string[]`                  | LIR      | 去重后的 treesitter parser 列表   |
| `_timings`     | `table<string, number>`     | debug    | debug_run 专用，phase 耗时        |

### 3.3 CompilerContext

```lua
---@class CompilerContext
---@field ir          IR
---@field stage       string
---@field diagnostics Diagnostic[]
---@field cache_key   string
---@field timings     table<string, number>
---@field run_id      string   unique per run() call
```

### 3.4 Phase 接口（core/compiler/pass.lua）

```lua
---@class Phase
---@field name         string
---@field input_state  string
---@field output_state string
---@field run          fun(ir: IR): IR
---@field validate?    fun(ir: IR): Diagnostic[]
```

**Phase contract 表：**

| Phase      | input_state | output_state | IR in  | IR out | 职责                                    |
| ---------- | ----------- | ------------ | ------ | ------ | --------------------------------------- |
| collect    | idle        | collecting   | —      | AST    | 加载 DSL → 验证 → CapabilitySet 快照    |
| normalize  | collecting  | normalizing  | AST    | HIR    | FormatterNode.strategy → .fn 注入       |
| resolve    | normalizing | resolving    | HIR    | MIR    | mason/system 决策 → IR.resolved         |
| optimize   | resolving   | optimizing   | MIR    | LIR    | parser 去重 + LSP 深合并                |
| codegen    | optimizing  | codegen      | LIR    | SPEC   | 驱动 adapters → LazySpec[]              |

### 3.5 IR 阶段字段契约

| 阶段进入前 | 必须存在的字段                                  |
| ---------- | ----------------------------------------------- |
| normalize  | `caps`, `meta`                                  |
| resolve    | `caps`, `meta`                                  |
| optimize   | `caps`, `resolved`                              |
| codegen    | `caps`, `resolved`, `merged_lsp`, `all_parsers` |

---

## 四、三层增量缓存

```
cache key = FNV1a(sorted file content hashes) + ":" + profile + ":v4"

Spec Tier (spec_cache.json)   ← 命中则跳过全部流水线
IR Tier   (ir_cache.json)     ← 命中则从 Phase 4 恢复
AST Tier  (ast_cache.json)    ← 命中则从 Phase 2 恢复

失效传播：低层失效 → 所有高层同步失效
不可序列化值（FormatterNode.fn）: metatable.__ltos_cacheable=false，跳过持久化
```

**缓存子模块职责分离：**

| 模块                        | 职责                                    |
| --------------------------- | --------------------------------------- |
| `cache/key.lua`             | 键计算（FNV-1a 内容 hash，纯函数）      |
| `cache/store.lua`           | JSON I/O（唯一 IO 层）                  |
| `cache/policy.lua`          | 失效传播 + 命中统计 + 可序列化检查      |
| `cache.lua`                 | 门面（facade），向后兼容 API            |

---

## 五、策略管理（Strategy Pattern + 依赖倒置）

```
toolchain/strategy/
├── interface.lua   -- Strategy 接口定义（契约，纯类型注解）
├── registry.lua    -- 运行时注册中心（register / get / list / bootstrap / lock）
└── builtin.lua     -- 内置策略实现（不依赖 registry 内部）
```

工具链解析优先级链（rules.lua）：

```
用户覆盖 (vim.g.ltos_tool_overrides / mappings.overrides)
    → system_tools 白名单（rustfmt / gofmt / zigfmt 等）
    → Nix 检测（env.is_nix and env.has(tool)）
    → 显式映射（tool_to_mason / lsp_to_mason）
    → Identity 回退（tool 名即 mason 包名）
```

---

## 六、生命周期（启动时序）

```
vim 启动
  → init.lua
       → require("core.kernel.bootstrap")   [Layer 0]
       → require("config.lazy")
            → lazy.nvim 引导
                 → runtime.build()          [Layer 5 → Layer 4 入口]
                      → resolve_profile()
                      → try_cache()         [Spec Tier 命中 → 直接返回]
                      → pipeline.run()      [全流水线]
                           → new_sm()       独立状态机实例
                           → Phase 1-5
                           → 5 Adapters → LazySpec[]
                      → persist_cache()
                 → lazy.setup(specs)
                 → VeryLazy autocmd (once)
                      → runtime.setup_commands()   [deferred — keeps startup clean]
```

启动时间目标：Spec 缓存命中 < 5ms，全流水线 < 50ms，IR 缓存命中 < 20ms。

---

## 七、v3 → v4 路径映射

| v3 路径                               | v4 路径                                                   |
| ------------------------------------- | --------------------------------------------------------- |
| `core/bootstrap.lua`                  | `core/kernel/bootstrap.lua`                               |
| `core/env.lua`                        | `core/kernel/env.lua`                                     |
| `core/util.lua`                       | `core/kernel/util.lua`                                    |
| `core/ir.lua`                         | `core/compiler/ir.lua`                                    |
| `core/pass.lua`                       | `core/compiler/pass.lua`                                  |
| `core/cache.lua`                      | `core/compiler/cache.lua`                                 |
| `core/schema.lua`                     | `core/domain/schema.lua`                                  |
| `core/capability.lua`                 | `core/domain/capability.lua`                              |
| `core/icons.lua`                      | `core/domain/icons.lua` + `config/icons.lua`（re-export） |
| `toolchain/strategies/init.lua`       | `toolchain/strategy/registry.lua`                         |
| `toolchain/strategies/formatters.lua` | `toolchain/strategy/builtin.lua`                          |
| _(新增)_                              | `toolchain/strategy/interface.lua`                        |

---

## 八、层边界违规检测

```bash
bash scripts/check_layer_boundaries.sh
# Layer boundary check: PASSED
```

_LTOS v4 · 架构设计原则：管道式 · 层级化 · 增量模式 · 依赖倒置 · 生命周期 · 策略管理 · 状态机 · 边界明确_
