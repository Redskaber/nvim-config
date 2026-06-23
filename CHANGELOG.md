# CHANGELOG

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
