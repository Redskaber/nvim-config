# 贡献指南 (CONTRIBUTING)

> nvim-config onboarding 指南。项目采用 LTOS 分层架构 (Layer 0 kernel → Layer 5 app → Layer 6 runtime)，
> 所有贡献须通过 `just check` + `just test` 才能合入。

---

## 1. 开发环境

进入 Nix dev-shell（提供 `nvim`、`lua`、`just`、`stylua`）：

```bash
nix develop        # 所有 toolchain 就绪
```

常用 `just` 命令（见 `justfile`）：

| 命令                     | 作用                                                |
| ------------------------ | --------------------------------------------------- |
| `just check`             | 运行 `scripts/check_layer_boundaries.sh` 静态检查   |
| `just test`              | 跑完整 spec catalogue（全部 suite）                 |
| `just test-suite <name>` | 指定 suite：`core`/`modules`/`runtime`/`toolchain`/`integration` |
| `just test-file <path>`  | `nvim --headless -l <file>` 跑单个 spec              |
| `just test-tags <tags>`  | 按 tag 过滤（`unit`/`integration`/`slow`/...）       |
| `just test-ff`           | `--fail-fast`，首次失败即停止                        |
| `just ci`                | `check && test`，CI 入口                             |

> Workflow：写代码 → `just check` → `just test-file spec/<area>/xxx_spec.lua`
> → `just test-suite <area>` → `just test`。

---

## 2. 如何添加 Language Module

**位置**：`lua/modules/lang/<name>.lua`

**必填字段**（见 `lua/modules/lang/lua.lua`）：

| 字段         | 类型       | 说明                                   |
| ------------ | ---------- | -------------------------------------- |
| `version`    | `number`   | DSL schema 版本，当前 `1`              |
| `treesitter` | `string[]` | treesitter parser 列表                 |
| `lsp`        | `table`    | `{ server_name = { settings = {...} } }` |
| `formatters` | `table`    | `{ filetype = { "formatter_name" } }`  |
| `linters`    | `table`    | `{ filetype = { "linter_name" } }`     |
| `mason`      | `string[]` | 需通过 Mason 安装的工具                |

**可选**：`core = true` 表示该 module 进入 minimal profile（如 `lua.lua` 是 P2 core）。

**DSL 纯度 (INV-8)**：必须 `return { ... }` 一个**普通 table**，不允许 metatable、
不允许 module-level side effect、不允许 `require("runtime.*")`。

**Skeleton**：

```lua
-- lua/modules/lang/rust.lua
return {
  core = false, version = 1,
  treesitter = { "rust" },
  lsp = { rust_analyzer = {
    settings = { ["rust-analyzer"] = { checkOnSave = { command = "clippy" } } } } },
  formatters = { rust = { "rustfmt" } },
  linters    = { rust = { "cargo" } },
  mason      = { "rustfmt", "codelldb" },
}
```

Module 由 `runtime/passes/collect.lua` **自动发现**（遍历 `ir.meta.lang_modules`
并 `pcall(require, mod)`），无需手动注册。

---

## 3. 如何添加 Plugin

**位置**：`lua/plugins/<category>/<name>.lua`，`<category>` ∈
`editing | completion | syntax | toolchain | debug | git | ui | system | theme | ai | lang`。

**规范**（见 `lua/plugins/editing/surround.lua`）：

```lua
return {
  {
    "nvim-mini/mini.surround",
    event = "VeryLazy",
    opts = { mappings = { add = "sa", delete = "sd" } },
    config = function(_, opts) require("mini.surround").setup(opts) end,
  },
}
```

- 必须返回 LazySpec table：`return { { "repo/name", opts = {...} } }`。
- `lua/plugins/init.lua` 通过 `vim.fn.globpath(..., "lua/plugins/**/*.lua")`
  **递归自动发现**，`table.sort` 保证加载顺序确定。
- **Helper module**（二选一）：文件名以 `_` 前缀（`_utils.lua`）；或不返回 table
  （`return M` 或无 return）。两者都会被 init.lua 跳过，不作为 plugin spec 加载。

**层边界强制**：`plugins/` **禁止** `require("runtime.adapters")` 或
`require("runtime.pipeline")`，由 `check_layer_boundaries.sh` 静态拦截。
LTOS adapter（`runtime/adapters/`）在 build-time 动态注入 `opts`，
`plugins/` 只声明 engine，不感知 LTOS。

---

## 4. 如何添加 Cap Module

**位置**：`lua/modules/cap/<name>.lua`（同样适用于 `editor`/`ai`/`keybind` 子目录）

**必填字段**（见 `lua/modules/cap/image.lua`）：

| 字段       | 类型     | 说明                    |
| ---------- | -------- | ----------------------- |
| `cap_type` | `string` | 能力类型，如 `"image"`  |
| `version`  | `number` | schema 版本             |

可选业务字段：`backend`、`fallback`、`filetypes`、`max_width`、`integrations`、
`mason`、`plugins`（依 `ext_schema` 定义）。

**校验**：module 必须 pass `core/domain/ext_schema` 验证。
`runtime/passes/collect_ext.lua` 负责加载并写入 `ir.ext_caps`
（INV-11：**只有** `collect_ext` 可写 `ext_caps`）。

```lua
-- lua/modules/cap/image.lua
return {
  cap_type  = "image", version = 1,
  backend   = "kitty", fallback = nil,
  filetypes = { "png", "jpg", "gif", "webp" },
  mason = {}, plugins = {},
}
```

---

## 5. Phase Module 模式

`Phase` interface 定义于 `lua/core/compiler/pass.lua`：

```lua
---@class Phase
---@field name              string
---@field input_state       string
---@field output_state      string
---@field run               fun(ir: IR): IR
---@field validate?         fun(ir: IR): Diagnostic[]   -- pre-condition
---@field output_validate?  fun(ir: IR): Diagnostic[]   -- post-condition (P6-D2)
```

**两种写法**：

1. **直接 return Phase table**（pure phase，无 setup 需求）——
   见 `runtime/passes/collect.lua`：`local ov = require("runtime.output_validate")`，
   构造 `{ name, input_state, output_state, output_validate = ov.collect,
   run = function(ir) ... end }` 直接 `return`。

2. **包裹在 `M.pass` 下**（phase 需要 setup/registry helper）——
   典型场景：phase 自带 `M.setup()` 注册默认 cap module
   （如 `collect_ext.lua`、`adapters/registry.lua`）。

**output_validate 模式**（P6-D2）：

- 在 `lua/runtime/output_validate.lua` 中用 `M.make({ "caps", "meta", ... })`
  构造 validator（基于下一 phase 的 `STAGE_REQUIRED`）。
- 在 Phase 中 `local ov = require("runtime.output_validate")`，再
  `output_validate = ov.<phase_name>`（如 `ov.collect`、`ov.normalize`、`ov.codegen`）。
- Post-condition failure **非致命**：`run_phase` 降级为 `warn` diagnostic
  并 append 到 IR，pipeline 继续推进（pipeline-is-additive）。

---

## 6. FIX- 标记约定

代码与文档中所有 actionable 改动须打 `FIX-` 标记以便跨文件追溯：

```
FIX-<NAME> (YYYY-MM-DD): description
```

**示例**（见 `plugins/init.lua:8`）：

```lua
-- FIX-ROBUST-V2 (2026-06-23): Convention-based auto-discovery.
```

`<NAME>` 用大写短标识（`ROBUST-V2`、`AUDIT-P1-7a`、`DEPLOY-TEST` 等）。
同一次审计/修复的所有 commit、注释、doc 引用同一 NAME 即可双向 grep。

---

## 7. Layer Boundary 规则

由 `scripts/check_layer_boundaries.sh` 静态强制（`just check` 入口）：

| 层                                | 禁止事项                                                                |
| --------------------------------- | ----------------------------------------------------------------------- |
| `core/kernel`                     | `require("core.compiler.*")`                                            |
| `core/compiler`（非 `ports.lua`） | 任何 `vim.*` API（经 `ports.lua` 注入）；`require("core.domain.*")`  |
| `core/domain`                     | `require("toolchain.*")`、`require("core.compiler.*")`（reverse）       |
| `toolchain/`                      | `vim.g`、`require("core.compiler.*")`、`require("runtime.adapters.*")`  |
| `toolchain/strategy/conflict.lua` | 不得 mutate `StrategyRegistry`（INV-15）                                |
| `runtime/passes/*.lua`            | Phase.run 中 `vim.notify`/`vim.api`/`vim.g`/`vim.tbl_extend`/`deepcopy`/`tbl_deep_extend`/`list_extend`；module-scope `register()`（`pipeline.lua` 例外） |
| `runtime/passes/*.lua`（非 collect_ext） | 赋值 `ext_caps`（INV-11）                                        |
| `runtime/adapters/*.lua`          | `vim.notify`、任何 `vim.*` API（INV-13，cap adapter 须 pure）           |
| `modules/`                        | `require("runtime.pipeline.*")`、`require("runtime.adapters.*")`        |
| `config/`、`plugins/`             | `require("runtime.adapters.*")`、`require("runtime.pipeline.*")`        |

违反即 `FAIL`，CI 阻断。修复方式见每个 `FAIL` 提示（如 "use ports.* abstraction"、
"use util.merge/deep_merge/deep_copy"、"inject via BuildRequest"）。

---

## 8. 测试约定

**文件位置**：`spec/<area>/<name>_spec.lua`，`<area>` ∈
`{ core, modules, runtime, toolchain, integration }`。

**Runner**：使用 `spec/_runner.lua` 提供的 DSL（无外部依赖）：

```lua
-- spec/runtime/my_phase_spec.lua
local R = require("spec._runner")
R.describe("my_phase", function()
  local ir
  R.before_each(function() ir = { stage = "idle", meta = {}, diagnostics = {} } end)
  R.after_each(function()  ir = nil end)   -- 清理状态，避免 suite 间泄漏
  R.it("adds caps to IR", function()
    R.assert_eq(require("runtime.passes.my_phase").run(ir).stage, "AST")
  end)
  R.skip("pending: TBD", function() end)
end)
```

**注册**：新 spec 须追加到 `scripts/ltos_tests.lua` 的 `SPEC_CATALOGUE`：

```lua
{ suite = "runtime", module = "spec.runtime.my_phase_spec", tags = { "unit", "runtime" } },
```

**Tag 系统**：`unit | integration | slow | core | modules | runtime | toolchain`，
可用 `just test-tags unit` 或 `just test-suite runtime` 过滤。

**清理铁律**：所有 `before_each` / `after_each` 必须复位全局状态
（`package.loaded`、`vim.g.*`、registry），否则 `full_pipeline_spec` 串扰。
`just test-ff` 可在首个失败时快速停下。

## 提交流程 Checklist

- [ ] `just check` 通过（layer boundary + orphan 检测）
- [ ] 新 spec 已加入 `SPEC_CATALOGUE` 且 `just test` 全绿
- [ ] 代码改动打上 `FIX-<NAME> (YYYY-MM-DD):` 标记
- [ ] DSL module 保持 plain table、无 `require("runtime.*")`（INV-8）；Phase.run 纯函数（INV-2）
