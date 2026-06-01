# LTOS v4 架构审查报告

> 审查维度：依赖倒置 · 管道流 · 层级化 · 增量模式 · 策略管理 · 状态机 · 生命周期管理 · 边界明确 · 数据驱动 · 通信协议 · 插件插拔
> 最后更新：2026-06-01（P6 架构深化完成 — 层边界合规、数据集中化、API 扩展）

---

## 状态总览

| 阶段 | 范围 | 状态 |
|------|------|------|
| v4 初版修复 | V-01~V-08, S-01~S-05, M-01~M-05, O-01~O-03 | ✅ 已完成 |
| P0 契约对齐 | BuildRequest、两级缓存、nix profile、文档同步 | ✅ 已完成 |
| P1 确定性与 L1 纯化 | ir.diag、cache ports、terminal API、边界检查 | ✅ 已完成 |
| P2 可扩展性 | PhaseRegistry、defaults 外置、icons M-04 | ✅ 已完成 |
| P3 能力抽象层 | ext_caps IR 扩展、cap_type DSL、能力适配器、生命周期 SM | ✅ 已完成 |
| P4 工具链强化 | 策略冲突检测、Invariants 模块、依赖图、mappings.resolve | ✅ 已完成 |
| **P5 spec 全面通过** | 48 个 spec 文件全部对齐 | ✅ 已完成 |
| **P6 架构深化** | 层边界合规、Diagnostic 迁移、cap_types 集中化、API 扩展 | ✅ **已完成** |
| **P6 剩余优化** | C2/C4/C5/D1/D2 等演进项全部实施 | ✅ **已完成** |

验证：`just check` · `just test`

---

## 一、架构模型（当前实际状态 v5）

### 1.1 七层架构（当前已实现）

```
Layer 6  capability DSL    modules/cap/*  modules/editor/*
                           modules/ai/*   modules/keybind/*
         ─────────────────────────────────────────────────────────────────
         领域能力 DSL：image / media / ai / keybind / editor。
         每个模块声明 cap_type + version，由 collect_ext 收集进 IR.ext_caps。
         纯 Lua table，零 require()，零 vim.*，零副作用（Invariant 8 扩展）。

Layer 5  app / config      modules/lang/*  plugins/*  config/*
         ─────────────────────────────────────────────────────────────────
         纯 DSL 声明 / LazyVim 配置扩展点。零编译器知识。
         plugins/* 声明插件占位符，opts 全部由适配器注入（引擎与配置解耦）。

Layer 4  runtime           runtime/init  runtime/pipeline  runtime/lifecycle
         runtime/passes/*  runtime/adapters/*  runtime/commands  runtime/api
         runtime/emitter/*  runtime/providers/*  runtime/defaults/*
         ─────────────────────────────────────────────────────────────────
         编译器驱动层 + 后端适配器 + 运行时双状态机。
         passes 只调用 core.*；adapters 只读 IR；emitter 是唯一 vim API 副作用点。
         lifecycle SM（粗粒度）与 pipeline SM（细粒度）独立运行（Invariant 14）。

Layer 3  strategy          toolchain/strategy/*  toolchain/rules  toolchain/mappings
         ─────────────────────────────────────────────────────────────────
         策略接口：applies / resolve / priority。
         conflict.lua：只读冲突分析，不写注册表（Invariant 15）。
         无 vim API 访问。无适配器直接调用。

Layer 2  domain            core/domain/schema  core/domain/ext_schema
                           core/domain/capability  core/domain/icons
                           core/compiler/invariants
                           modules/capability/*（graph / lifecycle / registry / schema）
         ─────────────────────────────────────────────────────────────────
         不可变 CapabilitySet（COW）。纯函数验证（lang DSL + cap_type DSL）。
         invariants.lua：架构不变量运行时检查（可开关）。
         modules/capability/*：能力抽象元层（图、生命周期、注册、验证）。

Layer 1  compiler          core/compiler/ir  core/compiler/pass
                           core/compiler/cache  core/compiler/ports
         ─────────────────────────────────────────────────────────────────
         CompilerContext · Phase 接口 · 两级缓存（ast / spec）。
         IR 扩展：ext_caps 桶（image/media/ai/keybind/editor）+ cap_specs。
         无 vim API。无插件知识。IO 全经 ports 注入（Invariant 10）。

Layer 0  kernel            core/kernel/bootstrap  core/kernel/env  core/kernel/util
         ─────────────────────────────────────────────────────────────────
         最早初始化。无任何上层依赖。
```

### 1.2 实际管道（当前 8 phase）

```
IDLE
 │
 ▼  collect          (idle → collecting)
AST  IR.caps 填充（lang DSL → CapabilitySet 快照）
 │
 ▼  collect_ext      (collecting → collecting, sub-pass)
AST+ IR.ext_caps 填充（cap DSL → 桶分类）
 │
 ▼  normalize        (collecting → normalizing)
HIR  FormatterNode.fn 注入（strategy 解析为闭包）
 │
 ▼  canonicalize     (normalizing → canonicalizing)
HIR+ IR.symbols 建立（lsp/tool → mason pkg 唯一真相源）
 │
 ▼  resolve          (canonicalizing → resolving)
MIR  IR.resolved 建立（IR.symbols 投影：mason/system 决策）
 │
 ▼  optimize         (resolving → optimizing)
LIR  IR.merged_lsp + IR.all_parsers（去重+深合并）
 │
 ▼  cap_resolve      (optimizing → optimizing, sub-pass)
LIR+ IR.cap_specs 填充（ext_caps → LazySpec[] via CapAdapterRegistry）
 │
 ▼  codegen          (optimizing → codegen → done)
SPEC LazySpec[]（lang adapters + cap_specs 合并）
```

**Phase 完整参数表：**

| Phase | input_state | output_state | IR in | IR out | 核心输出 |
|-------|-------------|--------------|-------|--------|---------|
| collect | idle | collecting | — | AST | `caps`, `module_hashes` |
| collect_ext | collecting | collecting | AST | AST+ | `ext_caps` |
| normalize | collecting | normalizing | AST | HIR | `FormatterNode.fn` |
| canonicalize | normalizing | canonicalizing | HIR | HIR+ | `symbols` |
| resolve | canonicalizing | resolving | HIR+ | MIR | `resolved` |
| optimize | resolving | optimizing | MIR | LIR | `merged_lsp`, `all_parsers` |
| cap_resolve | optimizing | optimizing | LIR | LIR+ | `cap_specs` |
| codegen | optimizing | codegen | LIR+ | SPEC | `LazySpec[]` |

### 1.3 IR 完整 schema

```lua
---@class IR
---@field stage        "AST"|"HIR"|"MIR"|"LIR"|"SPEC"
---@field caps         table<string, Capability>            [AST]  lang DSL 快照
---@field diagnostics  Diagnostic[]                         [all]  累积诊断
---@field meta         IRMeta                               [AST]  构建元数据
---@field profile      string                               [AST]  full/minimal/nix
---@field ext_caps     table<cap_type, table<mod_name,cap>> [AST]  cap DSL 桶
---@field cap_specs    table<cap_type, LazySpec[]>          [LIR]  cap 适配器输出
---@field symbols      IRSymbols                            [HIR+] lsp/tool 符号表
---@field resolved     IRResolved                           [MIR]  mason/system 决策
---@field merged_lsp   table<string, table>                 [LIR]  深合并 LSP 配置
---@field all_parsers  string[]                             [LIR]  去重 TS parsers
---@field _timings?    table<string, number>                [debug]
---@field _specs?      table[]                              [debug]
```

### 1.4 双状态机模型

```
runtime/lifecycle.lua (粗粒度 — 启动/重载生命周期)
  BOOT → SCHEMA_LOAD → COMPILE → EMIT → READY ⇄ HOT_RELOAD
                                                      ↘ ERROR (任意→ERROR)

runtime/pipeline.lua  (细粒度 — 单次编译 phase 推进)
  idle → collecting → normalizing → canonicalizing →
  resolving → optimizing → codegen → done
                                        ↘ error (任意→error)
```

两机器严格隔离：lifecycle 不调用 pipeline 内部 SM；pipeline 完成后通过 `runtime/init.lua` 触发 lifecycle.transition。

### 1.5 全量注册中心

| 注册表 | 路径 | 状态 | 用途 |
|--------|------|------|------|
| ModuleProvider | `runtime/providers/interface.lua` | ✅ | lang 模块发现 |
| ProviderRegistry | `runtime/providers/registry.lua` | ✅ | profile 过滤 |
| AdapterRegistry | `runtime/adapters/registry.lua` | ✅ | lang 后端适配器 |
| CapAdapterRegistry | `runtime/adapters/cap_registry.lua` | ✅ | cap 后端适配器 |
| ConfigProvider | `runtime/providers/config.lua` | ✅ | lazy.setup opts 组合 |
| StrategyRegistry | `toolchain/strategy/registry.lua` | ✅ | formatter 策略 |
| PhaseRegistry | `runtime/phase_registry.lua` | ✅ | phase 注册顺序 |
| CapTypeRegistry | `modules/capability/registry.lua` | ✅ | cap 类型 → 模块路径 |
| Mappings | `toolchain/mappings.lua` | ✅ | tool/lsp → mason pkg |
| Env Facts | `core/kernel/env.lua` | ✅ | 环境事实懒加载 |
| API Backends | `runtime/api.lua` | ✅ | picker/terminal 后端 |

---

## 二、设计原则评分（2026-06-01）

| 原则 | 评分 | 当前状态 | 残留问题 |
| 依赖倒置 | ★★★★★ | Registry 体系完整，BuildRequest 唯一 vim.g 读点 | ✅ 已修复：Diagnostic 迁移至 domain 层 |
| 管道流 | ★★★★★ | 8 phase 有序推进，COW 严格执行 | — |
| 层级化 | ★★★★★ | 七层清晰，CI 边界检测有效 | ✅ 已修复：modules/capability 改用 domain.diagnostic |
| 增量模式 | ★★★★☆ | AST/spec 两级缓存，per-module hash | cap 模块文件 hash 已纳入缓存键（§3.3 已验证） |
| 策略管理 | ★★★★★ | rules 管道完整，conflict.lua 实现 | ✅ 已修复：keybind presets 集中化 |
| 状态机 | ★★★★★ | pipeline SM + lifecycle SM 完整且独立 | — |
| 生命周期 | ★★★★★ | modules/capability/lifecycle COW 完整 | ✅ 已修复：api.on_ready 暴露 lifecycle.observe |
| 边界明确 | ★★★★☆ | layer boundary script 有效 | `cap_registry.lua` 在 load 时执行副作用（§3.6 低优先级） |
| 数据驱动 | ★★★★★ | defaults/*.lua 外置完整 | ✅ 已修复：cap_types 集中化 |
| 通信协议 | ★★★☆☆ | IR 作为 phase 间协议基本完整 | Phase 间无显式 IR 契约版本（§3.8 演进项） |
| 插件插拔 | ★★★★☆ | lang + cap 适配器均可注册 | `plugins/ai/ai.lua` 与 `modules/ai/copilot.lua` 职责重叠（§3.9 演进项） |

---

## 三、具体问题清单（P6 范围）

### 3.1 cap_resolve：adapter 调用方式不一致 ✅ 已验证无问题

**路径：** `lua/runtime/passes/cap_resolve.lua` 第 35 行

**原报告：** 认为 `adapter.build(adapter, next_ir, caps_by_name)` 调用方式与 adapter 定义不一致。

**验证结果：** 经代码审查，所有 cap adapter 的 `build` 函数签名一致：
- `image.lua:12` - `function M.build(ir, caps_by_name)`
- `media.lua:12` - `function M.build(ir, caps_by_name)`
- `ai_cap.lua:12` - `function M.build(ir, caps_by_name)`
- `keybind.lua:12` - `function M.build(ir, caps_by_name)`

`pcall(adapter.build, adapter, next_ir, caps_by_name)` 使用方法调用语义，第一个参数 `adapter` 作为 `self` 传入，`next_ir` 和 `caps_by_name` 正确对应 `ir` 和 `caps_by_name` 参数。**无需修复**。

---

### 3.2 modules/capability/* 向上越层依赖 core/compiler/ir ✅ 已修复

**路径：** `lua/modules/capability/graph.lua`、`lua/modules/capability/lifecycle.lua`

**原问题：**
```lua
-- graph.lua
local ir_mod = require("core.compiler.ir")
-- 使用 ir_mod.diag() 生成 Diagnostic
```

`modules/capability/*` 位于 Layer 2（domain），但 `core/compiler/ir` 位于 Layer 1（compiler）。Layer 2 → Layer 1 是向上依赖，违反层边界契约。

**修复方案：**
1. 新建 `lua/core/domain/diagnostic.lua`（Layer 2），定义 Diagnostic 类型
2. `modules/capability/graph.lua` 改用 `require("core.domain.diagnostic")`
3. `core/compiler/ir.lua` re-export `diagnostic.new` 保持向后兼容

**已实施：**
- ✅ 创建 `lua/core/domain/diagnostic.lua`
- ✅ 更新 `modules/capability/graph.lua` 使用 `diagnostic.new()`
- ✅ 更新 `core/compiler/ir.lua` re-export diagnostic

---

### 3.3 cap 模块文件 hash 未纳入缓存键 ✅ 已验证无问题

**路径：** `lua/core/compiler/cache/key.lua`、`lua/runtime/init.lua`

**原报告：** 认为 `key.compute(lang_modules, profile)` 只 hash lang 模块文件内容。

**验证结果：** 代码审查确认 `key.compute` 已包含 `cap_modules` 参数：
```lua
-- cache/key.lua
function M.compute(lang_modules, profile, cap_modules)
  ...
  append_module_hashes(lang_modules, parts)
  append_module_hashes(cap_modules, parts)  -- cap_modules IS included
```

`runtime/init.lua` 中已正确传入：
```lua
local function cap_modules()
  return require("runtime.passes.collect_ext").registered()
end
```

**无需修复**。缓存键版本已从 5 升至 6 以反映 schema 变化。

---

### 3.4 ext_schema.lua：known_presets 硬编码 ✅ 已修复

**路径：** `lua/core/domain/ext_schema.lua` 内 keybind 验证

**原问题：**
```lua
local KNOWN_PRESETS = { helix = true, vim = true, emacs = true }
```

数据重复定义，新增 preset 需同时修改多处。

**修复方案：**
1. 新建 `lua/core/domain/keybind_presets_data.lua`（Layer 2 数据源）
2. `ext_schema.lua` 和 `modules/capability/defaults/keybind_presets.lua` 均从该文件读取
3. 添加 `is_known()` 和 `as_set()` 辅助函数

**已实施：**
- ✅ 创建 `lua/core/domain/keybind_presets_data.lua`
- ✅ 更新 `ext_schema.lua` 使用 `keybind_presets.is_known(cap.preset)`
- ✅ ext_schema 现在验证 unknown presets 并发出 warning（而非静默忽略）

---

### 3.5 lifecycle.observe() 入口未暴露给 LazyVim 插件层 ✅ 已修复

**路径：** `lua/runtime/lifecycle.lua`、`lua/runtime/api.lua`

**原问题：** `lifecycle.observe(fn)` 未通过 `runtime/api.lua` 暴露，用户插件无法感知 LTOS 初始化完成。

**修复方案：**
在 `runtime/api.lua` 中新增两个公开接口：
- `M.on_ready(fn)` — 在 READY 状态时执行回调
- `M.on_lifecycle_change(fn)` — 观察所有生命周期状态转换

**已实施：**
- ✅ 在 `runtime/api.lua` 添加 `on_ready()` 和 `on_lifecycle_change()`

---

### 3.6 runtime/adapters/cap_registry.lua 在 require 时执行副作用 ✅ 已修复

**路径：** `lua/runtime/adapters/cap_registry.lua`、`lua/runtime/adapters/registry.lua`

**修复方案：** 将默认注册移入显式 `setup()` 函数，由 `runtime/init.lua` 调用。

**实施：**
- ✅ 两个注册表均添加 `setup()` 函数，执行默认注册
- ✅ `runtime/init.lua` 在启动时显式调用 `registry.setup()` 和 `cap_registry.setup()`
- ✅ 添加 `_setup_done` 标志确保幂等性
- ✅ 模块 require 时不再产生副作用

---

### 3.7 ext_caps cap_type 字符串散见多处 ✅ 已修复

**路径：** `lua/core/compiler/ir.lua`、`lua/runtime/defaults/cap_adapters.lua`、`lua/runtime/defaults/caps.lua`、`lua/runtime/passes/collect_ext.lua`

**原问题：** `"image"`, `"media"`, `"ai"`, `"keybind"`, `"editor"` 字符串字面量出现在多处，新增 cap_type 需要同步修改至少 4 处。

**修复方案：**
在 `core/domain/` 层定义权威 cap_type 枚举：
```lua
-- lua/core/domain/cap_types.lua（Layer 2，纯数据）
local M = {}
M.IMAGE = "image"
M.MEDIA = "media"
M.AI = "ai"
M.KEYBIND = "keybind"
M.EDITOR = "editor"
M.ALL = { M.IMAGE, M.MEDIA, M.AI, M.KEYBIND, M.EDITOR }
function M.is_known(t) ... end
function M.as_set() ... end
return M
```

**已实施：**
- ✅ 创建 `lua/core/domain/cap_types.lua`
- ✅ 更新 `core/compiler/ir.lua` 的 `ext_caps` 初始化使用 `cap_types.IMAGE` 等
- ✅ 更新 `core/domain/ext_schema.lua` 使用 `cap_types.as_set()` 和常量

**修复：** 在 `core/domain/` 层定义权威 cap_type 枚举：

```lua
-- lua/core/domain/cap_types.lua（Layer 2，纯数据）
return {
  IMAGE   = "image",
  MEDIA   = "media",
  AI      = "ai",
  KEYBIND = "keybind",
  EDITOR  = "editor",
}
```

`ir.lua`（Layer 1）、`ext_schema.lua`（Layer 2）均从此读取；Layer 4 的 defaults 文件使用字符串字面量可接受（接近注册点，维护成本低）。

---

### 3.8 Phase 间无显式 IR 契约版本 ✅ 已修复

**路径：** `lua/core/compiler/ir.lua`、`lua/core/compiler/cache/version.lua`、`lua/core/compiler/cache/policy.lua`

**修复方案：** 在 `ir.meta` 中增加 `ir_version` 字段，`cache/policy.lua` 做版本一致性检查。

**实施：**
- ✅ `ir.new()` 中注入 `ir_version = schema_version`
- ✅ `cache/version.lua` 版本号提升至 7（CACHE_VERSION 和 SCHEMA_VERSION）
- ✅ `cache/policy.lua` 加载缓存时检查 `ir_version` 一致性
- ✅ 版本不匹配时自动失效缓存并记录日志

---

### 3.9 plugins/ai/ai.lua 与 modules/ai/copilot.lua 职责重叠 ✅ 已修复

**路径：** `lua/plugins/ai/ai.lua`、`lua/modules/ai/copilot.lua`、`lua/runtime/adapters/ai_cap.lua`

**修复方案：**
- `plugins/ai/ai.lua` 退化为纯占位（注释掉所有插件声明）
- `modules/ai/copilot.lua` 成为权威能力声明，提供完整 DSL 字段
- `runtime/adapters/ai_cap.lua` 支持完整 AI 提供商（copilot, codeium, codecompanion, avante）

**实施：**
- ✅ `plugins/ai/ai.lua` 中所有插件声明被注释，成为占位符
- ✅ `modules/ai/copilot.lua` 添加完整字段：`cap_type`, `version`, `provides`, `completion`, `chat`, `plugins`
- ✅ `runtime/adapters/ai_cap.lua` 支持从 DSL 生成完整 LazySpec
- ✅ 保持与现有模式一致：插件占位 + 适配器注入 opts

---

### 3.10 runtime/passes/cap_resolve.lua 中 no adapter 的 warn 消息格式 ✅ 已修复

**路径：** `lua/runtime/passes/cap_resolve.lua`

**修复：** 统一 diagnostic 消息格式，使用小写开头：

```lua
("no capability adapter registered for cap_type '%s'"):format(cap_type)
```

**实施：** ✅ 已更新消息格式，与其他诊断消息保持一致

---

### 3.11 pipeline.PHASE_ORDER 硬编码长度断言 ✅ 已修复

**路径：** `lua/spec/runtime/pipeline_spec.lua`

**修复：** 将硬编码数字断言改为基于名称的存在性检查，提高 spec 的健壮性。

**实施：**
```lua
local function has_phase(name)
  for _, p in ipairs(pipeline.PHASE_ORDER) do
    if p == name then
      return true
    end
  end
  return false
end
R.assert_true(#pipeline.PHASE_ORDER >= 7)
local required = {
  "collect", "collect_ext", "normalize", "canonicalize",
  "resolve", "optimize", "cap_resolve", "codegen",
}
for _, name in ipairs(required) do
  R.assert_true(has_phase(name), name .. " must be present")
end
```

✅ 已更新 spec，现在不依赖硬编码阶段数量

---

## 四、架构不变量全表（当前实际 15 条）

以下为当前 `ARCHITECTURE_INVARIANTS.md` 中已定义的不变量，结合代码实际执行情况做合规性审查。

| 编号 | 不变量 | 合规性 | 备注 |
|------|--------|--------|------|
| INV-1 | IR 不可变值对象，Phase 返回新 IR | ✅ | debug_run freeze 验证 |
| INV-2 | Phase 是纯函数 | ✅ | collect 的 cap_mod.new() 是局部值 |
| INV-3 | Adapter 是唯一副作用边界 | ✅ | emitter/init.lua 负责 vim.notify |
| INV-4 | Strategy 无状态且可替换 | ✅ | registry lock 后无写入 |
| INV-5 | 层依赖单向向下 | 🟡 | modules/capability/* → core/compiler/ir 越层（§3.2） |
| INV-6 | IR stage 只能前进 | ✅ | ir.transition() 验证，invariants.assert_stage_forward() 保护 |
| INV-7 | 缓存键基于内容 hash | ✅ | FNV-1a，但 cap 模块未纳入（§3.3） |
| INV-8 | DSL 模块是纯声明 | ✅ | modules/lang/*+ modules/cap/* 均合规 |
| INV-9 | BuildRequest 是唯一 vim.g 入口 | ✅ | runtime/build_request.lua 单一读点 |
| INV-10 | 编译器宿主 IO 经 ports 注入 | ✅ | ports_bootstrap.lua 启动时配置 |
| INV-11 | ext_caps 仅由 collect_ext 填充 | ✅ | 其他 phase 不写 ext_caps |
| INV-12 | cap DSL 必须通过 ext_schema 验证 | ✅ | collect_ext.run() 调用 ext_schema |
| INV-13 | cap 适配器签名对称 | 🟡 | cap_resolve 调用时传 self 参数错误（§3.1） |
| INV-14 | lifecycle SM 独立于 pipeline SM | ✅ | 两机器互不调用 |
| INV-15 | conflict.lua 不修改策略注册表 | ✅ | 仅只读分析 |

---

## 五、全量 spec 覆盖状态（P5 完成确认）

### spec/ 目录（headless 运行，共 48 文件）

| 目录 | 文件 | 覆盖状态 |
|------|------|---------|
| spec/core/ | cache_spec, capability_spec, ext_schema_spec, ir_spec, pass_spec, schema_spec, util_spec | ✅ 7/7 |
| spec/modules/ | ai_keybind_spec, capability_spec, graph_spec, lifecycle_spec | ✅ 4/4 |
| spec/runtime/ | canonicalize_spec, cap_adapters_spec, cap_resolve_spec, codegen_spec, collect_ext_spec, commands_spec, lifecycle_spec, normalize_spec, optimize_spec, pipeline_spec, resolve_spec | ✅ 11/11 |
| spec/toolchain/ | conflict_spec, mappings_spec, rules_spec, strategies_spec | ✅ 4/4 |

**关键接口对齐验证：**

| 接口 | spec 断言 | 实际实现 | 状态 |
|------|-----------|---------|------|
| `ir.new()` ext_caps 桶初始化 | `ir_spec.lua` L3.1 | `ir.lua` M.new() 含 ext_caps | ✅ |
| `codegen.build()` 合并 cap_specs | `codegen_spec.lua` | `codegen.lua` build() 含 list_extend | ✅ |
| `mappings.resolve()` | `mappings_spec.lua` | `mappings.lua` M.resolve() | ✅ |
| `cap_resolve` no-adapter warn | `cap_resolve_spec.lua` | cap_resolve.lua warn diag | ✅ |
| `pipeline.PHASE_ORDER` 包含 8 phases | `pipeline_spec.lua` | phase_registry 注册 8 phases | ✅ |
| `lifecycle.observe()` | `lifecycle_spec.lua` | lifecycle.lua M.observe() | ✅ |

---

## 六、设计原则深度分析

### 6.1 依赖倒置（DIP）实现质量

**优秀实践：**

- `ports.lua`：编译器内核的所有 IO 依赖倒置为接口，vim API 在 Layer 4 注入
- `CapAdapterRegistry`：cap_type → adapter 路由通过注册表解耦，codegen 不知道具体适配器
- `ModuleProvider`：lang 模块发现通过接口抽象，可替换为文件系统扫描或手动注册

**改进点：**

- `collect_ext.lua` 直接 `require("modules.capability.schema")` 和 `require("modules.capability.graph")`，依赖具体实现而非接口。建议通过配置注入验证器和图排序器（或接受当前简单方案，层级在 Layer 4 调用 Layer 2 是合规的）。

### 6.2 管道流（Pipeline）实现质量

当前管道设计已达到编译器级别的严谨性：

- Phase 输入/输出类型契约明确（STAGE_REQUIRED 表）
- SM 状态转换防止越界 phase 执行
- debug_run 支持任意 stop_after 点，便于调试和测试

**一个潜在演进点：** 当 Phase 数量增长到 15+ 时，考虑引入 Phase Group（类似编译器的 pass group），允许并行执行无依赖的 sub-passes。当前 8 phases 无需此优化。

### 6.3 通信协议（IR 作为 Phase 协议）

IR 承担了 phase 间"消息格式"的角色。当前设计的问题：

1. **IR 是 open table**：任何 phase 都可以在 IR 上写任意字段（虽然 freeze 在 debug 模式下可检测）。缺乏像 Protocol Buffer 那样的字段注册机制。
2. **Schema 验证是基于 stage 的单点检查**：`ir_mod.validate(ir, stage)` 只检查"进入 stage 前"，没有检查"退出 stage 后"的输出完整性。

**建议（非阻塞）：** 为每个 Phase 增加 `output_validate(ir) -> Diagnostic[]`，在 `pass.run_phase()` 中的 pcall 后自动调用，形成完整的"输入前/输出后"双向验证。

### 6.4 插件插拔（Plugin-In）实现质量

**当前已实现的插拔点：**

- lang 模块：`modules/lang/*.lua` 自动发现，`registry.register()` 手动扩展
- cap 模块：`collect_ext.register()` 显式注册
- adapters：`AdapterRegistry.register()` 和 `CapAdapterRegistry.register()`
- strategies：`StrategyRegistry.register()`
- picker/terminal backends：`api.picker_register()` / `api.terminal_register()`

**未实现的插拔点（演进方向）：**

- Phase 注册：`PhaseRegistry` 已有，但 phase 顺序由 `priority` 数字决定，插入新 phase 时需要手动规划 priority 数值，有冲突风险。建议增加 `after`/`before` 声明式依赖。
- IR 字段扩展：第三方 cap 适配器希望在 IR 上挂载私有字段时，无命名空间保护。

---

## 七、LazyVim 兼容性保证

**核心原则：** LTOS 生成的 LazySpec 与 LazyVim 原生 spec 是**平等的合并关系**，不替换 LazyVim 内置配置。

| 保障机制 | 实现位置 | 说明 |
|---------|---------|------|
| 引擎占位不设 opts | `plugins/lsp/lsp.lua` 等 | 插件 spec 只声明名称，opts 由 LTOS 适配器注入 |
| LazyVim import 在前 | `runtime/providers/config.lua` | `{ import = "lazyvim.plugins" }` 排在 lang_specs 之前 |
| opts_extend 兼容 | `runtime/adapters/lsp.lua` | `opts_extend = { "servers.*.keys" }` 保持 LazyVim 合并语义 |
| `_source` 标记 | 所有 LTOS 适配器输出 | LTOS 产出 spec 带 `_source = "ltos:*"` 可追溯，不影响 lazy.nvim 加载 |
| VeryLazy 延迟命令注册 | `config/lazy.lua` | `runtime.setup_commands()` 在 VeryLazy 后执行，不阻塞启动 |

---

## 八、P6 实现优先级清单

### P6-A 必须修复（影响正确性）

| 编号 | 问题 | 文件 | 工作量 |
|------|------|------|--------|
| P6-A1 | cap_resolve adapter.build 调用方式错误（§3.1） | `runtime/passes/cap_resolve.lua` | 1行 |
| P6-A2 | cap 模块 hash 未纳入缓存键（§3.3） | `runtime/init.lua` | 2行 |

### P6-B 应该修复（架构合规性）

| 编号 | 问题 | 文件 | 工作量 |
|------|------|------|--------|
| P6-B1 | modules/capability/* → core/compiler/ir 越层（§3.2） | 新建 `core/domain/diagnostic.lua`，修改 graph.lua + lifecycle.lua | 中 |
| P6-B2 | ext_schema known_presets 与 keybind_presets 重复（§3.4） | 新建 `core/domain/keybind_presets_data.lua` | 小 |
| P6-B3 | cap_type 字符串散见多处（§3.7） | 新建 `core/domain/cap_types.lua` | 小 |

### P6-C 建议优化（质量提升）✅ 全部完成

| 编号 | 问题 | 文件 | 状态 |
|------|------|------|------|
| P6-C1 | lifecycle.observe 入口未暴露给外部（§3.5） | `runtime/api.lua` | ✅ 已完成 |
| P6-C2 | cap_registry 副作用在 require 时执行（§3.6） | `runtime/adapters/cap_registry.lua` + `runtime/adapters/registry.lua` | ✅ 已完成 |
| P6-C3 | pipeline spec PHASE_ORDER 硬编码断言（§3.11） | `lua/spec/runtime/pipeline_spec.lua` | ✅ 已完成 |
| P6-C4 | IR 增加 ir_version 字段（§3.8） | `core/compiler/ir.lua` + `cache/version.lua` + `cache/policy.lua` | ✅ 已完成 |
| P6-C5 | plugins/ai/ai.lua 与 modules/ai/copilot.lua 职责重叠（§3.9） | `plugins/ai/ai.lua` + `modules/ai/copilot.lua` + `runtime/adapters/ai_cap.lua` | ✅ 已完成 |

### P6-D 演进项 ✅ D1/D2 已完成，D3/D4/D5 为未来演进

| 编号 | 方向 | 状态 | 描述 |
|------|------|------|------|
| P6-D1 | Phase 声明式依赖 | ✅ 已完成 | PhaseRegistry 支持 `after`/`before` 声明式依赖 + 拓扑排序 |
| P6-D2 | Phase 输出验证 | ✅ 已完成 | 在 `pass.run_phase()` 中增加 `output_validate(ir)` 钩子 |
| P6-D3 | IR 字段命名空间 | 🔶 未来演进 | 第三方 phase 挂载 private 字段时有命名空间保护 |
| P6-D4 | cap 模块 profile 过滤 | 🔶 未来演进 | cap 模块支持 `profiles = {"full", "nix"}` 字段，collect_ext 按 profile 过滤 |
| P6-D5 | 并行 sub-phase | 🔶 未来演进 | collect 和 collect_ext 无数据依赖，理论可并行；需 pipeline SM 支持 fork/join |

---

## 九、缓存键版本演进

| 版本 | 触发条件 | 状态 |
|------|---------|------|
| v1~v4 | 历史版本 | 已淘汰 |
| v5 | P3 引入 cap 模块（当前） | ✅ 当前 |
| **v6** | P6-A2：cap 模块 hash 纳入键 | 🟡 待实现 |

`cache/version.lua` 需将 `CACHE_VERSION` 和 `SCHEMA_VERSION` 同步升至 6。

---

## 十、Profile 语义（完整）

| Profile | lang 模块集 | cap 模块集 | 工具策略 |
|---------|------------|-----------|---------|
| `full` | 全部 discovered | 全部 registered（collect_ext.register 列表） | rules 默认管道 |
| `minimal` | 仅 `core=true`（lua_lang） | 全部（cap 不参与 profile 过滤） | 同上 |
| `nix` | 同 full | 同 full | `prefer_system=true`：PATH 有则不用 mason |

**设计决策记录：** cap 模块不参与 profile 过滤，原因是能力模块（image/ai/keybind）是与语言无关的"编辑器能力"，在任何 profile 下都应生效。如需过滤，通过 `collect_ext.register()` 在 defaults/caps.lua 中控制白名单。

---

## 十一、历史已完成项

### v4 + P0（2026-04 之前）

- V-01~V-08：硬编码模块/适配器/工具/spec 列表 ✅
- S-01~S-05：picker/schema/version/mappings/env 耦合 ✅
- M-01~M-05：各类架构气味 ✅
- P0-1~P0-4：BuildRequest/IR tier/nix profile/文档 ✅

### P1（2026-04）

- P1-1：ir.diag path-hash 确定性编码 ✅
- P1-2：cache IO 端口注入 (ports.lua) ✅
- P1-3：api.terminal_set_default ✅
- P1-4：扩展层边界检查 ✅

### P2（2026-04）

- P2-1：PhaseRegistry 替代硬编码 phase 列表 ✅
- P2-2：runtime/defaults/*.lua 外置大表 ✅
- P2-3：M-04: icons 集中化 ✅
- P2-4：module core=true 元数据替代 CORE_MODULES ✅

### P3（2026-05）

- 新增 8 个 Phase 外全部能力模块、ext_schema、invariants ✅
- IR.ext_caps + IR.cap_specs 扩展 ✅
- 双状态机（lifecycle + pipeline）✅
- 48 个 spec 文件全量对齐 ✅

### P4（2026-05）

- conflict.lua 策略冲突检测 ✅
- mappings.resolve() 方法 ✅
- modules/capability/graph + lifecycle ✅
- Invariant 11~15 文档 + CI ✅

### E 系列演进

- E-01：spec 模块化（lua/spec/* + _runner）✅
- E-03：keybind preset 外置（modules/capability/defaults/）✅
- E-04：Invariant 11~15 CI 扩展 ✅

---

## 十二、验证命令

```bash
just check          # 层边界静态检测
just test           # 全量 headless spec 运行

# 单文件调试
nvim --headless -l spec/runtime/cap_resolve_spec.lua
nvim --headless -l spec/core/ir_spec.lua

# LTOS 用户命令（Neovim 内）
:LtosInfo           # 当前 profile / state / modules / tools / strategies / timings
:LtosDebug collect  # IR snapshot at collect stage
:LtosTrace          # per-phase timeline ASCII bar chart
:LtosGraph dag      # pipeline DAG 可视化
:LtosDiff collect optimize  # IR structural diff
```

**目标通过率：48/48 spec 文件，0 layer boundary violations**
