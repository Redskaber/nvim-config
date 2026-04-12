# LTOS · 完整重构架构组织结构

> Language Toolchain Orchestration System — nvim-config v4 架构设计文档  
> 设计原则：管道式 · 层级化 · 增量模式 · 依赖倒置 · 生命周期 · 策略管理 · 状态机 · 边界明确

---

## 一、架构总览

```
nvim-config/
├── init.lua                        # 启动入口（Layer 0 kernel 仅两行）
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
│   │   ├── strategy/               # 策略注册与执行（Strategy Pattern）
│   │   │   ├── registry.lua        # 策略注册中心（register / get / list / bootstrap）
│   │   │   ├── builtin.lua         # 内置策略实现（ruff_or_black / prettierd_or_prettier）
│   │   │   └── interface.lua       # Strategy 接口定义（applies / resolve / priority）
│   │   │
│   │   ├── mappings.lua            # LSP→Mason 包名映射 + system_tools 白名单
│   │   └── rules.lua               # 工具链解析引擎（override→system→nix→mapping→identity）
│   │
│   ├── runtime/                    # Layer 4：编译器驱动 + 后端适配器
│   │   ├── init.lua                # 编排器：模块注册、profile 解析、三层缓存协调
│   │   ├── pipeline.lua            # 五阶段流水线 + 状态机（独立实例/次运行）
│   │   │
│   │   ├── passes/                 # 编译阶段（纯 IR 变换，copy-on-write）
│   │   │   ├── collect.lua         # Phase 1：IDLE→COLLECTING，DSL→AST
│   │   │   ├── normalize.lua       # Phase 2：COLLECTING→NORMALIZING，AST→HIR
│   │   │   ├── resolve.lua         # Phase 3：NORMALIZING→RESOLVING，HIR→MIR
│   │   │   ├── optimize.lua        # Phase 4：RESOLVING→OPTIMIZING，MIR→LIR
│   │   │   └── codegen.lua         # Phase 5：OPTIMIZING→CODEGEN→DONE，LIR→SPEC
│   │   │
│   │   ├── adapters/               # 后端适配器（只读 IR，驱动 lazy.nvim 插件）
│   │   │   ├── lsp.lua             # IR.merged_lsp → nvim-lspconfig + mason-lspconfig LazySpec
│   │   │   ├── mason.lua           # IR.resolved → mason.nvim LazySpec
│   │   │   ├── treesitter.lua      # IR.all_parsers → nvim-treesitter LazySpec
│   │   │   ├── conform.lua         # IR.caps.formatters → conform.nvim LazySpec
│   │   │   └── lint.lua            # IR.caps.linters → nvim-lint LazySpec
│   │   │
│   │   └── commands.lua            # LTOS 用户命令（LtosDebug/Info/IR/Trace/Graph）
│   │
│   ├── modules/                    # Layer 5：纯 DSL 声明，零编译器知识
│   │   └── lang/                   # 语言工具链模块（每文件 return 纯表）
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
│   │   ├── autocmds.lua            # 自定义 autocmd（yank / cursor / mkdir / resize）
│   │   ├── globals.lua             # vim.g.* 全局开关（autoformat / picker / cmp）
│   │   ├── keymaps.lua             # 编辑器级键映射（无插件直接 require）
│   │   └── options.lua             # vim.opt.* 设置（fold / clipboard / scroll）
│   │
│   └── plugins/                    # Layer 5：静态插件声明（引擎占位，opts 由适配器注入）
│       ├── ui.lua                  # catppuccin / bufferline / lualine / noice / snacks
│       ├── editor.lua              # which-key / gitsigns / flash / trouble / todo-comments
│       ├── coding.lua              # mini.pairs / ts-comments / mini.ai / LuaSnip / cmp / dap
│       ├── git.lua                 # neogit / diffview
│       ├── lsp.lua                 # nvim-lspconfig 引擎声明（opts 由 ltos:lsp 注入）
│       ├── formatting.lua          # conform.nvim 引擎声明（opts 由 ltos:conform 注入）
│       ├── linting.lua             # nvim-lint 引擎声明（opts 由 ltos:lint 注入）
│       ├── terminal.lua            # toggleterm / nvim-tree
│       └── ai.lua                  # copilot / codecompanion
│
├── spec/                           # 测试套件（headless nvim --headless -l）
│   ├── core/
│   │   ├── schema_spec.lua
│   │   └── ir_spec.lua
│   ├── toolchain/
│   │   ├── mappings_spec.lua
│   │   └── strategies_spec.lua
│   └── runtime/
│       ├── pipeline_spec.lua
│       └── commands_spec.lua
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
         runtime/passes/*  runtime/adapters/*  runtime/commands
         ────────────────────────────────────────────────────
         编译器驱动层 + 后端适配器。
         passes 只调用 core.*；adapters 只读 IR，驱动 lazy.nvim API。
         adapters 禁止调用 vim.* 直接 API。

Layer 3  strategy          toolchain/strategy/*  toolchain/rules  toolchain/mappings
         ────────────────────────────────────────────────────
         策略接口：applies / resolve / priority。
         无 vim API 访问。无适配器直接调用。

Layer 2  domain IR         core/domain/schema  core/domain/capability
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
| adapters → vim API  | `runtime/adapters/*` 不得直接调用 `vim.*`                       |
| app → compiler      | `modules/lang/*` 和 `plugins/*` 不得 require `runtime/pipeline` |

---

## 三、编译器流水线（五阶段 + 状态机）

### 3.1 状态机设计

每次 `pipeline.run()` / `pipeline.debug_run()` 得到**独立状态机实例**。  
非法转换立即中止到 `ERROR`；非致命诊断累积在 IR 中，不阻断流水线。

```
IDLE ──► COLLECTING ──► NORMALIZING ──► RESOLVING ──► OPTIMIZING ──► CODEGEN ──► DONE
                                                                              ╲
                                                                               ERROR
```

转移表（adjacency map，不在表中的转移一律到 ERROR）：

| from        | allowed next       |
| ----------- | ------------------ |
| idle        | collecting         |
| collecting  | normalizing, error |
| normalizing | resolving, error   |
| resolving   | optimizing, error  |
| optimizing  | codegen, error     |
| codegen     | done, error        |

### 3.2 IR 子层（不可变，copy-on-write）

```
DSL表（modules/lang/*.lua）
         │
         ▼  Phase 1: collect
        AST  原始已验证的 CapabilitySet 快照
         │
         ▼  Phase 2: normalize
        HIR  FormatterNode.fn 已注入（策略已解析为闭包）
         │
         ▼  Phase 3: resolve
        MIR  mason vs system 决策已完成（IR.resolved）
         │
         ▼  Phase 4: optimize
        LIR  treesitter 去重、LSP 深合并（IR.merged_lsp / IR.all_parsers）
         │
         ▼  Phase 5: codegen
       SPEC  全字段就绪，驱动适配器 → LazySpec[]
```

每个 Phase 通过 `ir.with()` / `ir.clone()` 返回**新 IR**，输入 IR 永不可变。

### 3.3 CompilerContext（跨阶段携带类型）

```lua
---@class CompilerContext
---@field ir          IR                    -- 当前 IR 快照
---@field stage       string                -- 当前 SM 状态
---@field diagnostics Diagnostic[]          -- 累积诊断（不阻断）
---@field cache_key   string                -- mtime 指纹 + profile
---@field timings     table<string, number> -- 各阶段耗时（ms）
```

### 3.4 Phase 接口（core/compiler/pass.lua）

```lua
---@class Phase
---@field name         string
---@field input_state  string                   -- 进入前 SM 必须处于此状态
---@field output_state string                   -- 成功后 SM 转移到此状态
---@field run          fun(ir: IR): IR          -- 纯变换，返回新 IR，pcall 包裹
---@field validate?    fun(ir: IR): Diagnostic[] -- 前置条件检查（nil = 跳过）
```

`run()` 契约：永不变异输入 IR · 始终返回 table · pcall 封装使错误成为 Diagnostic。

### 3.5 增量缓存（三层，部分失效）

```
cache key = mtime_hash(sorted module paths) + ":" + profile

┌─────────────────────────────────────────────────────────┐
│  Spec Tier (spec_cache.json)   ← 命中则跳过全部流水线   │
├─────────────────────────────────────────────────────────┤
│  IR Tier   (ir_cache.json)     ← 命中则从 Phase 4 恢复  │
├─────────────────────────────────────────────────────────┤
│  AST Tier  (ast_cache.json)    ← 命中则从 Phase 2 恢复  │
└─────────────────────────────────────────────────────────┘

失效传播：低层失效 → 所有高层同步失效（TIER_ORDER: ast → ir → spec）
不可序列化值（FormatterNode.fn 闭包）: _no_cache=true，跳过持久化
```

---

## 四、策略管理（Strategy Pattern + 依赖倒置）

### 4.1 策略注册（重构后拆分）

```
toolchain/strategy/
├── interface.lua   -- Strategy 接口定义（契约）
├── registry.lua    -- 运行时注册中心（register / get / list / bootstrap）
└── builtin.lua     -- 内置策略实现（不依赖 registry 内部）
```

**接口定义：**

```lua
---@class Strategy
---@field name     string
---@field applies  fun(tool: string, env: EnvContext): boolean
---@field resolve  fun(bufnr: integer): string[]   -- FormatterNode.fn 签名
---@field priority integer                          -- 数字越大优先级越高
```

**工具链解析优先级链（rules.lua）：**

```
用户覆盖 (vim.g.ltos_tool_overrides)
    │
    ▼
system_tools 白名单（rustfmt/clippy/gofmt 等）
    │
    ▼
Nix 检测（env.prefer_system(tool)）
    │
    ▼
显式映射（tool_to_mason / lsp_to_mason）
    │
    ▼
Identity 回退（tool 名即 mason 包名）
```

### 4.2 格式化器策略示例

```lua
-- builtin.lua
registry.register({
  name     = "ruff_or_black",
  priority = 100,
  applies  = function(tool, env) return tool == "ruff_or_black" end,
  resolve  = function(bufnr)
    if vim.fn.executable("ruff") == 1 then return { "ruff" } end
    return { "black" }
  end,
})
```

---

## 五、后端适配器（Layer 4，只读 IR）

### 5.1 适配器接口

```lua
---@class Adapter
---@field build fun(ir: IR): LazySpec[]
```

### 5.2 适配器注册顺序（codegen.lua）

```lua
local ADAPTERS = {
  "runtime.adapters.lsp",        -- merged_lsp → lspconfig + mason-lspconfig
  "runtime.adapters.mason",      -- resolved  → mason.nvim ensure_installed
  "runtime.adapters.treesitter", -- all_parsers → nvim-treesitter
  "runtime.adapters.conform",    -- caps.formatters → conform.nvim
  "runtime.adapters.lint",       -- caps.linters   → nvim-lint
}
```

每个适配器：

- 只读取 IR 字段（无工具链逻辑）
- 工具链决策已在 Phase 3（resolve）中完成
- 通过 `pcall` 保护，单个失败不阻断其他适配器

---

## 六、生命周期（启动时序）

```
vim 启动
    │
    ├─ init.lua
    │      └─ require("core.kernel.bootstrap")   [Layer 0]
    │             netrw off，leader keys
    │
    └─ require("config.lazy")
           └─ lazy.nvim 引导
                  └─ runtime.build()             [Layer 5 → Layer 4 入口]
                         │
                         ├─ resolve_profile()    (full / minimal / nix)
                         ├─ try_cache()          [Spec Tier 命中 → 直接返回]
                         │
                         └─ pipeline.run()       [全流水线]
                                │
                                ├─ new_sm()      独立状态机实例
                                ├─ Phase 1: collect   (IDLE→COLLECTING)
                                ├─ Phase 2: normalize (COLLECTING→NORMALIZING)
                                ├─ Phase 3: resolve   (NORMALIZING→RESOLVING)
                                ├─ Phase 4: optimize  (RESOLVING→OPTIMIZING)
                                ├─ Phase 5: codegen   (OPTIMIZING→CODEGEN→DONE)
                                │      └─ 5 Adapters → LazySpec[]
                                │
                                └─ persist_cache()   [Spec Tier 写入]
                                       │
                                       ▼
                                 LazySpec[] → lazy.nvim setup()
                                       │
                                       ▼
                              VeryLazy autocmd
                                 runtime.setup_commands()   (:LtosDebug etc.)
```

**启动时间目标：**

| 路径                    | 目标                    |
| ----------------------- | ----------------------- |
| Spec 缓存命中           | < 5ms（跳过全部流水线） |
| 全流水线（10 语言模块） | < 50ms                  |
| IR 缓存命中（部分重建） | < 20ms                  |

---

## 七、领域模型（Domain IR）

### 7.1 Capability DSL

```lua
-- modules/lang/<name>.lua — 纯返回，零副作用
return {
  treesitter = string[],          -- TS 解析器名
  lsp        = { [server]: LspConfig },
  formatters = { [ft]: (string | FormatterNode)[] },
  linters    = { [ft]: string[] },
  mason      = string[],          -- 额外 mason 包（非 LSP）
}
```

### 7.2 FormatterNode（AST 节点）

```lua
---@class FormatterNode
---@field kind      "formatter"
---@field name?     string      -- 具体格式化器名
---@field strategy? string      -- 策略键（由 normalize phase 解析）
---@field fn?       fun(bufnr: integer): string[]  -- 注入闭包（不在 source 中出现）
```

`fn` 由 normalize phase 注入，绝不出现在 source DSL 中（schema 校验拒绝）。

### 7.3 IR 字段完整性约束（每阶段前置条件）

| Stage     | Required IR fields                      |
| --------- | --------------------------------------- |
| normalize | caps, meta                              |
| resolve   | caps, meta                              |
| optimize  | caps, resolved                          |
| codegen   | merged_lsp, all_parsers, caps, resolved |

---

## 八、Profile 管理

```lua
-- runtime/init.lua
local VALID_PROFILES = { minimal = true, full = true, nix = true }

-- CORE_MODULES: minimal profile 时仅加载
local CORE_MODULES = { "modules.lang.lua_lang" }

-- 全量注册表（add new langs here）
M.LANG_MODULES = {
  "modules.lang.c_cpp",
  "modules.lang.go",
  -- ...
}
```

| Profile   | 激活方式                         | 加载模块                  |
| --------- | -------------------------------- | ------------------------- |
| `full`    | 默认                             | 全部 LANG_MODULES         |
| `minimal` | `vim.g.ltos_profile = "minimal"` | 仅 CORE_MODULES           |
| `nix`     | `vim.g.ltos_profile = "nix"`     | 全部 + Nix 优先系统二进制 |

---

## 九、边界明确：重构要点清单

### 9.1 目录结构变更（v3 → v4）

| v3 路径                  | v4 路径                                                             | 原因                         |
| ------------------------ | ------------------------------------------------------------------- | ---------------------------- |
| `core/bootstrap.lua`     | `core/kernel/bootstrap.lua`                                         | 明确 Layer 0 kernel 子目录   |
| `core/env.lua`           | `core/kernel/env.lua`                                               | 同上                         |
| `core/util.lua`          | `core/kernel/util.lua`                                              | 同上                         |
| `core/ir.lua`            | `core/compiler/ir.lua`                                              | 明确 Layer 1 compiler 子目录 |
| `core/pass.lua`          | `core/compiler/pass.lua`                                            | 同上                         |
| `core/cache.lua`         | `core/compiler/cache.lua`                                           | 同上                         |
| `core/schema.lua`        | `core/domain/schema.lua`                                            | 明确 Layer 2 domain 子目录   |
| `core/capability.lua`    | `core/domain/capability.lua`                                        | 同上                         |
| `core/icons.lua`         | `core/domain/icons.lua`                                             | 全局常量归入 domain          |
| `toolchain/strategies/*` | `toolchain/strategy/registry.lua` + `builtin.lua` + `interface.lua` | 策略注册/实现/接口三分离     |

### 9.2 新增模块

| 新模块                             | 职责                                                        |
| ---------------------------------- | ----------------------------------------------------------- |
| `toolchain/strategy/interface.lua` | Strategy 类型契约（LuaLS annotations）                      |
| `toolchain/strategy/registry.lua`  | 策略注册中心（register/get/list）                           |
| `toolchain/strategy/builtin.lua`   | 内置策略实现（无注册器内部依赖）                            |
| `runtime/passes/` 目录             | 将现有 passes 从 `runtime/` 移入子目录，与 `adapters/` 并列 |

### 9.3 违规检测脚本（CI 集成）

```bash
#!/usr/bin/env bash
# check_layer_boundaries.sh
# Layer 0 kernel 不得 require Layer 1+ 模块
grep -r "require.*core\.compiler\|require.*core\.domain\|require.*toolchain\|require.*runtime" \
  lua/core/kernel/ && echo "LAYER VIOLATION: kernel imports upper layer" && exit 1

# Layer 1 compiler 不得 require Layer 2 domain
grep -r "require.*core\.domain" lua/core/compiler/ && \
  echo "LAYER VIOLATION: compiler imports domain" && exit 1

# Layer 3 toolchain 不得 require Layer 4 runtime/adapters
grep -r "require.*runtime\.adapters" lua/toolchain/ && \
  echo "LAYER VIOLATION: toolchain imports adapters" && exit 1

# modules/lang DSL 不得 require 任何 runtime
grep -r "require.*runtime" lua/modules/ && \
  echo "LAYER VIOLATION: lang modules import runtime" && exit 1

echo "Layer boundary check: PASSED"
```

---

## 十、测试结构

```
spec/
├── core/
│   ├── schema_spec.lua         -- FormatterNode 验证、sentinel 拒绝、错误恢复
│   └── ir_spec.lua             -- copy-on-write、diag 累积、stage 校验
├── toolchain/
│   ├── mappings_spec.lua       -- LSP 包名映射、system_tools 白名单
│   └── strategies_spec.lua     -- 策略注册、ruff_or_black、prettierd_or_prettier
└── runtime/
    ├── pipeline_spec.lua       -- SM 转移、各 phase IR 字段、缓存命中路径
    └── commands_spec.lua       -- :LtosDebug / :LtosInfo / :LtosGraph scratch 输出
```

运行：

```bash
nvim --headless -l spec/core/schema_spec.lua
nvim --headless -l spec/core/ir_spec.lua
nvim --headless -l spec/toolchain/mappings_spec.lua
nvim --headless -l spec/toolchain/strategies_spec.lua
nvim --headless -l spec/runtime/pipeline_spec.lua
nvim --headless -l spec/runtime/commands_spec.lua
```

---

## 十一、扩展指南

### 新增语言支持

1. 在 `lua/modules/lang/` 创建 `<lang>.lua`，返回纯 DSL 表
2. 在 `lua/runtime/init.lua` 的 `M.LANG_MODULES` 中注册模块路径
3. 运行 `:LtosGraph` 确认模块已被 collect phase 识别

### 新增格式化策略

1. 在 `lua/toolchain/strategy/builtin.lua` 实现策略
2. 在 `registry.bootstrap()` 中注册
3. 在 lang 模块的 `formatters` 中使用 `{ kind = "formatter", strategy = "<name>" }`

### 新增 IR 阶段

1. 在 `lua/runtime/passes/` 创建新的 Phase 模块
2. 实现 `Phase` 接口（name / input_state / output_state / run / validate?）
3. 在 `lua/runtime/pipeline.lua` 的 `PHASES` 列表中注册
4. 在 SM 的 `TRANSITIONS` 中添加对应转移

### 新增后端适配器

1. 在 `lua/runtime/adapters/` 创建适配器，导出 `M.build(ir): LazySpec[]`
2. 在 `lua/runtime/passes/codegen.lua` 的 `ADAPTERS` 列表中注册
3. 适配器只读 IR，不执行工具链决策

---

_LTOS v4 · 架构设计原则：管道式 · 层级化 · 增量模式 · 依赖倒置 · 生命周期 · 策略管理 · 状态机 · 边界明确_
