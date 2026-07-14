# Architecture.md 更新补充（2026-06-23）

> 本文档记录审计修复后对原 Architecture.md 的更新，反映 bootstrap.lua 职责扩展。

---

## bootstrap.lua 职责扩展

### 原描述（Architecture.md 第 17 行）

```
├── bootstrap.lua       # netrw off、leader keys（唯一职责）
```

### 更新后描述

```
├── bootstrap.lua       # netrw off、leader keys、LazyVim 全局开关（必须早于 lazy.setup）
```

### 职责清单（当前实际）

| 职责 | 设置 | 为什么必须在 bootstrap 阶段 |
| ------ | ------ | --------------------------- |
| 禁用 netrw | `vim.g.loaded_netrw = 1`<br>`vim.g.loaded_netrwPlugin = 1` | netrw 必须在任何插件加载前禁用 |
| Leader keys | `vim.g.mapleader = " "`<br>`vim.g.maplocalleader = "\\"` | lazy.nvim 解析 keymap 时需要 leader 已定义 |
| LazyVim 文件浏览器选择 | `vim.g.lazyvim_file_explorer = "snacks"` | LazyVim 在 `lazy.setup()` 构建 spec 时读取此值，决定加载 neo-tree 还是 snacks |

### 设计原则

bootstrap.lua 的所有设置都是**"必须在 lazy.setup() 之前设置的全局变量"**。这与 Layer 0（kernel）的定位一致——最早初始化，零依赖。

### 为什么 lazyvim_file_explorer 从 globals.lua 迁移到 bootstrap.lua

**原问题**：`vim.g.lazyvim_file_explorer = "snacks"` 最初设置在 `config/globals.lua`。但 `globals.lua` 通过 `options.lua` 加载，而 `options.lua` 是在 `lazy.setup()` **内部**才执行的。LazyVim 在 `lazy.setup()` 构建 spec 列表时读取 `vim.g.lazyvim_file_explorer`——此时该变量还是 nil，LazyVim 用默认值 "neo-tree"，加载了 neo-tree spec，覆盖了我们的 Snacks.explorer keymap。

**修复**：迁移到 `bootstrap.lua`（Layer 0），在 `require("config.lazy")` 之前执行，确保 LazyVim 读到正确值。

### 层边界合规性

- `check_layer_boundaries.sh` 未禁止 kernel 层使用 `vim.g`（bootstrap 性质例外）
- kernel 层的 `vim.g` 调用都是"全局初始化写入"，非"运行时配置读取"
- `env.lua` 的 `vim.g` 读取通过 facts 机制，与 bootstrap 的"写入"职责不冲突

---

## 其他架构更新

### editor.lua 新增 neo-tree 禁用

`lua/plugins/editor/editor.lua` 新增 `{ "nvim-neo-tree/neo-tree.nvim", enabled = false }`，作为双保险确保 neo-tree 永不加载（即使 LazyVim 某些版本仍尝试加载）。

### autocmds.lua 新增 Snacks explorer 自动打开

`lua/config/autocmds.lua` 新增 `SnacksExplorerAutoOpen` autocmd，在启动时自动打开 Snacks explorer（左侧）。

### mason adapter 竞态修复

`lua/runtime/adapters/mason.lua` 新增 `config` 函数，清空 `opts.ensure_installed` 后调 `mason.setup()`，在 VeryLazy 时用 `mason-registry` API 安全安装，避免 "Package is already installing" 竞态。

---

_本补充文档基于 2026-06-23 审计修复。原 Architecture.md 保持不变，本文件记录增量更新。_

