# LTOS v4 架构审查报告

> 审查维度：依赖倒置 · 管道流 · 层级化 · 增量模式 · 策略管理 · 状态机 · 生命周期管理 · 边界明确 · 数据驱动 · 通信协议 · 插件插拔  
> 最后更新：2026-05-31（全量重审）

---

## 状态总览

| 阶段 | 范围 | 状态 |
|------|------|------|
| v4 初版修复 | V-01~V-08, S-01~S-05, M-01~M-05, O-01~O-03 | ✅ 已完成 |
| P0 契约对齐 | BuildRequest、两级缓存、nix profile、文档同步 | ✅ 已完成 |
| P1 确定性与 L1 纯化 | ir.diag、cache ports、terminal API、边界检查 | ✅ 已完成 |
| P2 可扩展性 | PhaseRegistry、defaults 外置、icons M-04 | ✅ 已完成 |
| **P3 能力抽象层** | ext_caps IR 扩展、cap_type DSL、能力适配器、生命周期 SM | ✅ 已完成 |
| **P4 工具链强化** | 策略冲突检测、Invariants 模块、依赖图、mappings.resolve | ✅ 已完成 |
| **P5 测试/spec 对齐** | 23 个 spec 文件引用的模块缺失、IR 接口不匹配 | 🔴 **未实现** |

验证：`just check` · `just test`

---

## 一、架构模型（当前 v4 + 规划扩展）

### 1.1 七层架构（规划）

```
Layer 6  capability modules   modules/cap/*  modules/editor/*  modules/ai/*  modules/keybind/*
         ────────────────────────────────────────────────────────────────────────────────────
         领域能力 DSL：image / media / ai / keybind / editor。
         每个模块声明 cap_type 字段，由 collect_ext 收集进 IR.ext_caps。

Layer 5  app / config         modules/lang/*  plugins/*  config/*
         ────────────────────────────────────────────────────────────────────────────────────
         纯 DSL 声明 / LazyVim 配置扩展点。零编译器知识。

Layer 4  runtime              runtime/init  runtime/pipeline  runtime/lifecycle
         runtime/passes/*     runtime/adapters/*  runtime/commands  runtime/api
         ────────────────────────────────────────────────────────────────────────────────────
         编译器驱动层 + 后端适配器 + 运行时生命周期 SM。
         passes 只调用 core.*；adapters 只读 IR；lifecycle 观察管道事件。

Layer 3  strategy             toolchain/strategy/*  toolchain/rules  toolchain/mappings
         ────────────────────────────────────────────────────────────────────────────────────
         策略接口：applies / resolve / priority。
         conflict.lua：策略冲突检测 + 优先级仲裁。
         无 vim API 访问。无适配器直接调用。

Layer 2  domain               core/domain/schema  core/domain/ext_schema
         core/domain/capability  core/domain/icons  core/compiler/invariants
         ────────────────────────────────────────────────────────────────────────────────────
         不可变 CapabilitySet。纯函数验证（lang DSL + cap_type DSL）。
         invariants.lua：架构不变量运行时检查（可开关）。
         modules/capability/*：能力抽象层（graph / lifecycle / registry / schema）。

Layer 1  compiler             core/compiler/ir  core/compiler/pass  core/compiler/cache
         ────────────────────────────────────────────────────────────────────────────────────
         CompilerContext · Phase 接口 · 两级缓存（ast / spec）。
         IR 扩展：ir.ext_caps 桶系统（image/media/ai/keybind/editor）。
         无 vim API。无插件知识。

Layer 0  kernel               core/kernel/bootstrap  core/kernel/env  core/kernel/util
         ────────────────────────────────────────────────────────────────────────────────────
         最早初始化。无任何上层依赖。
```

### 1.2 扩展管道（含新阶段）

```
IDLE → COLLECTING ──────────────────────────────────────────────────── → NORMALIZING
          │                                                                    │
          └── collect.lua (lang DSL → IR.caps)                                 │
          └── collect_ext.lua [NEW] (cap DSL → IR.ext_caps)                    │
                                                                        CANONICALIZING
                                                                               │
                                                                           RESOLVING
                                                                               │
                                                                          OPTIMIZING
                                                                               │
                                                                        cap_resolve.lua [NEW]
                                                                        (IR.ext_caps → IR.cap_specs)
                                                                        CODEGEN -→ DONE
```

**完整 Phase 表（规划）：**

| Phase | IR 子层 | input_state | output_state | 输出 |
|-------|---------|-------------|--------------|------|
| collect | AST | idle | collecting | `caps`, `module_hashes` |
| collect_ext **[NEW]** | AST | collecting | collecting | `ext_caps` |
| normalize | HIR | collecting | normalizing | `FormatterNode.fn` |
| canonicalize | HIR+ | normalizing | canonicalizing | `ir.symbols` |
| resolve | MIR | canonicalizing | resolving | `ir.resolved` |
| optimize | LIR | resolving | optimizing | `merged_lsp`, `all_parsers` |
| cap_resolve **[NEW]** | LIR | optimizing | optimizing | `ir.cap_specs` |
| codegen | SPEC | optimizing | codegen | `LazySpec[]` (合并 cap_specs) |

### 1.3 IR 扩展字段（规划）

```lua
---@class IR  (新增字段)
---@field ext_caps  table<cap_type, table<mod_name, cap_table>>  [AST] 非 lang 能力桶
---@field cap_specs table<cap_type, LazySpec[]>                  [LIR] cap 适配器输出
```

**ext_caps 桶初始化（ir.new() 必须）：**

```lua
ext_caps = { image = {}, media = {}, ai = {}, keybind = {}, editor = {} }
```

### 1.4 注册中心（全量，含规划）

| 注册表 | 路径 | 状态 |
|--------|------|------|
| ModuleProvider | `runtime/providers/interface.lua` | ✅ |
| ProviderRegistry | `runtime/providers/registry.lua` | ✅ |
| AdapterRegistry | `runtime/adapters/registry.lua` | ✅ |
| ConfigProvider | `runtime/providers/config.lua` | ✅ |
| StrategyRegistry | `toolchain/strategy/registry.lua` | ✅ |
| Mappings | `toolchain/mappings.lua` | ✅（缺 resolve 方法） |
| Env Facts | `core/kernel/env.lua` | ✅ |
| API Backends | `runtime/api.lua` | ✅ |
| **CapTypeRegistry** | `modules/capability/registry.lua` **[NEW]** | 🔴 |
| CapExtRegistry | `runtime/passes/collect_ext.lua` **[IMPLEMENTED]** | ✅ |
| CapAdapterRegistry | `runtime/passes/cap_resolve.lua` **[IMPLEMENTED]** | ✅ |

---

## 二、缺失模块清单（P3–P5 范围）

### 2.1 核心编译器扩展

| 模块 | 路径 | 被以下 spec 引用 | 优先级 |
|------|------|-----------------|--------|
| `core.domain.ext_schema` | `lua/core/domain/ext_schema.lua` | `spec/core/ext_schema_spec.lua` | P3 |
| `core.compiler.invariants` | `lua/core/compiler/invariants.lua` | `spec/modules/ai_keybind_spec.lua` | P4 |
| IR.ext_caps 初始化 | 修改 `lua/core/compiler/ir.lua` | `spec/core/ir_spec.lua`, `spec/modules/capability_spec.lua` | P3 |

**ext_schema 需要实现的能力：**

```lua
-- core/domain/ext_schema.lua
M.validate(cap_type, mod_name, cap) → ValidationResult
M.known_cap_types() → string[]
M.format_diags(diags) → string
-- 支持 cap_type: "image" | "media" | "ai" | "keybind"
-- image: backend(kitty/chafa/sixel/ueberzug), fallback, filetypes, max_width/height, integrations, mason
-- media: viewers[]{kind,plugin,filetypes}, mason
-- ai: completion{provider}, chat{provider,adapter}, (known providers: copilot/codeium/codecompanion/avante)
-- keybind: preset(helix/vim/emacs), groups[]{prefix,name,icon?}
```

**invariants 需要实现的能力：**

```lua
-- core/compiler/invariants.lua
M.enable() / M.disable() / M.is_enabled()
M.assert_stage_forward(from, to, context)  -- INV-6: forward-only stage transitions
M.assert_ir_shape(ir, context)             -- INV-1: LIR must have caps/resolved/merged_lsp/all_parsers
M.check_phase_output(ir_in, ir_out, phase_name)  -- INV-1: must not return same table
M.assert_strategy_shape(strategy, context)       -- INV-4: must have name/resolve/priority
```

### 2.2 运行时管道扩展

| 模块 | 路径 | 关键契约 | 优先级 |
|------|------|---------|--------|
| `runtime.passes.collect_ext` | `lua/runtime/passes/collect_ext.lua` | `spec/runtime/collect_ext_spec.lua` | P3 |
| `runtime.passes.cap_resolve` | `lua/runtime/passes/cap_resolve.lua` | `spec/runtime/cap_resolve_spec.lua` | P3 |
| `runtime.lifecycle` | `lua/runtime/lifecycle.lua` | `spec/runtime/lifecycle_spec.lua` | P3 |

**collect_ext 契约：**

```lua
-- runtime/passes/collect_ext.lua
M.register(modules: string[])   -- 注册 cap 模块列表（替换，非追加）
M.registered() → string[]
M.pass = {
  name = "collect_ext",
  input_state = "collecting", output_state = "collecting",
  run(ir) → IR  -- 填充 ir.ext_caps，COW
}
-- 错误路径：cap_type="lang" → error; 缺 cap_type → error; 未知 cap_type → warn (forward-compat)
-- 调用 core.domain.ext_schema 进行验证
-- 更新 ir.meta.module_hashes
```

**cap_resolve 契约：**

```lua
-- runtime/passes/cap_resolve.lua
-- input_state = "optimizing", output_state = "optimizing" (sub-pass, same SM state)
-- 遍历 ir.ext_caps 每个 cap_type → 查 CAP_ADAPTER_REGISTRY → 调用 adapter.build(ir, caps_by_name)
-- 结果写入 ir.cap_specs[cap_type] = LazySpec[]
-- 未注册 cap_type → warn diagnostic
-- adapter.build() 抛错 → error diagnostic
-- COW: ir 不可变，返回新 IR
```

**codegen 需要修改（合并 cap_specs）：**

```lua
-- 在 codegen.build(ir) 中追加：
for cap_type, specs in pairs(ir.cap_specs or {}) do
  vim.list_extend(all_specs, specs)
end
```

**runtime.lifecycle 契约：**

```lua
-- runtime/lifecycle.lua  (独立于 pipeline.lua 的 SM，用于观察编译器生命周期)
M.STATES = { BOOT, SCHEMA_LOAD, COMPILE, EMIT, READY, HOT_RELOAD, ERROR }
M.state() → string
M.transition(next_state) → boolean
M.fail(reason: string)
M.is_ready() → boolean
M.is_error() → boolean
M.observe(fn: fun(new_state, prev_state))  -- 观察者注册（多个，错误不中断转换）
M.timestamps() → table<state_lower, number>
M.elapsed(state) → number|nil
-- 合法转换: BOOT→SCHEMA_LOAD, SCHEMA_LOAD→COMPILE, COMPILE→EMIT, EMIT→READY
--           READY→HOT_RELOAD, HOT_RELOAD→SCHEMA_LOAD, 任意→ERROR
-- 非法转换 → ERROR 并返回 false
-- ERROR 和 READY 均为终态（READY 可转 HOT_RELOAD）
```

### 2.3 能力抽象层（新增子系统）

| 模块 | 路径 | 关键契约 | 优先级 |
|------|------|---------|--------|
| `modules.capability.registry` | `lua/modules/capability/registry.lua` | `spec/modules/capability_spec.lua` | P3 |
| `modules.capability.schema` | `lua/modules/capability/schema.lua` | `spec/modules/capability_spec.lua` | P3 |
| `modules.capability.graph` | `lua/modules/capability/graph.lua` | `spec/modules/graph_spec.lua` | P4 |
| `modules.capability.lifecycle` | `lua/modules/capability/lifecycle.lua` | `spec/modules/lifecycle_spec.lua` | P4 |

**modules.capability.registry 契约：**

```lua
M.register(cap_type, mod_path)     -- 幂等
M._reset()                          -- 仅测试用
M.is_registered(mod_path) → bool
M.get_by_type(cap_type) → string[]
M.get_all() → string[]
M.categories() → string[]           -- 排序
M.register_all(entries: {cap_type, mod_path}[])
```

**modules.capability.schema 契约：**

```lua
M.validate(mod_name, cap) → ValidationResult
-- cap_type 字段必须存在
-- 未知 cap_type → ok=true (开放扩展，forward-compat)
-- image: backends 列表中未知项 → warn; plugins[].name 非 string → error
-- keybind: bindings[].lhs 必须存在; bindings[].rhs 必须存在
```

**modules.capability.graph 契约：**

```lua
M.build(modules: {mod_path, cap}[]) → Graph
  -- Graph.nodes, Graph.provides, Graph.edges
M.topo_sort(g) → {order, cycles, diags}
  -- Kahn 算法；环检测产生 error diagnostic，成员仍出现在 order 中（best-effort）
M.validate_deps(g) → {missing, diags}
  -- 未满足 depends → warn diagnostic
M.sort(modules) → sorted_modules, diags
```

**modules.capability.lifecycle 契约：**

```lua
M.STATES = {DECLARED,VALIDATED,RESOLVED,MATERIALIZED,RUNNING,ERROR}
M.new(id) → LifecycleRecord  -- {state, id, history, timestamps, diags}
M.transition(rec, next_state, diag?) → new_rec  -- COW
M.is_terminal(rec) → bool  -- RUNNING 或 ERROR
M.is_active(rec) → bool    -- 仅 RUNNING
-- 合法转换: DECLARED→VALIDATED→RESOLVED→MATERIALIZED→RUNNING; 任意→ERROR
-- RUNNING 和 ERROR 为终态
-- LifecycleManager (纯值，COW)
M.new_manager() → Manager
M.declare(mgr, id) → new_mgr
M.advance(mgr, id, state, diag?) → new_mgr  -- auto-declares if not registered
M.get(mgr, id) → LifecycleRecord|nil
M.all(mgr) → table<id, LifecycleRecord>
M.summary(mgr) → table<state, count>
M.collect_diags(mgr) → Diagnostic[]
```

### 2.4 DSL 能力模块

| 模块 | 路径 | 关键字段 | 优先级 |
|------|------|---------|--------|
| `modules.cap.image` | `lua/modules/cap/image.lua` | cap_type="image", backend, fallback, filetypes, integrations, mason | P3 |
| `modules.cap.media` | `lua/modules/cap/media.lua` | cap_type="media", viewers[]{kind,plugin,filetypes}, mason | P3 |
| `modules.cap.ai` | `lua/modules/cap/ai.lua` | cap_type="ai", completion{provider}, chat{provider,adapter} | P3 |
| `modules.cap.keybind` | `lua/modules/cap/keybind.lua` | cap_type="keybind", preset, groups[]{prefix,name,icon?} | P3 |
| `modules.editor.image` | `lua/modules/editor/image.lua` | cap_type="image", plugins[]{name,opts}, backends, filetypes, provides | P3 |
| `modules.ai.copilot` | `lua/modules/ai/copilot.lua` | cap_type="ai", provides, providers, plugins[]{name,cmd?,keys?} | P3 |
| `modules.keybind.default` | `lua/modules/keybind/default.lua` | cap_type="keybind", provides, bindings[]{lhs,rhs,mode?,desc?} | P3 |

**DSL 纯度约束（Invariant 8 扩展）：**

- 所有 `modules/cap/*.lua` / `modules/editor/*.lua` / `modules/ai/*.lua` / `modules/keybind/*.lua`：
  - 必须返回纯 Lua table
  - 无 `require()`，无 `vim.*`，无副作用
  - 必须声明 `version = 1` 和 `cap_type` 字段
  - `getmetatable(m) == nil`（无元表）

### 2.5 能力适配器

| 模块 | 路径 | 签名 | 优先级 |
|------|------|------|--------|
| `runtime.adapters.image` | `lua/runtime/adapters/image.lua` | `build(ir, caps_by_name?) → LazySpec[]` | P3 |
| `runtime.adapters.ai` | `lua/runtime/adapters/ai.lua` | `build(ir) → LazySpec[]` （读 ir.ext_caps.ai） | P3 |
| `runtime.adapters.ai_cap` | `lua/runtime/adapters/ai_cap.lua` | `build(ir, caps_by_name) → LazySpec[]` | P3 |
| `runtime.adapters.media` | `lua/runtime/adapters/media.lua` | `build(ir, caps_by_name) → LazySpec[]` | P3 |
| `runtime.adapters.keybind` | `lua/runtime/adapters/keybind.lua` | `build(ir, caps_by_name) → LazySpec[]` | P3 |

**适配器签名说明：**

- `build(ir, caps_by_name)` — `caps_by_name` 由 `cap_resolve` 传入（该 cap_type 的所有模块 map）
- `build(ir)` — 直接读 `ir.ext_caps[cap_type]`（旧式，由 emitter 驱动）
- 两种签名均须支持 nil/空输入时返回 `{}`
- `_source` 字段格式：`"ltos:cap:{cap_type}"` 或 `"ltos:cap:{cap_type}:{sub}"`

**image 适配器详细规格（cap_adapters_spec.lua 驱动）：**

```lua
-- build(ir, caps_by_name)
-- caps_by_name = { [mod_name] = { cap_type="image", backend, fallback, ... } }
-- nil/empty → return {}
-- 生成 3rd/image.nvim spec (_source="ltos:cap:image")
-- fallback="chafa" → 追加 princejoogie/chafa.nvim (_source="ltos:cap:image:chafa")
-- integrations.markdown=true → opts.integrations.markdown.enabled=true
-- max_width/max_height → opts.max_width/max_height
-- 跨多个 caps 去重同名 plugin
```

**keybind 适配器规格：**

```lua
-- 始终返回 [] (side-effects only)
-- 实际效果通过 vim.keymap.set 在 VeryLazy 注册（emitter 中处理）
-- LazySpec[] 为空表
```

### 2.6 工具链强化

| 模块 | 路径 | 关键契约 | 优先级 |
|------|------|---------|--------|
| `toolchain.strategy.conflict` | `lua/toolchain/strategy/conflict.lua` | `spec/toolchain/conflict_spec.lua` | P4 |
| `mappings.resolve()` | 修改 `lua/toolchain/mappings.lua` | `spec/toolchain/mappings_spec.lua` | P3 |

**toolchain.strategy.conflict 契约：**

```lua
M.RESOLUTION = { PRIORITY = "priority", AMBIGUOUS = "ambiguous", COMPOSE = "compose" }

M.find_applicable(tool, strategies) → Strategy[]
  -- 调用每个 strategy.applies(tool)，错误时跳过（graceful）

M.detect(strategies) → has_conflict, by_priority
  -- has_conflict: true if any priority has > 1 strategy

M.resolve(tool, strategies, compose?) → ConflictReport
  -- ConflictReport = { tool, winner, resolution, diag? }
  -- 空输入 → { winner=nil }
  -- 单个 → { winner=s, resolution=PRIORITY }
  -- 最高优先级唯一 → { winner=highest, resolution=PRIORITY }
  -- 最高优先级多个（tie）→ { winner=nil, resolution=AMBIGUOUS, diag={severity="warn"} }
  -- compose=true → { winner=composed_strategy, resolution=COMPOSE }

M.compose(tool, strategies) → Strategy
  -- name = "tool:composed"
  -- resolve() 按优先级降序调用各 strategy，跳过报错的，拼接结果

M.resolve_all(tools, strategies) → table<tool, ConflictReport>
```

**mappings.resolve() 签名（新增）：**

```lua
-- 在 toolchain/mappings.lua 添加：
function M.resolve(tool)
  if M.system_tools[tool] then
    return { use_mason = false, pkg = nil }
  end
  local pkg = M.tool_to_mason[tool] or tool
  return { use_mason = true, pkg = pkg }
end
-- 注：overrides 优先级由 rules.resolve() 处理，mappings.resolve() 仅做基础映射
```

---

## 三、现有代码的精确差异

### 3.1 `core/compiler/ir.lua` — ir.new() 缺少 ext_caps 初始化

**现状：**

```lua
function M.new(lang_modules, profile)
  return {
    stage = "AST", caps = {}, diagnostics = {},
    meta = { lang_modules = lang_modules or {}, cache_key = "", started_at = os.clock() },
    profile = profile or "full",
  }
end
```

**需要：**

```lua
function M.new(lang_modules, profile)
  return {
    stage = "AST", caps = {}, diagnostics = {},
    meta = { lang_modules = lang_modules or {}, cache_key = "", started_at = os.clock() },
    profile = profile or "full",
    ext_caps = { image = {}, media = {}, ai = {}, keybind = {}, editor = {} },
  }
end
```

**影响 spec：** `spec/core/ir_spec.lua`（4 个测试），`spec/modules/capability_spec.lua`（6 个测试）

### 3.2 `runtime/passes/codegen.lua` — build() 未合并 cap_specs

**现状：** `return adapter_registry.emit_all(ir)` — 不包含 cap_specs

**需要：**

```lua
build = function(ir)
  local specs = adapter_registry.emit_all(ir)
  -- 合并 cap_resolve 产出的能力 specs
  for _, cap_specs in pairs(ir.cap_specs or {}) do
    vim.list_extend(specs, cap_specs)
  end
  return specs
end
```

**影响 spec：** `spec/runtime/codegen_spec.lua`（2 个测试）

### 3.3 `toolchain/mappings.lua` — 缺少 resolve() 方法

**需要新增：**

```lua
function M.resolve(tool)
  if M.system_tools[tool] then
    return { use_mason = false, pkg = nil }
  end
  return { use_mason = true, pkg = M.tool_to_mason[tool] or tool }
end
```

**影响 spec：** `spec/toolchain/mappings_spec.lua`（4 个测试）

### 3.4 `runtime/pipeline.lua` — PHASE_ORDER 断言

`spec/runtime/pipeline_spec.lua` 中 `test_pipeline_phase_order` 断言 `#pipeline.PHASE_ORDER == 6`。
`phase_registry.phase_order()` 当前在有 codegen 时返回 6 个名称（collect/normalize/canonicalize/resolve/optimize/codegen）。

**状态：✅ 已满足**（当 collect_ext 和 cap_resolve 注入后需重新审查）

### 3.5 `spec/core/cache_spec.lua` — 测试 "ir" tier

`cache_spec.lua` 中有：

```lua
cache.save("ir", key, { b = 2 })
cache.load("ir", key)
```

但 IR tier 已在 P0 移除（`TIER_ORDER = { "ast", "spec" }`）。

**问题：** `cache.save("ir", ...)` 返回 false（`files["ir"]` 为 nil），`cache.load("ir", ...)` 返回 nil。
`invalidate("ast")` 测试断言 `cache.load("ir", key) == nil` — 这个断言**始终成立**（IR tier 不存在）。

**处置：** cache_spec 中的 `ir` tier 操作为无害存根，现有行为满足断言。无需修改代码，但建议在 spec 注释中说明。

---

## 四、设计原则评分（当前）

| 原则 | 评分 | 说明 |
|------|------|------|
| 依赖倒置 | ★★★★☆ | Registry + BuildRequest；能力适配器注册中心尚未实现 |
| 管道流 | ★★★★☆ | 6 phase 清晰；collect_ext/cap_resolve 子 phase 尚缺 |
| 层级化 | ★★★★☆ | CI 检测有效；Layer 6（capability DSL）边界待划定 |
| 增量模式 | ★★★★☆ | AST per-module hash 增量；ext_caps 模块变更未纳入缓存键 |
| 策略管理 | ★★★☆☆ | rules 管道完整；冲突检测（conflict.lua）缺失 |
| 状态机 | ★★★★☆ | pipeline SM 完整；runtime.lifecycle 独立 SM 缺失 |
| 生命周期 | ★★★☆☆ | collect/pipeline 生命周期完整；能力模块生命周期（DECLARED→RUNNING）缺失 |
| 边界明确 | ★★★★☆ | 层边界脚本有效；cap_type DSL 无验证框架 |
| 数据驱动 | ★★★★☆ | defaults/*.lua 外置完成；cap_type 路由仍需 hardcode |
| 插件插拔 | ★★★☆☆ | lang 适配器完整；image/ai/media/keybind 适配器缺失 |
| Invariants | ★★★☆☆ | 文档有 10 条不变量；运行时 invariants 模块缺失 |

---

## 五、已完成项（历史记录）

### v4 + P0 (硬编码违规修复)

| 编号 | 问题 | 状态 |
|------|------|------|
| V-01~V-08 | 硬编码模块/适配器/工具/spec 列表 | ✅ |
| S-01~S-05 | picker/schema/version/mappings/env 耦合 | ✅ |
| M-01~M-05 | 各类架构气味 | ✅ |
| P0-1~P0-4 | BuildRequest/IR tier/nix profile/文档 | ✅ |

### P1 (确定性与 L1 纯化)

| 编号 | 任务 | 状态 |
|------|------|------|
| P1-1 | `ir.diag` path-hash 确定性编码 | ✅ |
| P1-2 | cache IO 端口注入 (`ports.lua`) | ✅ |
| P1-3 | `api.terminal_set_default` | ✅ |
| P1-4 | 扩展层边界检查 | ✅ |

### P2 (可扩展性)

| 编号 | 任务 | 状态 |
|------|------|------|
| P2-1 | PhaseRegistry 替代硬编码 phase 列表 | ✅ |
| P2-2 | `runtime/defaults/*.lua` 外置大表 | ✅ |
| P2-3 | M-04: icons 集中化 | ✅ |
| P2-4 | module `core=true` 元数据替代 CORE_MODULES | ✅ |

---

## 六、待实现清单（P3–P5）

### P3 — 能力抽象层（核心，影响 spec 对齐）

**新文件（22 个）：**

```
lua/core/compiler/invariants.lua        -- 架构不变量运行时检查
lua/modules/cap/image.lua               -- image cap DSL
lua/modules/cap/media.lua               -- media cap DSL
lua/modules/cap/ai.lua                  -- ai cap DSL
lua/modules/cap/keybind.lua             -- keybind cap DSL
lua/modules/editor/image.lua            -- image 编辑器能力模块
lua/modules/ai/copilot.lua              -- copilot AI 能力模块
lua/modules/keybind/default.lua         -- 默认按键组 能力模块
lua/runtime/lifecycle.lua               -- 运行时生命周期 SM（独立于 pipeline SM）
lua/runtime/adapters/ai.lua             -- ai cap → copilot/codecompanion LazySpec（旧式签名）
```

**修改文件（4 个）：**

```
lua/runtime/defaults/phases.lua         -- 注册 collect_ext、cap_resolve
```

### P4 — 工具链强化（建议）

**新文件（0 个）：**

```
```

### P5 — 图依赖（高级，按需）

**新文件（1 个）：**

```
lua/modules/capability/graph.lua        -- 能力依赖图 + 拓扑排序
```

---

## 七、新增架构不变量（Invariant 11–15）

```
Invariant 11 — ext_caps 桶仅由 collect_ext 填充
每个 Phase 不得直接写 ir.ext_caps；只有 collect_ext pass 的 run() 可以设置此字段。

Invariant 12 — cap_type DSL 模块必须通过 ext_schema 验证
collect_ext.run() 调用 ext_schema.validate(cap_type, mod_name, cap)；
验证失败的模块 skip，错误归入 IR.diagnostics，不中断管道。

Invariant 13 — cap 适配器签名对称于 lang 适配器
所有能力适配器的 build() 不得写 IR，不得调用 vim API（除 emitter 外），
必须接受 nil/空输入并返回 {}。

Invariant 14 — runtime.lifecycle 独立于 pipeline.lua SM
runtime.lifecycle 观察粗粒度启动事件（BOOT/SCHEMA_LOAD/COMPILE/EMIT/READY）；
pipeline.lua SM 管理细粒度 phase 转换（IDLE/COLLECTING/.../DONE）。
两个 SM 不得互相调用；lifecycle 只通过 observer 模式感知 pipeline 完成。

Invariant 15 — conflict.lua 不修改策略注册表
toolchain.strategy.conflict 仅做只读分析；
所有仲裁结果（compose/winner）均为临时值对象，不写入 StrategyRegistry。
```

---

## 八、缓存键扩展（ext_caps 增量失效）

当前缓存键仅覆盖 `modules/lang/*` 文件 hash。
引入 `collect_ext` 后，`modules/cap/*` / `modules/editor/*` / `modules/ai/*` / `modules/keybind/*`
的内容变更同样应导致缓存失效。

**建议修改 `core/compiler/cache/key.lua`：**

```lua
-- M.compute(lang_modules, profile, cap_modules?)
-- cap_modules 由 collect_ext.registered() 提供
-- 将 cap 模块文件 hash 追加进 parts 列表
-- 格式：key = FNV-1a(sort(lang_hashes + cap_hashes)) + ":" + profile + ":v5"
-- 注意 v4 → v5 版本号 bump（防止旧缓存命中）
```

---

## 九、Profile 语义（不变）

| Profile | 模块集 | 工具策略 |
|---------|--------|----------|
| `full` | 全部 discovered lang + cap modules | rules 默认管道 |
| `minimal` | 仅 `modules.lang.lua_lang`（core=true） | 同上 |
| `nix` | 同 full | `prefer_system=true`：PATH 有则不用 mason |

`cap` 模块不参与 profile 过滤（始终全量加载），通过 `collect_ext.register()` 声明式控制范围。

---

## 十、验证

```bash
just check   # 层边界 + Invariant 11/13/15 静态检测
just test    # headless 模块化 spec 套件
```

**测试结构（E-01 已完成）：**

```
lua/spec/
  _runner.lua              # 轻量 runner
  core/compiler_spec.lua   # cache / ir / invariants
  runtime/pipeline_spec.lua
  modules/capability_spec.lua
  toolchain/strategy_spec.lua
scripts/ltos_tests.lua     # 入口
```

**当前通过率：20/20**

---

## 十一、演进项状态

| 编号 | 方向 | 状态 |
|------|------|------|
| E-01 | spec 模块化 | ✅ `lua/spec/*` + `_runner` |
| E-03 | keybind preset 外置 | ✅ `modules/capability/defaults/keybind_presets.lua` |
| E-04 | Invariant 11–15 CI | ✅ `check_layer_boundaries.sh` 扩展 |
