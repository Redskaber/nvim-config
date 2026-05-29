# LTOS v4 Architecture Audit Report

> 审查维度：依赖倒置 · 管道流 · 层级化 · 增量模式 · 策略管理 · 状态机 · 生命周期管理 · 边界明确 · 数据驱动 · 通信协议 · 插件插拔

**状态：已修复（2026-05-29）** — 见文末「验证」与 `just test`。

---

## 一、硬编码违规（Hardcoded Violations）

### V-01 · `runtime/init.lua` — `LANG_MODULES` 写死 ✅

**修复**：`runtime/providers/interface.lua`（`ModuleProvider.discover`）+ `runtime/providers/registry.lua`（`ProviderRegistry`）。`runtime.lang_modules()` 为注册结果；`LANG_MODULES` 保留为向后兼容代理。

---

### V-02 · `runtime/passes/codegen.lua` — `ADAPTERS` 写死 ✅

**修复**：`runtime/adapters/registry.lua`（`AdapterRegistry`）。codegen 调用 `registry.emit_all(ir)`。

---

### V-03 · `runtime/adapters/mason.lua` — `BASE_TOOLS` 写死 ✅

**修复**：默认保留 `codespell`；可通过 `vim.g.ltos_base_mason_tools` 覆盖。

---

### V-04 · `runtime/adapters/treesitter.lua` — `BASE_PARSERS` 写死 ✅

**修复**：默认列表在 adapter 内；可通过 `vim.g.ltos_base_parsers` 覆盖。

---

### V-05 · `config/lazy.lua` — lazy.setup() spec 结构写死 ✅

**修复**：`runtime/providers/config.lua`（`ConfigProvider`）数据驱动组合 spec。

---

### V-06 · `config/lazy.lua` — `disabled_plugins` 写死 ✅

**修复**：可通过 `vim.g.ltos_disabled_plugins` 覆盖；默认在 `ConfigProvider` 内。

---

### V-07 · `toolchain/rules.lua` — 直接读 `vim.g`（Layer 3 违规）✅

**修复**：`rules.resolve(tool, overrides)` 由 Layer 4 `canonicalize` / `mason` 注入 overrides。

---

### V-08 · `runtime/commands.lua` — `PHASE_ORDER` 重复定义 ✅

**修复**：`pipeline.PHASE_ORDER` 为单一真相源；commands 引用之。

---

## 二、耦合气味（Coupling Smells）

### S-01 · `runtime/api.lua` — picker/terminal 后端名称写死 ✅

**修复**：`api.picker_register` / `api.picker_set_default`；`vim.g.ltos_picker_backend` 可选。

---

### S-02 · `core/domain/schema.lua` — `_code_seq` 模块级可变计数器 ✅

**修复**：诊断码由 `path` 哈希确定性生成，测试幂等。

---

### S-03 · cache key / policy 版本号重复 ✅

**修复**：统一到 `core/compiler/cache/version.lua`。

---

### S-04 · `toolchain/mappings.lua` — 无运行时扩展点 ✅

**修复**：`register_lsp` / `register_tool` / `register_override` API。

---

### S-05 · `core/kernel/env.lua` — 无扩展点 ✅

**修复**：`register_fact(name, fn)` 延迟求值 API。

---

## 三、缺失抽象（Missing Abstractions）

| 编号 | 抽象 | 状态 | 实现 |
|------|------|------|------|
| M-01 | ModuleProvider | ✅ | `runtime/providers/interface.lua` |
| M-02 | AdapterRegistry | ✅ | `runtime/adapters/registry.lua` |
| M-03 | ProviderRegistry | ✅ | `runtime/providers/registry.lua` |
| M-04 | icons ft/file 表 | ⏳ | 仍为 diagnostics/git/todo；可后续扩展 |
| M-05 | ConfigProvider | ✅ | `runtime/providers/config.lua` |

---

## 四、优化目标（Optimization Targets）

### O-01 · `ir.diff()` 未接入增量缓存失效 ✅（部分）

AST tier 现存储 `{ caps, module_hashes }`；`init.lua` 按 per-module hash 选择 skip / partial / full collect；`collect` pass 支持 `ast_seed` 增量复用。

### O-02 · `env.lua` 检测结果惰性求值 ✅

内置 fact 通过 `register_fact` + metatable 首次访问时求值并 memoise。

### O-03 · `pipeline.run()` 返回值签名不对称 ✅

`debug_run()` 现返回 `(ir, specs|nil)`。

---

## 五、修复优先级（原始）

| 优先级 | 编号 | 工作量 | 状态 |
|--------|------|--------|------|
| P0 | V-07 | 小 | ✅ |
| P0 | S-02 | 小 | ✅ |
| P0 | S-03 | 极小 | ✅ |
| P1 | V-01 | 中 | ✅ |
| P1 | V-02 | 中 | ✅ |
| P1 | S-04 | 小 | ✅ |
| P1 | S-05 | 小 | ✅ |
| P2 | V-03/V-04 | 小 | ✅ |
| P2 | V-05/V-06 | 中 | ✅ |
| P3 | O-01 | 大 | ✅（增量 AST） |

---

## 六、验证

```bash
just check   # 层边界
just test    # 12 项 headless 集成测试
```

新增/扩展文件：

- `lua/core/compiler/cache/version.lua`
- `lua/runtime/providers/{interface,registry,config}.lua`
- `lua/runtime/adapters/registry.lua`
- `scripts/ltos_tests.lua`
- `scripts/run_ltos_tests.sh`
