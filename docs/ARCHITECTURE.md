# ARCHITECTURE — nvim-config (LTOS) compiler kernel

> Source-of-truth architecture reference. Every claim below is verifiable in
> the actual Lua source. Chinese headers (matching CHANGELOG style), English
> for technical terms.

## 1. 总览 (Overview)

`init.lua` 仅两行:

```lua
require("core.kernel.bootstrap")  -- Layer 0: netrw/leader/LazyVim globals
require("config.lazy")            -- Layer 5: clone lazy.nvim → runtime.build() → lazy.setup()
```

`config/lazy.lua` 调用 `runtime.build()` 触发 LTOS 编译管线,产出 `LazySpec[]`
喂给 `lazy.setup()`。如果 build 崩溃,`pcall` 兜底使 nvim 仍可启动 (LazyVim 默认)。

LTOS 是一个七层分层编译器:声明式 DSL (语言/capability 模块) → 经 8-phase
管线编译 → 生成 lazy.nvim spec + 应用 cap 副作用。

## 2. 七层架构 (Seven-layer architecture)

依赖方向**严格单向向下**:高层可 `require` 低层,反之禁止。

| 层 | 目录 | 职责 | 禁止依赖 |
| ---- | ------ | ------ | ---------- |
| **L0 kernel** | `lua/core/kernel/` | 早期 bootstrap、leader、util (deep_copy/merge/hash/freeze) | compiler / domain / toolchain / runtime / vim API (除 bootstrap) |
| **L1 compiler** | `lua/core/compiler/` | IR 类型、Phase 接口、invariants、cache、ports | domain / toolchain / runtime / 任何 `vim.*` (除 `ports.lua`) |
| **L2 domain** | `lua/core/domain/` | 纯领域模型:`capability`、`diagnostic`、`ext_schema` | compiler / toolchain / runtime |
| **L3 toolchain** | `lua/toolchain/` | strategy 注册表与策略:`prefer_mason`、`prefer_system`、`conflict` | compiler / runtime / adapters / `vim.g` |
| **L4 runtime** | `lua/runtime/` | orchestrator:pipeline、phase_registry、passes、adapters、emitter、lifecycle、providers | (允许向下,但 passes/adapters 自身有纯度约束) |
| **L5 app/config** | `lua/config/`、`lua/plugins/` | lazy.nvim 启动、plugin spec 聚合 | runtime.adapters / runtime.pipeline (反向) |
| **L6 cap DSL** | `lua/modules/cap/`、`modules/ai/`、`modules/editor/`、`modules/keybind/` | 用户声明式 capability 模块 (`cap_type` + `version`) | runtime.pipeline / runtime.adapters |

L4 是 orchestrator 层,允许横跨下面各层组装数据流;但 L4 内部的 passes
与 adapters 自身仍受纯度约束 (见 §10)。

## 3. IR 子层 (IR sub-layers)

`ir.lua` 定义 IR 值类型 + `STAGES` enum。IR 不可变,所有变更走
copy-on-write (`ir.with` / `ir.clone` / `ir.append_diag`)。

```
AST   ─→  HIR   ─→  MIR   ─→  LIR   ─→  SPEC
```

| 子层 | 字段契约 | 由哪个 phase 产出 |
| ------ | ---------- | ------------------- |
| **AST** | `caps`, `meta`, `profile`, `ext_caps` | collect + collect_ext |
| **HIR** | + `symbols` (canonical symbol table) | normalize (注入 `FormatterNode.fn`) → canonicalize (建符号表) |
| **MIR** | + `resolved` (`{lsp, tools}`) | resolve (策略决定 use_mason) |
| **LIR** | + `merged_lsp`, `all_parsers` | optimize (dedup parsers / merge LSP configs) |
| **SPEC** | codegen 输入,字段完整 | codegen |

Stage 转换由 `STAGE_TRANSITIONS` 严格前进-only:
`AST→HIR→MIR→LIR→SPEC`。`ir.transition(ir)` 校验合法性,非法则 `error`。
`ir.assert_stage(ir, stage)` 在 phase 入口断言。运行时不变量检查目前仅限
INV-1 (COW identity),由 `invariants.check_phase_output` 执行
(需 `vim.g.ltos_debug_invariants = true` 启用);其余不变量
(INV-4/6 等) 由 `scripts/check_layer_boundaries.sh` 静态强制。

## 4. 八阶段编译管线 (8-phase compiler pipeline)

Phase 接口 (`pass.lua`):

```lua
---@class Phase
---@field name           string
---@field input_state    string   -- SM 输入态
---@field output_state   string   -- SM 输出态 (== input_state 即 side phase)
---@field run            fun(ir): IR
---@field validate?      fun(ir): Diagnostic[]   -- 前置条件
---@field output_validate? fun(ir): Diagnostic[] -- 后置条件 (P6-D2)
```

`pass.assert_valid(phase)` 在注册时强制校验必填字段。`run_phase` 流程:
freeze 输入 (debug) → `validate` 前置 → pcall `run` → invariant 检查 →
`output_validate` 后置 (失败降级为 warn,非致命,保持管线 additive)。

| # | Phase | input_state → output_state | IR in → IR out | 类型 |
| --- | ------- | --------------------------- | ---------------- | ------ |
| 1 | `collect` | idle → collecting | ∅ → AST | main |
| 1.5 | `collect_ext` | collecting → collecting | AST → AST (+ext_caps) | **side** |
| 2 | `normalize` | collecting → normalizing | AST → HIR (注入 `FormatterNode.fn`) | main |
| 2.5 | `canonicalize` | normalizing → canonicalizing | HIR → HIR (+symbols) | main |
| 3 | `resolve` | canonicalizing → resolving | HIR → MIR (+resolved) | main |
| 4 | `optimize` | resolving → optimizing | MIR → LIR (+merged_lsp, all_parsers) | main |
| 4.5 | `cap_resolve` | optimizing → optimizing | LIR → LIR (+cap_specs) | **side** |
| 5 | `codegen` | optimizing → codegen | LIR → SPEC | main (terminal) |

**Side phase** (`output_state == input_state`) 不触发 SM 转移 — 由
`next_sm_state_for(phase, current)` 返回 `nil` 实现。这是 FIX-P2-2 后的
单一真相源:Phase 的 `input_state`/`output_state` 决定 SM 行为,无需
额外维护 `PHASE_NEXT_SM` 表。

**Codegen 特例**:pipeline 不走 `run_phase`,直接 `pcall(codegen.build, ir)`
得到 `specs` (`LazySpec[]`)。`run` 仅为接口合规存在 (供 sub-pipeline 使用)。

Phase 排序由 `runtime/defaults/phases.lua` 声明,带 `after = { ... }` 依赖
和 `priority` tie-breaker。`phase_registry` 用 Kahn 拓扑排序解析最终顺序;
检测到环则回退到 priority 排序并 `ports.notify` 警告。`pipeline.PHASE_ORDER`
是 plain table,通过 listener 在 registry 每次变更时原地刷新 (LuaJIT 的
`#`/`ipairs` 不可靠地尊重 metatable proxy)。

## 5. 状态机 (State machines)

LTOS 有**两个独立** SM (INV-14):

### 5.1 Pipeline SM (`runtime/pipeline.lua`)

```
idle → collecting → normalizing → canonicalizing → resolving
     → optimizing → codegen → done        (+ error 任意态可达)
```

每次 `pipeline.run` 新建一个 SM 实例。`TRANSITIONS` 表枚举合法边;
非法转移 → `ports.notify(ERROR)` + 状态置 `error`。`last_run_sm` 保留
最后一次运行的状态供 `M.state()` 查询。

### 5.2 Lifecycle SM (`runtime/lifecycle.lua`)

```
BOOT → SCHEMA_LOAD → COMPILE → EMIT → READY
                                      ↓
                                  HOT_RELOAD → SCHEMA_LOAD (循环)
任何态 → ERROR (终态)
```

`runtime.build()` 驱动 lifecycle:READY 时若再次 build 会先转 `HOT_RELOAD`,
然后 `SCHEMA_LOAD` → `COMPILE` → `EMIT` → `READY`。支持 observer
(`lifecycle.observe(fn)`) 与时间戳查询 (`elapsed(state)`)。

两 SM 互不引用对方状态:lifecycle 不看 pipeline SM 是否 `done`,
pipeline SM 也不读 lifecycle 当前态。

## 6. 两层缓存 (Two-tier cache)

`core/compiler/cache/store.lua` 暴露两个 tier:

| Tier | 文件 | 内容 | 写入时机 |
|------|------|------|----------|
| `ast` | `<cache_dir>/ast_cache.json` | `{caps, ext_caps, module_hashes}` — collect 已验证的 cap 快照 | pipeline.run 完成后 `persist_ast_cache` |
| `spec` | `<cache_dir>/spec_cache.json` | `LazySpec[]` — codegen 最终产物 | pipeline.run 完成后 `persist_cache` |

**AST tier 加速路径**:`runtime.build()` 计算 per-module content hash,
比对缓存的 `module_hashes`:

- 全部匹配 → `skip`:跳过 collect/collect_ext,直接用 cached caps
- 部分匹配 → `partial`:作为 `ast_seed` 注入 `ir.meta`,collect 复用未变更模块
- 全部失配 → `full`:正常重跑

**Spec tier**:完整命中则跳过整个 pipeline,直接返回 cached specs。

### 缓存键

`cache/key.lua` 计算:

```
<hash>:<profile>:v<schema_version>
```

- `<hash>` = FNV-1a 32-bit (`util.hash` — LuaJIT fast path + pure-Lua fallback)
  对 `<sorted module path=hash list>` 拼接后的 composite 串再 hash
- `<profile>` = `"full"` 或 provider 注册的 profile
- `v<schema_version>` = `cache.version.SCHEMA_VERSION` (当前 = 7)

`SCHEMA_VERSION` 在 `ir.new()` 时也写入 `ir.meta.ir_version`,
`cache/policy.lua` 加载时校验一致性,版本不符则丢弃。

### 原子写入

`store.write` 流程:`ensure_cache_dir()` → JSON encode → 写 `path.tmp` →
`fs:close()` → `os.rename(tmp, path)` (POSIX `rename(2)` 原子)。崩溃只留
`.tmp` 孤儿,主缓存不破坏。`ensure_cache_dir` 默认走 libuv `fs_mkdir`
递归创建 (mode 0o755 = 493),无 shell 调用,无注入风险。

## 7. 十五条不变量 (15 invariants)

| ID | 描述 |
| ---- | ------ |
| INV-1 | IR 不可变 / copy-on-write — `run_phase` 检查返回的 IR ≠ 输入 IR;LIR 必有 `caps`/`resolved`/`merged_lsp`/`all_parsers` |
| INV-2 | Phase.run 纯函数 — 不得调用 `vim.notify` / `vim.api` / `vim.tbl_*` / `vim.deepcopy` / `vim.list_extend` |
| INV-3 | emitter 是唯一允许 `vim.notify` 的运行时模块 (ports.notify 抽象例外) |
| INV-4 | Strategy 无状态可替换 — 必有 `name`/`resolve`/`priority` 字段 |
| INV-5 | 层依赖单向向下 — 反向 require 被静态检查禁止 |
| INV-6 | IR stage 前进-only — `ir.transition()` + `STAGE_TRANSITIONS` 表强制 (非法转移即 `error`) |
| INV-7 | 缓存键基于内容 hash (FNV-1a),非 mtime |
| INV-8 | cap DSL 纯声明 — 模块 `return { cap_type=..., version=... }`,无副作用 |
| INV-9 | `BuildRequest` 是 passes 唯一的 vim.g 入口 (debug/UI knobs 集中) |
| INV-10 | compiler IO 必经 `ports` 抽象,不直接调 vim API |
| INV-11 | `ext_caps` 仅 `collect_ext` 可写 |
| INV-12 | cap DSL 经 `core/domain/ext_schema` 验证 |
| INV-13 | cap adapter 签名对称 + 纯函数 — `image`/`media`/`ai_cap`/`keybind` adapter 不得调 `vim.*` |
| INV-14 | 双 SM (pipeline / lifecycle) 互相独立 |
| INV-15 | `toolchain/strategy/conflict.lua` 不得 mutate strategy registry |

## 8. Ports 抽象 (Ports abstraction)

`core/compiler/ports.lua` 是 L1 与宿主 (nvim) 之间的依赖反转层。
L1 不直接调 `vim.*`,而是调用 ports 上的函数,默认实现是 no-op / error:

| Port | 默认 | vim 实现 (`ports_bootstrap.setup()`) |
| ------ | ------ | -------------------------------------- |
| `cache_dir()` | `".cache/ltos"` | `vim.fn.stdpath("cache") .. "/ltos"` |
| `json_encode(t)` | `error` | `vim.json.encode` |
| `json_decode(s)` | `error` | `vim.json.decode` |
| `read_file(path)` | `nil` | `io.open` + `read("*a")` |
| `resolve_runtime_file(rel)` | `nil` | `vim.api.nvim_get_runtime_file(rel, false)[1]` |
| `debug_cache()` | `false` | `vim.g.ltos_debug or vim.g.ltos_debug_cache` |
| `notify(level, msg)` | no-op | `vim.notify(msg, level)` |
| `ensure_cache_dir(dir)` | libuv `fs_mkdir` 递归 | `vim.fn.mkdir(dir, "p")` |

`ports.configure(opts)` 注入实现;`runtime/init.lua` 在加载首行调用
`ports_bootstrap.setup()` 一次性注入。L1 测试可在不 mock vim 的情况下
替换 ports。该模式即依赖反转:L1 定义抽象接口,L4 提供具体实现。

## 9. Plugin 自动发现 (Plugin auto-discovery)

`lua/plugins/init.lua` 是 lazy.nvim `{ import = "plugins" }` 的入口:

1. `vim.fn.globpath(vim.o.rtp, "lua/plugins/**/*.lua", true, true)` 递归收集
2. `table.sort` 保证加载顺序确定性
3. 对每个文件:
   - 跳过 `init.lua` (本聚合文件)
   - 跳过 basename 以 `_` 开头的文件 (约定:helper/private)
   - `pcall(require, modname)` 加载
   - 检查返回值是否是 LazySpec:`result[1]` 为 string (单 spec) 或 table
     (spec 列表) — 否则视作库模块静默跳过
   - 单 spec 直接 `specs[#specs+1] = result`;spec 列表 flatten

约定明确:helper 模块要么 `_` 前缀,要么不返回 table (`local M = {}; return M`)。

## 10. Phase Module Pattern

`pipeline.resolve_phase(mod_path)` 处理两种模块形态:

```lua
local function resolve_phase(mod_path)
  local mod = require(mod_path)
  if type(mod) == "table" and mod.pass ~= nil then
    return mod.pass            -- sub-pass: 模块包了一层 .pass
  end
  return mod                   -- main pass: 直接返回 Phase table
end
```

| 形态 | 例子 | 原因 |
|------|------|------|
| 直接 return Phase table | `collect.lua`、`normalize.lua`、`canonicalize.lua`、`resolve.lua`、`optimize.lua`、`codegen.lua` | 模块即 pass,简洁 |
| `M.pass = {...}` + 其他导出 | `collect_ext.lua` (有 `register`/`registered`/`setup`)、`cap_resolve.lua` | 模块既有 pass 又有伴随 API (注册函数、setup hook) |

`runtime/init.lua` 调用 `collect_ext.setup()` 显式注册默认 cap 模块
(P6-C2 模式:no require-time side effects)。`pipeline.lua` 是例外 —
它在 require-time 调 `register_default_phases()`,因为它是 orchestrator
而非 pluggable registry,且测试套件依赖 `package.loaded` reload 模式
(规则 7c 排除 pipeline.lua)。

## 11. 层边界静态检查 (Layer boundary enforcement)

`scripts/check_layer_boundaries.sh` 是 CI 守门脚本,使用 `grep` 模式匹配
(排除 `--` 注释行)。规则分四类:

### 11.1 前向依赖 (forward)

禁止以下 require (高层 → 更高):

- `core/kernel` → `core.compiler`
- `core/compiler` → `core.domain`
- `core/domain` → `toolchain`
- `toolchain` → `runtime.adapters`
- `modules` → `runtime.pipeline` / `runtime.adapters`
- `config` → `runtime.adapters` / `runtime.pipeline`
- `plugins` → `runtime.adapters` / `runtime.pipeline`

### 11.2 反向依赖 (reverse)

- `toolchain` → `core.compiler`
- `modules/capability` → `core.compiler`
- `core/domain` → `core.compiler`

### 11.3 纯度约束 (phase / adapter / compiler purity)

- `env.lua` 不得含 `prefer_system` (移至 `rules.lua`)
- `runtime/adapters/*.lua` 不得调 `vim.notify` (emitter 层负责副作用)
- `core/domain/capability.lua` 不得有 module-level `_store`
- `runtime/passes/*.lua` 不得在 `Phase.run` 中调:
  `vim.notify`、`vim.api`、`vim.tbl_extend`、`vim.deepcopy`、
  `vim.tbl_deep_extend`、`vim.list_extend`、`vim.g`
- `runtime/passes/*.lua` 不得在模块顶层调 `*.register()` (require-time
  side effect) — `pipeline.lua` 豁免 (规则 7c)
- `core/compiler/**/*.lua` (除 `ports.lua`) 不得调 `vim.*`
- `toolchain/**` 不得读 `vim.g`
- INV-11:除 `collect_ext.lua` 外,任何 pass 不得赋值 `ext_caps`
- INV-13:`adapters/image.lua`、`media.lua`、`ai.lua`、`ai_cap.lua`、
  `keybind.lua` 不得调 `vim.*`
- INV-15:`toolchain/strategy/conflict.lua` 不得调 `StrategyRegistry` /
  `registry.register`

### 11.4 孤儿 + 约定检测 (orphan / convention)

WARN (非 FAIL):

- `runtime/adapters/*.lua` (除 `registry`/`cap_registry`) 未在
  `defaults/adapters.lua` 或 `defaults/cap_adapters.lua` 中注册
- `runtime/passes/*.lua` 未在 `defaults/phases.lua` 中注册
- `plugins/**/*.lua` (非 `init.lua`、非 `_` 前缀) 不 `return {` — 若是
  helper 应改名为 `_<name>.lua`
- `modules/{cap,editor,ai,keybind}/*.lua` (非 `_` 前缀) 缺 `cap_type`
  字段 — 若是 helper 应加 `_` 前缀

## 12. 启动序列 (Startup sequence)

`config/lazy.lua`:

1. 检查 `lazy.nvim` 是否已 clone 至 `stdpath("data")/lazy/lazy.nvim`,
   否则 `git clone --filter=blob:none --branch=stable`
2. `vim.opt.rtp:prepend(lazypath)`
3. `require("runtime")` → 触发 `ports_bootstrap.setup()` +
   `types_bootstrap.setup()` + 两个 registry 的 `setup()` +
   `collect_ext.setup()`
4. `pcall(runtime.build)`:
   - lifecycle 推进 `BOOT → SCHEMA_LOAD → COMPILE`
   - 尝试 spec tier 缓存命中 → 直接 `EMIT → READY`
   - 否则尝试 ast tier 命中 → `pipeline.run(modules, profile, cached_caps, ast_seed, req)`
   - `EMIT` → `emitter.cap_effects.apply_all(ir)` 应用 cap 副作用
   - 持久化 spec + ast 缓存 → `READY`
5. `User Verylazy` autocmd → `runtime.setup_commands()`
6. `lazy.setup(config_provider.build_setup_opts(lang_specs))`:
   合并 spec providers (`LazyVim` + `plugins` import + lang_specs),
   配置 `checker` (opt-in via `vim.g.ltos_auto_update`)、`performance.rtp`
   禁用 builtin 插件、`lockfile = stdpath("state")/lazy-lock.json`

## 13. 关键文件索引 (Key file index)

| 路径 | 角色 |
| ------ | ------ |
| `init.lua` | L0 入口 (2 行) |
| `lua/core/kernel/bootstrap.lua` | netrw off / leader / `lazyvim_file_explorer=snacks` / `ltos_auto_update=false` |
| `lua/core/compiler/ir.lua` | IR 类型 + STAGES enum + transition/validate/diff |
| `lua/core/compiler/pass.lua` | Phase 接口 + `run_phase` / `run_with_ctx` |
| `lua/core/compiler/ports.lua` | 注入式 IO 端口 |
| `lua/core/compiler/invariants.lua` | INV-1/4/6 运行时检查 |
| `lua/core/compiler/cache/{key,store,version,policy}.lua` | 缓存键/存储/版本/策略 |
| `lua/runtime/pipeline.lua` | 8-phase 编排 + pipeline SM |
| `lua/runtime/phase_registry.lua` | Phase 注册 + 拓扑排序 + listener |
| `lua/runtime/lifecycle.lua` | lifecycle SM (BOOT→READY) |
| `lua/runtime/defaults/phases.lua` | 8 个 phase 声明式注册 |
| `lua/runtime/adapters/registry.lua` | codegen backend 注册 |
| `lua/runtime/providers/config.lua` | `lazy.setup()` 选项合成 |
| `lua/config/lazy.lua` | lazy.nvim bootstrap + `runtime.build()` 调用 |
| `lua/plugins/init.lua` | plugin spec globpath 自动发现 |
| `scripts/check_layer_boundaries.sh` | 层边界 + 纯度静态检查 |

---

*Document version: 1.0 · synced with source as of v5.5.0.*
