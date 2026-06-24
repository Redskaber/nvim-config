# LTOS nvim-config — 部署指南

> 完整可部署的 Neovim 配置，基于 LazyVim + 自研 LTOS 编译器内核
> 版本：v5.4.7 + P0/P1 审计修复（2026-06-23）

---

## 一、系统要求

| 依赖 | 最低版本 | 用途 |
| ------ | --------- | ------ |
| Neovim | >= 0.11 | 必须 |
| Git | 任意 | lazy.nvim 引导 |
| rippgrep | 任意 | grep / 搜索 |
| fd | 任意 | 文件查找 |
| Nerd Font | 任意 | 图标 / 字形 |
| Node.js | >= 18 | vtsls, bash-language-server |
| Python 3 | >= 3.10 | pyright, ruff, black, isort |
| just | 任意 | 任务运行器（可选但推荐） |
| stylua | 任意 | Lua 格式化（系统级） |
| shfmt | 任意 | Shell 格式化（系统级） |

### 可选语言工具链（按需安装）

- Rust: rustup（rust_analyzer + rustfmt + clippy）
- Go: Go toolchain（gopls + gofmt + goimports）
- Zig: Zig toolchain（zls + zigfmt）
- Java: >= 17（jdtls + google-java-format）
- Kotlin: Kotlin toolchain（kotlin-language-server + ktfmt）
- C/C++: clangd + clang-format + clang-tidy
- Nix: Nix toolchain（nil_ls + statix）

---

## 二、快速部署

### 全新安装

```bash
# 1. 备份现有配置
mv ~/.config/nvim ~/.config/nvim.bak.$(date +%Y%m%d) 2>/dev/null || true
mv ~/.local/share/nvim ~/.local/share/nvim.bak.$(date +%Y%m%d) 2>/dev/null || true
mv ~/.cache/nvim ~/.cache/nvim.bak.$(date +%Y%m%d) 2>/dev/null || true

# 2. 解压代码包
cd ~/.config
tar xzf /path/to/nvim-config-ltos-final.tar.gz
mv nvim-config-ltos-final nvim

# 3. 启动 Neovim（首次会自动安装插件）
cd nvim
nvim

# 4. 等待 lazy.nvim 安装完成（约 1-3 分钟）
#    安装完成后 :q 退出，再重新打开即可正常使用
```

---

## 三、验证部署

### 3.1 架构验证

```bash
cd ~/.config/nvim

# 层边界检查（含 7a-7e 新规则）
just check
# 期望：Layer boundary check: PASSED

# 全量测试套件（30 个 spec 文件，~880 个用例）
just test
# 期望：==> All LTOS tests passed.
```

### 3.2 如果 just 未安装

```bash
# macOS
brew install just

# 或直接运行脚本
bash scripts/check_layer_boundaries.sh
bash scripts/run_ltos_tests.sh
```

### 3.3 LTOS 用户命令（Neovim 内）

```vim
:LtosInfo           " 显示当前 profile / state / modules / tools
:LtosDebug collect  " 查看 collect 阶段 IR 快照
:LtosTrace          " 显示 per-phase 耗时
:LtosGraph dag      " 流水线 DAG 可视化
```

---

## 四、配置定制

### 4.1 Profile 切换

在 `lua/config/globals.lua` 中设置：

```lua
vim.g.ltos_profile = "full"  -- full / minimal / nix
```

| Profile | lang 模块 | 工具策略 |
| --------- | ---------- | --------- |
| full | 全部 | rules 默认管道 |
| minimal | 仅 lua | 同上 |
| nix | 同 full | prefer_system=true |

### 4.2 调试模式

```lua
vim.g.ltos_debug = true           -- IR freeze 检测
vim.g.ltos_debug_cache = true     -- 缓存日志
vim.g.ltos_debug_invariants = true -- 不变量检查
```

### 4.3 添加新语言模块

创建 `lua/modules/lang/mylang.lua`：

```lua
return {
  version = 1,
  treesitter = { "mylang" },
  lsp = { mylang_lsp = { cmd = { "mylang-lsp" } } },
  formatters = {
    mylang = { { kind = "formatter", strategy = "mylang_fmt" } },
  },
  mason = { "mylang_fmt" },
}
```

重启 Neovim，LTOS 自动发现并编译。

---

## 五、项目结构

```
nvim-config-ltos-final/
├── init.lua              # 入口（2 行）
├── lazyvim.json          # LazyVim extras
├── justfile              # 任务定义
├── stylua.toml           # Lua 格式化
├── README.md             # 项目说明
├── DEPLOY.md             # 本文档
├── CHANGELOG.md          # 变更日志
├── LICENSE               # MIT
├── lua/                  # 117 个 Lua 源文件
│   ├── core/             # Layer 0-2: kernel + compiler + domain
│   ├── toolchain/        # Layer 3: strategy / rules / mappings
│   ├── runtime/          # Layer 4: pipeline / passes / adapters
│   ├── modules/          # Layer 5-6: DSL 声明
│   ├── config/           # Layer 5: Neovim 运行时配置
│   └── plugins/          # Layer 5: 静态插件声明
├── scripts/              # 5 个脚本
│   ├── check_layer_boundaries.sh
│   ├── run_ltos_tests.sh
│   ├── concat_files.sh
│   ├── grep_paths.sh
│   └── ltos_tests.lua
├── spec/                 # 30 个测试文件
└── docs/                 # 审计文档
```

---

## 六、常用命令

### just 命令

| 命令 | 说明 |
| ------ | ------ |
| just check | 层边界检查 |
| just test | 全量测试 |
| just test-suite <name> | 指定套件 |
| just ci | check + test |

### 故障排查

```bash
# 清除缓存
rm -rf ~/.cache/ltos/

# 查看编译过程
nvim --headless "+lua vim.g.ltos_debug=true" "+LtosDebug collect" +qa
```

---

## 七、本版本包含的审计修复

详见 `docs/AUDIT_CORRIGENDUM_2026-06-23.md`。

### P0 修复（5 个，1 个误报）

- P0-1: cap_resolve.lua 调用签名
- P0-2: plugins/ai/ai.lua 注释 LIVE spec
- P0-4: lifecycle.lua 运算符优先级
- P0-5: conflict.lua 三处修复（含移除 notify_warn 越层）
- P0-6: python.lua + lang_spec.lua 对齐

### P1 修复（5 个，1 个回退）

- P1-1: collect.lua vim.api → ports
- P1-2a: collect_ext.lua require-time → setup()
- P1-2b: pipeline.lua 回退（测试兼容性）
- P1-3: store.lua 原子写入
- P1-4: policy.lua 环检测
- P1-5: lifecycle.lua 迁移到 domain.diagnostic

### 新增护栏

- 6 个回归测试（cap_specs 内容验证）
- 5 个 layer boundary check 规则（7a-7e）

### 不变量合规率

修复前 11/15 → P0 后 13/15 → **P1 后 14/15**

---

_LTOS v5.4.7 + 2026-06-23 审计修复 · MIT License_
