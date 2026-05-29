# LTOS v4 架构审查报告

> 审查维度：依赖倒置 · 管道流 · 层级化 · 增量模式 · 策略管理 · 状态机 · 生命周期管理 · 边界明确 · 数据驱动 · 通信协议 · 插件插拔  
> 最后更新：2026-05-29

---

## 状态总览

| 阶段 | 范围 | 状态 |
|------|------|------|
| v4 初版修复 | V-01~V-08, S-01~S-05, M-01~M-05, O-01~O-03 | ✅ 已完成 |
| P0 契约对齐 | BuildRequest、两级缓存、nix profile、文档同步 | ✅ 已完成 |
| P1 确定性与 L1 纯化 | ir.diag、cache port、边界检查扩展 | ⏳ 待做 |
| P2 可扩展性 | PhaseRegistry、defaults 外置、icons M-04 | ⏳ 待做 |
| P3 深度优化 | 可序列化 HIR、ir.diff 接入、细粒度 spec/ | ⏳ 待做 |

验证：`just check` · `just test`

---

## 一、架构模型

### 1.1 六层 + 单向依赖

```
Layer 5  app/config/modules   纯 DSL · LazyVim 配置
    ↓
Layer 4  runtime               编排 · 管道 · 适配器 · BuildRequest 入口
    ↓
Layer 3  toolchain             rules 管道 · strategy · mappings
    ↓
Layer 2  domain                schema · capability · icons
    ↓
Layer 1  compiler              IR · pass · cache-policy
    ↓
Layer 0  kernel                bootstrap · env facts · util
```

### 1.2 编译管道 + 状态机

```
IDLE → COLLECTING → NORMALIZING → CANONICALIZING → RESOLVING → OPTIMIZING → CODEGEN → DONE
```

| Phase | IR 子层 | 输出 |
|-------|---------|------|
| collect | AST | `caps`, `module_hashes` |
| normalize | HIR | `FormatterNode.fn` |
| canonicalize | HIR+ | `ir.symbols` |
| resolve | MIR | `ir.resolved` |
| optimize | LIR | `merged_lsp`, `all_parsers` |
| codegen | SPEC | `LazySpec[]` via AdapterRegistry |

### 1.3 注册中心（依赖倒置）

| 注册表 | 路径 | 扩展 API |
|--------|------|----------|
| ModuleProvider | `runtime/providers/interface.lua` | `discover()` |
| ProviderRegistry | `runtime/providers/registry.lua` | `register`, `register_filter` |
| AdapterRegistry | `runtime/adapters/registry.lua` | `register(path, opts)` |
| ConfigProvider | `runtime/providers/config.lua` | `register_spec(fn)` |
| StrategyRegistry | `toolchain/strategy/registry.lua` | `register(name, fn)` |
| Mappings | `toolchain/mappings.lua` | `register_lsp/tool/override` |
| Env Facts | `core/kernel/env.lua` | `register_fact(name, fn)` |
| API Backends | `runtime/api.lua` | `picker_register`, `terminal_register` |

### 1.4 BuildRequest（P0 编排契约）

**唯一 `vim.g` 读取点**：`runtime/build_request.lua` ← 由 `runtime/init.lua` 调用。

```lua
---@class BuildRequest
---@field profile       string
---@field modules       string[]
---@field overrides     table
---@field prefer_system boolean   -- profile == "nix"
---@field base_tools    string[]
---@field base_parsers? string[]
```

注入路径：`init.build()` → `pipeline.run(..., req)` → `ir.meta.build_request` → passes / adapters。

### 1.5 两级增量缓存（P0 诚实模型）

```
cache key = FNV-1a(sorted file content hashes) + ":" + profile + ":v4"

Spec Tier (spec_cache.json)  ← 命中 → 跳过全部 pipeline
AST Tier  (ast_cache.json)   ← 命中 → skip/partial/full collect
```

**已移除 IR tier**：HIR 含 `FormatterNode.fn` 闭包，不可序列化。原 `ir_cache.json` 不再写入。

失效传播：`ast` 失效 → `spec` 同步失效。

---

## 二、设计原则评分

| 原则 | 评分 | 说明 |
|------|------|------|
| 依赖倒置 | ★★★★☆ | Registry + BuildRequest；phase 列表仍硬编码 |
| 管道流 | ★★★★★ | 6 phase 清晰，sub-pipeline 可组合 |
| 层级化 | ★★★★☆ | CI 检测 toolchain；L1 cache IO 仍有 vim 泄漏 |
| 增量模式 | ★★★★☆ | AST per-module 增量；`ir.diff` 未接入失效 |
| 策略管理 | ★★★★☆ | rules 管道 + nix profile 规则 |
| 状态机 | ★★★★★ | 完整 TRANSITIONS + 非法转换保护 |
| 生命周期 | ★★★★☆ | 每次 run 独立 SM；timings 写 `vim.g` |
| 边界明确 | ★★★★☆ | BuildRequest 收敛后明显改善 |
| 数据驱动 | ★★★★☆ | 默认值可 `vim.g` 覆盖，集中在 BuildRequest |
| 插件插拔 | ★★★★☆ | adapter/module/config 可扩展 |

---

## 三、已修复项（v4 + P0）

### 硬编码违规

| 编号 | 问题 | 修复 |
|------|------|------|
| V-01 | `LANG_MODULES` 写死 | `ModuleProvider.discover()` + `ProviderRegistry` |
| V-02 | `ADAPTERS` 写死 | `AdapterRegistry.emit_all()` |
| V-03 | `BASE_TOOLS` 写死 | `BuildRequest.base_tools` |
| V-04 | `BASE_PARSERS` 写死 | `BuildRequest.base_parsers` |
| V-05 | lazy spec 写死 | `ConfigProvider` |
| V-06 | `disabled_plugins` 写死 | `vim.g.ltos_disabled_plugins` / ConfigProvider |
| V-07 | rules 读 `vim.g` | `rules.resolve(tool, overrides, ctx)` |
| V-08 | `PHASE_ORDER` 重复 | `pipeline.PHASE_ORDER` 单一真相源 |

### 耦合气味

| 编号 | 问题 | 修复 |
|------|------|------|
| S-01 | picker 后端写死 | `picker_register` / `ltos_picker_backend` |
| S-02 | schema `_code_seq` | path-hash 确定性诊断码 |
| S-03 | 版本号重复 | `cache/version.lua` |
| S-04 | mappings 无扩展 | `register_lsp/tool/override` |
| S-05 | env 无扩展 | `register_fact` |

### P0 契约对齐（2026-05-29）

| 编号 | 任务 | 实现 |
|------|------|------|
| P0-1 | BuildRequest 收敛 `vim.g` | `runtime/build_request.lua` |
| P0-2 | 移除 IR tier | `cache/store.lua`, `cache/policy.lua` |
| P0-3 | nix profile 语义 | `register_filter("nix")` + `prefer_system` rules |
| P0-4 | 文档同步 | 本文件 · Architecture.md · Invariants · README |

---

## 四、剩余差距（待 P1–P3）

### 4.1 不变量与实现偏差

| 项 | 文档 | 实际 | 优先级 |
|----|------|------|--------|
| L1 cache IO 用 vim | "no vim API" | `store.lua` 用 `vim.fn.stdpath` | P1 |
| `ir.diag` 计数器 | Inv 2 纯函数 | `_diag_seq` 仍可变 | P1 |
| Adapter 不调 vim | Inv 3 | adapters 仅读 `ir.meta`，已去除 `vim.g` | ✅ P0 |
| Phase 读 vim.g | Inv 2 | canonicalize 已改读 BuildRequest | ✅ P0 |
| M-04 icons | ft/file 表 | 仍分散在 plugins/ui | P2 |

### 4.2 仍集中写死的默认值

| 位置 | 内容 | 建议 |
|------|------|------|
| `pipeline.lua:13-19` | PHASES require 列表 | PhaseRegistry |
| `adapters/registry.lua` | 5 adapter + priority | `runtime/defaults/adapters.lua` |
| `providers/registry.lua:12-14` | CORE_MODULES | module 元数据 `core=true` |
| `mappings.lua` | LSP/tool 映射表 | `toolchain/defaults/*.lua` |
| `api.lua` | terminal `"toggleterm"` 默认 | `terminal_set_default` |

### 4.3 未接入能力

| 能力 | 状态 |
|------|------|
| `ir.diff()` 缓存校验 | 仅 `:LtosDiff` |
| HIR/IR tier 缓存 | 已移除（不可序列化） |
| `spec/` 测试目录 | 使用 `scripts/ltos_tests.lua` |

---

## 五、Profile 语义

| Profile | 模块集 | 工具策略 |
|---------|--------|----------|
| `full` | 全部 discovered | rules 默认管道 |
| `minimal` | 仅 `modules.lang.lua_lang` | 同上 |
| `nix` | 同 full | `prefer_system=true`：PATH 有则不用 mason |

`env.is_nix` 仍作为独立规则（`nix_env_rule`），与 profile 互补。

---

## 六、工具链解析优先级

```
用户覆盖 (BuildRequest.overrides / mappings.overrides)
    → profile nix: prefer_system + env.has(tool)
    → system_tools 白名单
    → Nix 主机: env.is_nix + env.has(tool)
    → 显式映射 (tool_to_mason)
    → Identity 回退
```

---

## 七、优化路线图

### P1 — 确定性与 L1 纯化

1. `ir.diag` 改为 path-hash 确定性编码
2. cache IO 端口注入（`core/compiler/ports.lua`）
3. `api.terminal_set_default` 对称 picker API
4. 扩展 `check_layer_boundaries.sh`：pass `vim.g`、compiler `vim.fn`

### P2 — 可扩展性

5. `PhaseRegistry` 替代 pipeline 硬编码 phase 列表
6. `runtime/defaults/*.lua` 外置大表
7. M-04：`icons.lua` ft/file/extension 表
8. module `core=true` 元数据替代 CORE_MODULES

### P3 — 深度优化

9. normalize 输出可序列化策略引用 → 未来可解锁 IR cache
10. `ir.diff` 接入 debug 缓存校验
11. 拆分细粒度 `spec/` 测试套件

---

## 八、验证

```bash
just check   # 层边界（含 toolchain vim.g）
just test    # headless 回归（BuildRequest · nix · 两级缓存）
```

关键文件：

- `lua/runtime/build_request.lua` — P0 编排契约
- `lua/runtime/providers/{interface,registry,config}.lua`
- `lua/runtime/adapters/registry.lua`
- `lua/core/compiler/cache/version.lua`
- `scripts/ltos_tests.lua` · `scripts/run_ltos_tests.sh`
