# LTOS v4 — TODO / 工程任务跟踪

> 状态标记：✅ 已完成  🔄 进行中  ⬜ 待实现

---

## Phase 0 — Mapping & Canonical Layer

### TODO-0.1 统一 symbol 映射层 ✅
- [x] `toolchain/mappings.lua` 作为唯一真相源（SSOT）
- [x] `lsp_to_mason` / `tool_to_mason` 完整覆盖所有 lang modules
- [x] `system_tools` 清理（移除 `false` 条目，只保留 `true`）
- [x] adapters 禁止直接访问 mapping 表（通过 ir.symbols）

### TODO-0.2 canonicalize pass ✅
- [x] `runtime/passes/canonicalize.lua` 实现
- [x] 输入 HIR，输出 HIR + ir.symbols
- [x] 未映射 symbol → info diagnostic
- [x] state contract 注释修正（NORMALIZING → CANONICALIZING）

---

## Phase 1 — IR 契约强化

### TODO-1.1 明确 IR schema ✅
- [x] `STAGE_REQUIRED` 表定义各阶段必须字段
- [x] `ir.validate(ir, stage)` 实现
- [x] `ir.transition()` / `ir.assert_stage()` 实现
- [x] `ir.new()` / `ir.with()` / `ir.clone()` copy-on-write

### TODO-1.2 禁止 adapter 推断逻辑 ✅
- [x] adapters 只读 IR，不做 fallback 推断
- [x] mason adapter fallback 路径补全（formatter/linter tools）

---

## Phase 2 — Adapter 纯函数化

### TODO-2.1 mason adapter 防御性编程 ✅
- [x] 跳过 nil mapping
- [x] 使用 ir.symbols 作为唯一来源

### TODO-2.2 conform adapter schema 校验 ✅
- [x] FormatterNode 无 fn 且无 name 时 emit `_ltos_warn` marker（不静默丢弃）
- [x] emitter 层负责 surface warnings

---

## Phase 3 — Pipeline 架构

### TODO-3.1 run_sub() 子流水线 ✅
- [x] `pipeline.run_sub(phases, ir)` 实现
- [x] 独立于主 SM，无状态污染

### TODO-3.2 状态机强化 ✅
- [x] 状态不可逆（TRANSITIONS 表）
- [x] 非法 transition → ERROR 状态 + vim.notify
- [x] 每 phase 校验 input_state（通过 Phase.validate）

---

## Phase 4 — 增量编译

### TODO-4.1 AST per-module cache ✅
- [x] module content hash 计算（FNV-1a）
- [x] `ir.meta.module_hashes` 记录每模块 hash
- [x] AST tier cache 命中 → 跳过 collect phase
- [x] `pipeline.run(modules, profile, cached_caps)` 接受注入 caps

### TODO-4.2 IR structural sharing ⬜
- [ ] normalize / resolve 避免 deep copy 全量
- [ ] 使用 persistent data structure 思想（低优先级）

---

## Phase 5 — Strategy 系统

### TODO-5.1 strategy 生命周期 ✅
- [x] bootstrap → register → lock
- [x] 禁止 runtime 动态修改（lock 后 register 抛错）

### TODO-5.2 strategy 类型系统 ✅
- [x] formatter strategy（ruff_or_black / prettierd_or_prettier / stylua_or_lua_format）
- [x] Strategy interface 定义（interface.lua）
- [x] applies / resolve / priority 字段

---

## Phase 6 — 可观测性

### TODO-6.1 IR diff 工具 ✅
- [x] `ir.diff(old, new)` 实现
- [x] `ir.format_diff(changes)` 实现
- [x] `:LtosDiff [stage_a] [stage_b]` 命令注册

### TODO-6.2 trace 标准化 ✅
- [x] `vim.g.ltos_debug_trace` → JSON line emit
- [x] `:LtosTrace` ASCII bar chart

---

## Phase 7 — 错误系统

### TODO-7.1 统一 Diagnostic 类型 ✅
- [x] `Diagnostic.code` 字段（机器可读，E/W/I 前缀）
- [x] `SchemaDiagnostic.code` 字段（S 前缀）
- [x] `ir.diag_counts()` / `ir.format_diagnostics()`

### TODO-7.2 错误分层 ✅
- [x] schema error（collect）
- [x] semantic error（normalize — unknown strategy warn）
- [x] resolution error（resolve — symbols missing）

---

## Phase 8 — API 边界

### TODO-8.1 runtime/api.lua 作为唯一 facade ✅
- [x] format / find_files / live_grep / buffers / recent_files / help_tags
- [x] diagnostics / lsp / terminal / ui namespaces
- [x] pluggable terminal backend

### TODO-8.2 禁止外部 require adapters ✅
- [x] boundary check 脚本增加 `modules/*` / `config/*` / `plugins/*` → `runtime/adapters` 检测

---

## Phase 9 — 配置 DSL（长期）

### TODO-9.1 lang module schema formalization ⬜
- [ ] JSON Schema / Lua schema 自动校验工具
- [ ] `version` 字段强制要求（当前为可选）

---

## 测试矩阵

| 测试文件                              | 覆盖范围                          | 状态 |
| ------------------------------------- | --------------------------------- | ---- |
| `spec/core/util_spec.lua`             | dedup/merge/hash/freeze/deep_copy | ✅   |
| `spec/core/ir_spec.lua`               | IR COW / diag / transition / diff | ✅   |
| `spec/core/pass_spec.lua`             | Phase interface / run_with_ctx    | ✅   |
| `spec/core/schema_spec.lua`           | DSL validator / version compat    | ✅   |
| `spec/core/capability_spec.lua`       | CapabilitySet COW / snapshot      | ✅   |
| `spec/core/cache_spec.lua`            | 三层缓存 / 失效传播 / stats       | ✅   |
| `spec/toolchain/mappings_spec.lua`    | lsp_pkg / tool_pkg / resolve      | ✅   |
| `spec/toolchain/rules_spec.lua`       | 规则链优先级                      | ✅   |
| `spec/toolchain/strategies_spec.lua`  | registry / builtin / lock         | ✅   |
| `spec/runtime/canonicalize_spec.lua`  | symbol 规范化 / 去重              | ✅   |
| `spec/runtime/resolve_spec.lua`       | ir.symbols → ir.resolved 投影    | ✅   |
| `spec/runtime/optimize_spec.lua`      | parser dedup / LSP deep-merge     | ✅   |
| `spec/runtime/codegen_spec.lua`       | 5 adapters / LazySpec 契约        | ✅   |
| `spec/runtime/normalize_spec.lua`     | normalize pass / fn 注入 / COW    | ✅   |
| `spec/runtime/pipeline_spec.lua`      | 全流水线集成 / SM / COW           | ✅   |
| `spec/runtime/commands_spec.lua`      | 用户命令注册 / 参数校验           | ✅   |

---

## 已知限制 / 不在范围内

- `plugins/` 层配置不允许修改（架构约束）
- `TODO-4.2` IR structural sharing 为低优先级优化
- `TODO-9.1` JSON Schema 工具为长期目标
