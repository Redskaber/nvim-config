# LTOS v4 重构 TODO-LIST（Compiler-grade）

> 范式：Pipeline + Compiler + Layered Architecture
> 目标：**确定性（determinism）+ 可验证性（verifiability）+ 可缓存性（cacheability）+ 可调试性（observability）**

---

# 0. Meta / 全局约束收敛

## TODO-0.1 架构不变量（Architecture Invariants）

* [x] 明确并固化以下 invariants（写入 `ARCHITECTURE_INVARIANTS.md`）：

  * [x] IR = **不可变值对象（value object）**
  * [x] Phase = **纯函数（无副作用）**
  * [x] Adapter = **唯一 side-effect 边界**
  * [x] Strategy = **无状态 + 可替换**
* [x] 引入 `ARCHITECTURE_INVARIANTS.md`
* [x] pipeline 每阶段 assert：

  * [x] 输入 IR 不被 mutation（debug 模式 `util.freeze` via `_G._ltos_debug_freeze`）

---

## TODO-0.2 命名统一（Compiler Terminology）

当前存在混用：

* `caps / capability / IR fields`

重构：

* [ ] 统一术语：

  * DSL → AST → HIR → MIR → LIR → SPEC
* [ ] IR 字段命名规范：

  * `ir.ast_caps`
  * `ir.hir_nodes`
  * `ir.mir_resolved`
  * `ir.lir_optimized`
* [ ] 禁止跨阶段字段复用（当前存在 `caps` 跨阶段复用问题）

---

## TODO-0.3 Debug 模式体系化

* [x] `vim.g.ltos_debug` → 扩展为：

  * [x] `LTOS_DEBUG=trace|ir|cache|perf`（`config/globals.lua` 解析环境变量）
* [x] debug 输出结构化：

  * [x] JSON lines（`LTOS_DEBUG=trace` → `vim.json.encode` 输出到 `vim.notify`）

---

# 1. Layer 0（kernel）重构

## TODO-1.1 env.lua 语义收敛

当前：

```lua
M.prefer_system(cmd) = is_nix and has(cmd)
```

问题：策略层泄漏

重构：

* [x] env 仅提供事实：

  * [x] `is_nix`
  * [x] `has(cmd)`
* [x] 删除：

  * [x] `prefer_system`（已删除，注释说明）
* [x] 将决策移至：

  * `toolchain/rules.lua`（nix_rule: `env.is_nix and env.has(tool)`）

---

## TODO-1.2 util.lua 纯函数强化

当前 OK，但可增强：

* [x] 增加：

  * [x] `deep_merge`
  * [x] `deep_equal`
  * [x] `freeze(table)`（debug 用）
* [x] 所有 util：

  * [x] 无 vim 依赖（当前符合）

---

# 2. Layer 1（compiler）重构

## TODO-2.1 IR 类型系统强化（核心问题）

* [x] 引入 IR schema（`@class IR` 完整注解，`ir.STAGES` 枚举）
* [x] 引入：`ir.new()` / `ir.transition()` / `ir.assert_stage()` / `ir.diff()` + `ir.format_diff()`

---

## TODO-2.2 Phase 执行模型强化

* [x] `CompilerContext` 已定义（`ir.ctx()`），包含 `run_id`、`timings`、`diagnostics`
* [x] `pass.run_with_ctx(phase, ctx) -> ctx` 实现（forward-compat 包装层）
* [ ] Phase.run 签名迁移为 `run(ctx) -> ctx`（各 pass 文件逐步迁移）

---

## TODO-2.3 cache.lua 分层职责拆分（关键）

当前问题：

* key 计算 + IO + policy 混在一起 

重构：

### 结构拆分

* [x] `cache/key.lua`
* [x] `cache/store.lua`
* [x] `cache/policy.lua`
* [x] `cache.lua` 作为门面（facade）

### TODO

* [x] key 引入：

  * [x] 内容 hash（而非 mtime）
* [x] spec cache 增加：

  * [x] schema version
* [x] cache 增加：

  * [x] 命中统计
  * [x] hit ratio

---

## TODO-2.4 不可序列化标记机制优化

当前：

```lua
_no_cache = true
```

问题：

* 侵入业务对象

重构：

* [x] 使用：

  * metatable 标记（`__ltos_cacheable = false`）
  * 向后兼容 `_no_cache` 字段

---

# 3. Layer 2（domain）重构

## TODO-3.1 CapabilitySet → 真正不可变

当前问题：

* `_store` 是全局可变状态 

重构：

* [x] CapabilitySet 改为：

  * 持久化结构（persistent data structure）
* [x] `add()` 返回新实例：

```lua
new_set, result = cap_mod.add(set, name, data)
```

* [x] 删除：

  * `_store`（`M.reset()` 保留为 no-op 向后兼容）

---

## TODO-3.2 schema.lua 编译器级错误模型

当前：

* Diagnostic 是 string + path

重构：

* [x] 引入：

```lua
---@class SchemaDiagnostic
---@field code     string   e.g. "S001"
---@field path     string
---@field message  string
---@field severity "error"|"warn"
```

* [x] 支持：

  * error code（可机器处理）
* [ ] multi-location（span）

---

## TODO-3.3 FormatterNode AST 正规化

* [x] AST 层：`{ kind="formatter", strategy="xxx" }` — source DSL，fn 禁止出现
* [x] HIR 层：`{ kind="formatter", fn=function }` — normalize pass 注入
* [x] schema 明确禁止 AST 中出现 fn（`validate_formatter_node` 检查）

---

## TODO-4.1 Strategy = 纯函数化

* [x] `resolve(bufnr) -> string[]` 是纯函数
* [x] `applies` 字段从 interface 中保留（向后兼容），builtin 策略已实现 `applies` 字段

---

## TODO-4.2 Strategy registry 生命周期

* [x] 明确：

  * bootstrap only once（`_bootstrapped` flag）
* [x] registry 冻结：

```lua
registry.lock()  -- called after bootstrap()
```

---

## TODO-4.3 rules.lua → 编译规则引擎

当前：

* if/else chain

重构：

* [x] 转换为：

  * rule pipeline

```lua
rules = {
  override_rule,
  system_rule,
  nix_rule,
  mapping_rule,
  identity_rule,
}
```

* [x] 每个 rule：

```lua
apply(ctx, tool) -> { use_mason: boolean } | nil
```

---

# 5. Layer 4（runtime）重构（关键）

## TODO-5.1 pipeline.lua = 真正状态机

当前：

* 状态机是隐式的

重构：

* [x] 引入：

```lua
StateMachine = {
  state,
  timestamps,
  transition(next_state),
  fail(),
}
```

* [x] 每 phase：

  * 必须声明：

    * input_state
    * output_state

---

## TODO-5.2 pipeline 支持子 pipeline（你提到的 bootstrap）

实现：

* [x] 引入：

```lua
Pipeline.run_sub(phases, ir) -> IR, Diagnostic[]
```

用途：

* formatter resolution sub-flow
* LSP merge sub-flow

---

## TODO-5.3 CompilerContext 生命周期隔离

* [x] 每次 run：

  * 新 ctx（`ir_mod.new()` + 独立 SM）
* [x] debug_run：

  * 禁止复用 cache（独立 SM，`_G._ltos_debug_freeze`）
* [x] ctx 增加：

  * `run_id`（`ir.meta.run_id`）

---

## TODO-5.4 adapters 彻底去 vim API（当前设计违背）

文档声明：

> adapters 不调用 vim API

重构：

* [x] adapters 仅生成：

  * spec data（纯 Lua table）
* [x] 新层：

```
runtime/emitter/init.lua
```

负责：

* vim API side-effect（vim.notify）
* 驱动 adapters，汇总 specs

---

## TODO-5.5 commands.lua 可观测性增强

* [x] LtosGraph：

  * 输出 pipeline DAG（`:LtosGraph dag`）
  * 输出 module capability graph（`:LtosGraph caps`，默认）
* [x] LtosTrace：

  * 输出 phase 执行时间（ASCII bar chart）
* [x] LtosIR：

  * 支持 `--stage`（`:LtosIR [stage]`）
* [x] LtosInfo：

  * 展示 cache hit/miss 统计

---

# 6. Layer 5（DSL / config）重构

## TODO-6.1 modules/lang DSL 版本化

* [x] schema 支持可选 `version` 字段（integer，warn if non-number）
* [x] 所有 lang modules 已声明 `version = 1`
* [x] 编译器版本兼容性校验：`CURRENT_SCHEMA_VERSION = 1`，高版本 warn，低版本静默接受

---

## TODO-6.2 DSL → 声明式约束强化

* [ ] 禁止：

  * 任意 Lua 逻辑
* [ ] 允许：

  * declarative only

---

## TODO-6.3 plugins 层去逻辑化

当前：

* opts 注入存在隐式逻辑

重构：

* [ ] plugins 仅：

```lua
{ "plugin/name", enabled=true }
```

* [ ] 所有 opts：

  * 由 codegen 注入

---

# 7. Cache + Incremental（重点优化）

## TODO-7.1 AST 增量编译

* [x] per-module content hash 记录在 `IR.meta.module_hashes`
* [x] AST tier 缓存读取路径：`try_ast_cache()` → `pipeline.run(cached_caps)` 跳过 collect
* [x] AST tier 缓存写入路径：full collect 后 `persist_ast_cache()`
* [x] `pipeline.run_sub()` 测试（`spec/runtime/pipeline_spec.lua`）
* [ ] dirty-only recompile（当前仍全量 normalize/resolve/optimize，仅 collect 可跳过）

---

## TODO-7.2 IR diff

* [x] 引入：

```lua
ir.diff(old, new)   -- returns { path, old, new }[]
ir.format_diff(changes)  -- human-readable string
```

用途：

* debug（`:LtosIR` 对比两次 run）
* cache validation（检测 IR 是否真正变化）

---

## TODO-7.3 Cache invalidation 精细化

* [ ] 当前：

  * tier invalidation

* [ ] 目标：

  * node-level invalidation

---

# 8. 测试体系（spec/）

## TODO-8.1 编译器级测试

* [x] golden test：

  * DSL → CapabilitySet snapshot（`spec/core/capability_spec.lua`）
* [x] IR snapshot test：collect/optimize stage shape + codegen pre-condition（`spec/runtime/pipeline_spec.lua`）
* [x] `ir.diff()` 测试：AST vs LIR 变化检测

---

## TODO-8.2 状态机测试

* [x] 非法 transition 测试（`spec/runtime/pipeline_spec.lua`）
* [x] debug_run 不影响 M.state() 测试
* [x] error recovery 测试：codegen pre-condition failure（`ir.validate(ir, "codegen")`）

---

## TODO-8.3 Cache 测试

* [x] 命中率测试（`spec/core/cache_spec.lua`）
* [x] invalidation correctness（cascade 测试）
* [x] 可序列化检查（metatable + _no_cache + function）

---

# 9. 性能优化（Startup SLA）

## TODO-9.1 profiling

* [x] 每 phase timing（`timings[phase.name]` in pipeline）
* [x] `LTOS_DEBUG=perf` → `vim.g.ltos_debug_perf` → 每 phase 实时 notify
* [ ] flamegraph（可选，需外部工具）

---

## TODO-9.2 lazy evaluation

* [ ] formatter fn 延迟注入
* [ ] LSP config lazy merge

---

# 10. 文档（README 对齐）

## TODO-10.1 README 与实现一致性

当前偏“理想模型”

* [ ] 标注：

  * 哪些是 guarantee
  * 哪些是目标

---

## TODO-10.2 Architecture.md → 形式化

* [x] 增加：

  * [x] 状态机转换表（完整 8 状态）
  * [x] IR schema 表（各阶段字段）
  * [x] phase contract 表（input/output state + IR 层）
  * [x] 缓存子模块职责表
---

---

# v4.1 已解决的核心问题

### ✅ 1. 不可变性已落地

* CapabilitySet 改为持久化值对象（`M.add(set, name, raw) -> new_set`）
* IR copy-on-write（`ir.with()` / `ir.clone()`）
* debug 模式 `util.freeze()` 防止 mutation

### ✅ 2. cache 已重构为编译器模型

* 内容 hash（FNV-1a）替代 mtime
* 三层子模块分离（key / store / policy）
* hit/miss 统计 + 细粒度 debug flag

### ✅ 3. adapter 边界已纯化

* adapters 无 vim API 调用
* emitter 层统一处理 side-effect

### ✅ 4. 状态机已显式化

* `new_sm()` 工厂，每次 run 独立实例
* 非法 transition → ERROR 状态

### ✅ 5. Phase 纯函数性已强化（本次修复）

* `normalize.lua` 移除 `vim.notify`，改用 IR diagnostics（Invariant 2 合规）
* `capability.lua` 移除 `vim.notify`，domain 层纯函数化（Invariant 2 合规）
* `collect.lua` 移除 `vim.notify`，所有错误通过 IR diagnostics 传播
* `optimize.lua` 移除 `vim.list_extend` / `vim.tbl_deep_extend`，改用 `util.deep_merge`（Invariant 2 合规）
* `runtime/init.lua` 修复双重 pipeline 运行 bug（AST cache 从 `run()` 返回的 IR 中提取）
* `builtin.lua` 策略改为完整 Strategy 对象（含 `applies` 字段，符合 TODO-4.1）
* `pipeline.run()` 返回 `(specs, ir)` 二元组，支持 AST cache 持久化
* TODO-0.3 debug JSON lines 输出已实现（`LTOS_DEBUG=trace`）
* `util.freeze` / `util.unfreeze` 修复 LuaJIT `__pairs` 不支持问题
* `ir_mod.with()` 使用 `util.unfreeze` 正确处理冻结代理

### ✅ 6. 测试矩阵已完善（本次补全）

* `spec/toolchain/rules_spec.lua` 新增（规则管道全覆盖）
* `spec/core/ir_spec.lua` 补全：`ir.transition()` / `ir.assert_stage()` / `ir.ctx()` / `ir.diff()` / `ir.format_diff()`
* `spec/core/pass_spec.lua` 补全：`run_with_ctx()` 三个测试
* `spec/core/cache_spec.lua` 补全：key 计算（content hash / schema version / determinism）
* `spec/core/schema_spec.lua` 补全：version 兼容性（TODO-6.1）/ SchemaDiagnostic.code
* `spec/toolchain/strategies_spec.lua` 补全：`applies` 字段 / `priority` / `stylua_or_lua_format` / `resolve()` 多分派
* `spec/runtime/pipeline_spec.lua` 补全：`run()` 返回二元组 / freeze 泄漏检测
* 总计：151 个测试，全部通过

### 🔄 7. 剩余待完成

* TODO-0.2：IR 字段命名规范（`caps` 跨阶段复用）— 重大重构，需谨慎
* TODO-2.2：各 pass 文件迁移到 `run(ctx) -> ctx` 签名
* TODO-7.1：dirty-only recompile（normalize 以下阶段的增量化）
* TODO-7.3：node-level cache invalidation
* TODO-6.2/6.3：DSL 声明式约束 + plugins 去逻辑化
* TODO-9.2：lazy evaluation（formatter fn 延迟注入 / LSP config lazy merge）
* TODO-10.1：README 对齐（标注 guarantee vs 目标）

---

# 优先级建议（剩余）

1. **TODO-2.2** 各 pass 迁移到 ctx 签名（基础设施完备，逐步迁移）
2. **TODO-7.1** dirty-only recompile（normalize 以下增量化）
3. **TODO-0.2** IR 字段命名规范（breaking change，需版本规划）
4. **TODO-9.2** lazy evaluation（启动性能优化）

