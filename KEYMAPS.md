# LTOS Keymaps — 完整键映射参考

> 包含所有由本配置显式定义或覆盖的键映射。  
> 未列出 LazyVim 保留默认值但本配置未改动的映射。

## 全局 / 编辑器核心映射

| 键           | 模式       | 描述                                   | 来源                  |
| ------------ | ---------- | -------------------------------------- | --------------------- |
| `j`          | n, x       | 向下移动（按屏幕行）                   | `config/keymaps.lua`  |
| `k`          | n, x       | 向上移动（按屏幕行）                   | `config/keymaps.lua`  |
| `<C-h>`      | n          | 窗口左移                               | `config/keymaps.lua`  |
| `<C-j>`      | n          | 窗口下移                               | `config/keymaps.lua`  |
| `<C-k>`      | n          | 窗口上移                               | `config/keymaps.lua`  |
| `<C-l>`      | n          | 窗口右移                               | `config/keymaps.lua`  |
| `<C-Up>`     | n          | 增加窗口高度                           | `config/keymaps.lua`  |
| `<C-Down>`   | n          | 减少窗口高度                           | `config/keymaps.lua`  |
| `<C-Left>`   | n          | 减少窗口宽度                           | `config/keymaps.lua`  |
| `<C-Right>`  | n          | 增加窗口宽度                           | `config/keymaps.lua`  |
| `<S-h>`      | n          | 前一个 buffer                          | `config/keymaps.lua`  |
| `<S-l>`      | n          | 后一个 buffer                          | `config/keymaps.lua`  |
| `<C-s>`      | i, x, n, s | 保存文件                               | `config/keymaps.lua`  |
| `<leader>qq` | n          | 退出所有                               | `config/keymaps.lua`  |
| `<Esc>`      | n          | 清除搜索高亮                           | `config/keymaps.lua`  |
| `<`          | v          | 向左缩进并保持选择                     | `config/keymaps.lua`  |
| `>`          | v          | 向右缩进并保持选择                     | `config/keymaps.lua`  |
| `<A-j>`      | n, i, v    | 向下移动行                             | `config/keymaps.lua`  |
| `<A-k>`      | n, i, v    | 向上移动行                             | `config/keymaps.lua`  |
| `p`          | x          | 粘贴但不覆盖寄存器                     | `config/keymaps.lua`  |
| `q`          | n          | 关闭窗口（help/man/qf 等特定文件类型） | `config/autocmds.lua` |

## 代码 / LSP / 诊断

| 键           | 模式 | 描述                                   | 来源                        |
| ------------ | ---- | -------------------------------------- | --------------------------- |
| `<leader>cf` | n, v | 格式化代码                             | `config/keymaps.lua`        |
| `<leader>cr` | n    | 重命名符号                             | `config/keymaps.lua`        |
| `<leader>ca` | n, x | 代码操作                               | `config/keymaps.lua`        |
| `K`          | n    | 悬停信息                               | `config/keymaps.lua`        |
| `gd`         | n    | 转到定义                               | `plugins/lsp/lsp.lua`       |
| `gD`         | n    | 转到声明                               | `plugins/lsp/lsp.lua`       |
| `gr`         | n    | 查找引用                               | `plugins/lsp/lsp.lua`       |
| `gI`         | n    | 转到实现                               | `plugins/lsp/lsp.lua`       |
| `gy`         | n    | 转到类型定义                           | `plugins/lsp/lsp.lua`       |
| `gK`         | n    | 签名帮助                               | `plugins/lsp/lsp.lua`       |
| `<c-k>`      | i    | 签名帮助（插入模式）                   | `plugins/lsp/lsp.lua`       |
| `<leader>cc` | n, x | 运行 CodeLens                          | `plugins/lsp/lsp.lua`       |
| `<leader>cC` | n    | 刷新 CodeLens                          | `plugins/lsp/lsp.lua`       |
| `<leader>cR` | n    | 重命名文件                             | `plugins/lsp/lsp.lua`       |
| `<leader>cA` | n    | 源操作                                 | `plugins/lsp/lsp.lua`       |
| `]]`         | n    | 跳到下一个引用（Snacks.words）         | `plugins/lsp/lsp.lua`       |
| `[[`         | n    | 跳到上一个引用（Snacks.words）         | `plugins/lsp/lsp.lua`       |
| `<a-n>`      | n    | 跳到下一个引用（Snacks.words，跨窗口） | `plugins/lsp/lsp.lua`       |
| `<a-p>`      | n    | 跳到上一个引用（Snacks.words，跨窗口） | `plugins/lsp/lsp.lua`       |
| `<leader>cl` | n    | LSP 信息                               | `plugins/lsp/lsp.lua`       |
| `]d`         | n    | 下一个诊断                             | `config/keymaps.lua`        |
| `[d`         | n    | 上一个诊断                             | `config/keymaps.lua`        |
| `<leader>cd` | n    | 诊断浮动窗口                           | `config/keymaps.lua`        |
| `<leader>xd` | n    | 诊断列表（picker）                     | `config/keymaps.lua`        |
| `]h` / `[h`  | n    | 下一个/上一个 Git 块                   | `plugins/editor/editor.lua` |
| `]H` / `[H`  | n    | 最后一个/第一个 Git 块                 | `plugins/editor/editor.lua` |

## Git 相关（gitsigns / Neogit）

| 键            | 模式 | 描述                          | 来源                        |
| ------------- | ---- | ----------------------------- | --------------------------- |
| `<leader>ghs` | n, x | 暂存当前块                    | `plugins/editor/editor.lua` |
| `<leader>ghr` | n, x | 重置当前块                    | `plugins/editor/editor.lua` |
| `<leader>ghS` | n    | 暂存整个缓冲区                | `plugins/editor/editor.lua` |
| `<leader>ghu` | n    | 撤消暂存块                    | `plugins/editor/editor.lua` |
| `<leader>ghR` | n    | 重置整个缓冲区                | `plugins/editor/editor.lua` |
| `<leader>ghp` | n    | 预览块内联                    | `plugins/editor/editor.lua` |
| `<leader>ghb` | n    | 查看行 blame（完整）          | `plugins/editor/editor.lua` |
| `<leader>ghB` | n    | 查看缓冲区 blame              | `plugins/editor/editor.lua` |
| `<leader>ghd` | n    | 差异比较（当前文件）          | `plugins/editor/editor.lua` |
| `<leader>ghD` | n    | 差异比较（与上次提交）        | `plugins/editor/editor.lua` |
| `<leader>ghq` | n    | 将当前缓冲区更改放入 quickfix | `plugins/editor/editor.lua` |
| `<leader>ghQ` | n    | 将所有更改放入 quickfix       | `plugins/editor/editor.lua` |
| `ih`          | o, x | 选择当前块（文本对象）        | `plugins/editor/editor.lua` |
| `<leader>gtb` | n    | 切换当前行 blame              | `plugins/editor/editor.lua` |
| `<leader>gtw` | n    | 切换单词差异                  | `plugins/editor/editor.lua` |
| `<leader>gts` | n    | 切换符号显示                  | `plugins/editor/editor.lua` |
| `<leader>gtl` | n    | 切换行高亮                    | `plugins/editor/editor.lua` |
| `<leader>gtn` | n    | 切换数字高亮                  | `plugins/editor/editor.lua` |
| `<leader>ngg` | n    | 打开 Neogit                   | `plugins/sys/git.lua`       |
| `<leader>ngc` | n    | Neogit 提交                   | `plugins/sys/git.lua`       |
| `<leader>ngp` | n    | Neogit 推送                   | `plugins/sys/git.lua`       |
| `<leader>ngl` | n    | Neogit 拉取                   | `plugins/sys/git.lua`       |

## 查找 / 文件 / 缓冲区

| 键                | 模式 | 描述                 | 来源                 |
| ----------------- | ---- | -------------------- | -------------------- |
| `<leader>ff`      | n    | 查找文件             | `config/keymaps.lua` |
| `<leader>fg`      | n    | 实时 grep            | `config/keymaps.lua` |
| `<leader>fb`      | n    | 缓冲区列表           | `config/keymaps.lua` |
| `<leader>fr`      | n    | 最近文件             | `config/keymaps.lua` |
| `<leader>sh`      | n    | 帮助标签             | `config/keymaps.lua` |
| `<leader><space>` | n    | 智能查找文件         | `plugins/ui/ui.lua`  |
| `<leader>,`       | n    | 缓冲区列表（snacks） | `plugins/ui/ui.lua`  |
| `<leader>/`       | n    | Grep                 | `plugins/ui/ui.lua`  |
| `<leader>:`       | n    | 命令历史             | `plugins/ui/ui.lua`  |
| `<leader>e`       | n    | 文件浏览器           | `plugins/ui/ui.lua`  |

### Snacks Picker 专项映射（在 ui.lua 中定义）

| 键           | 模式 | 描述                      |
| ------------ | ---- | ------------------------- |
| `<leader>fc` | n    | 查找配置文件              |
| `<leader>fp` | n    | 项目列表                  |
| `<leader>gb` | n    | Git 分支                  |
| `<leader>gl` | n    | Git 日志                  |
| `<leader>gL` | n    | Git 日志（当前行）        |
| `<leader>gs` | n    | Git 状态                  |
| `<leader>gS` | n    | Git 储藏                  |
| `<leader>gd` | n    | Git 差异（块）            |
| `<leader>gf` | n    | Git 文件日志              |
| `<leader>gi` | n    | GitHub Issues（打开）     |
| `<leader>gI` | n    | GitHub Issues（全部）     |
| `<leader>gp` | n    | GitHub PRs（打开）        |
| `<leader>gP` | n    | GitHub PRs（全部）        |
| `<leader>sB` | n    | 在所有打开的缓冲区中 grep |
| `<leader>sg` | n    | Grep（项目）              |
| `<leader>sw` | n, x | Grep 选中文本或当前单词   |
| `<leader>s"` | n    | 寄存器                    |
| `<leader>s/` | n    | 搜索历史                  |
| `<leader>sa` | n    | 自动命令                  |
| `<leader>sb` | n    | 缓冲区行                  |
| `<leader>sc` | n    | 命令历史                  |
| `<leader>sC` | n    | 命令列表                  |
| `<leader>sd` | n    | 诊断                      |
| `<leader>sD` | n    | 缓冲区诊断                |
| `<leader>sh` | n    | 帮助页面                  |
| `<leader>sH` | n    | 高亮组                    |
| `<leader>si` | n    | 图标                      |
| `<leader>sj` | n    | 跳转列表                  |
| `<leader>sk` | n    | 键映射                    |
| `<leader>sl` | n    | 位置列表                  |
| `<leader>sm` | n    | 标记                      |
| `<leader>sM` | n    | Man 手册                  |
| `<leader>sp` | n    | 插件搜索                  |
| `<leader>sq` | n    | 快速修复列表              |
| `<leader>sR` | n    | 恢复上次搜索              |
| `<leader>su` | n    | 撤销历史                  |
| `<leader>uC` | n    | 色彩方案                  |
| `gai`        | n    | 来电调用                  |
| `gao`        | n    | 去电调用                  |
| `<leader>ss` | n    | LSP 符号                  |
| `<leader>sS` | n    | LSP 工作区符号            |

## UI / 窗口 / 终端

| 键            | 模式            | 描述                   | 来源                        |
| ------------- | --------------- | ---------------------- | --------------------------- |
| `<leader>z`   | n               | 禅模式                 | `config/keymaps.lua`        |
| `<leader>Z`   | n               | 放大当前窗口           | `config/keymaps.lua`        |
| `<C-t>`       | n               | 水平终端               | `config/keymaps.lua`        |
| `<leader>t`   | n               | 浮动终端               | `config/keymaps.lua`        |
| `<leader>th`  | n               | 水平终端（toggleterm） | `plugins/sys/terminal.lua`  |
| `<leader>fe`  | n               | 文件树（nvim-tree）    | `plugins/sys/terminal.lua`  |
| `<leader>bp`  | n               | 切换 pin（bufferline） | `plugins/ui/ui.lua`         |
| `<leader>bP`  | n               | 删除未 pin 的缓冲区    | `plugins/ui/ui.lua`         |
| `<leader>br`  | n               | 关闭右侧缓冲区         | `plugins/ui/ui.lua`         |
| `<leader>bl`  | n               | 关闭左侧缓冲区         | `plugins/ui/ui.lua`         |
| `[b` / `]b`   | n               | 前一个/后一个缓冲区    | `plugins/ui/ui.lua`         |
| `[B` / `]B`   | n               | 移动缓冲区位置         | `plugins/ui/ui.lua`         |
| `<leader>snl` | n               | 最后一条消息（noice）  | `plugins/ui/ui.lua`         |
| `<leader>snh` | n               | 历史消息               | `plugins/ui/ui.lua`         |
| `<leader>sna` | n               | 所有消息               | `plugins/ui/ui.lua`         |
| `<leader>snd` | n               | 关闭所有通知           | `plugins/ui/ui.lua`         |
| `<leader>snt` | n               | Noice picker           | `plugins/ui/ui.lua`         |
| `<S-Enter>`   | c               | 重定向命令行           | `plugins/ui/ui.lua`         |
| `<c-f>`       | i, n, s         | 向下滚动（noice）      | `plugins/ui/ui.lua`         |
| `<c-b>`       | i, n, s         | 向上滚动（noice）      | `plugins/ui/ui.lua`         |
| `<C-j>`       | n（snacks.win） | 向下滚动（snacks）     | `plugins/ui/ui.lua`         |
| `<C-k>`       | n（snacks.win） | 向上滚动（snacks）     | `plugins/ui/ui.lua`         |
| `<leader>uG`  | n               | 切换 Git 符号          | `plugins/editor/editor.lua` |
| `<leader>n`   | n               | 通知历史               | `plugins/ui/ui.lua`         |
| `<leader>bd`  | n               | 删除缓冲区             | `plugins/ui/ui.lua`         |
| `<leader>cR`  | n               | 重命名文件（LSP）      | `plugins/ui/ui.lua`         |
| `<leader>gB`  | n, v            | Git 浏览               | `plugins/ui/ui.lua`         |
| `<leader>un`  | n               | 关闭所有通知           | `plugins/ui/ui.lua`         |
| `<leader>N`   | n               | Neovim 新闻            | `plugins/ui/ui.lua`         |
| `<leader>.`   | n               | 草稿缓冲区             | `plugins/ui/ui.lua`         |
| `<leader>S`   | n               | 选择草稿缓冲区         | `plugins/ui/ui.lua`         |

## 文本对象 / 编辑增强

| 键          | 模式 | 描述                   | 来源                              |
| ----------- | ---- | ---------------------- | --------------------------------- |
| `af`        | o, x | 外部函数（treesitter） | `runtime/adapters/treesitter.lua` |
| `if`        | o, x | 内部函数               | `runtime/adapters/treesitter.lua` |
| `ac`        | o, x | 外部类                 | `runtime/adapters/treesitter.lua` |
| `ic`        | o, x | 内部类                 | `runtime/adapters/treesitter.lua` |
| `aa`        | o, x | 外部参数               | `runtime/adapters/treesitter.lua` |
| `ia`        | o, x | 内部参数               | `runtime/adapters/treesitter.lua` |
| `]f` / `[f` | n    | 下一个/上一个函数      | `runtime/adapters/treesitter.lua` |
| `]F` / `[F` | n    | 下一个/上一个函数结尾  | `runtime/adapters/treesitter.lua` |
| `]c` / `[c` | n    | 下一个/上一个类        | `runtime/adapters/treesitter.lua` |
| `]C` / `[C` | n    | 下一个/上一个类结尾    | `runtime/adapters/treesitter.lua` |
| `]a` / `[a` | n    | 下一个/上一个参数      | `runtime/adapters/treesitter.lua` |
| `]A` / `[A` | n    | 下一个/上一个参数结尾  | `runtime/adapters/treesitter.lua` |
| `<leader>a` | n    | 交换下一个参数         | `runtime/adapters/treesitter.lua` |
| `<leader>A` | n    | 交换上一个参数         | `runtime/adapters/treesitter.lua` |

## 多光标（vim-visual-multi）

| 键           | 模式 | 描述             | 来源                        |
| ------------ | ---- | ---------------- | --------------------------- |
| `<C-n>`      | n, x | 添加下一个匹配项 | `plugins/editor/cursor.lua` |
| `<C-d>`      | n, x | 查找子词         | `plugins/editor/cursor.lua` |
| `<A-j>`      | n    | 向下添加光标     | `plugins/editor/cursor.lua` |
| `<A-k>`      | n    | 向上添加光标     | `plugins/editor/cursor.lua` |
| `<leader>vu` | n    | 撤销多光标操作   | `plugins/editor/cursor.lua` |
| `<leader>vr` | n    | 重做多光标操作   | `plugins/editor/cursor.lua` |

## AI 助手

| 键           | 模式 | 描述         | 来源                |
| ------------ | ---- | ------------ | ------------------- |
| `<leader>ai` | n    | 切换 AI 聊天 | `plugins/ai/ai.lua` |
| `<leader>aa` | n, v | AI 动作      | `plugins/ai/ai.lua` |
| `<leader>ac` | n, v | AI 内联协助  | `plugins/ai/ai.lua` |

## Which-Key 分组（仅作为标签提示）

| 前缀            | 分组名               | 来源                        |
| --------------- | -------------------- | --------------------------- |
| `<leader><tab>` | tabs                 | `plugins/editor/editor.lua` |
| `<leader>c`     | code                 | `plugins/editor/editor.lua` |
| `<leader>d`     | debug                | `plugins/editor/editor.lua` |
| `<leader>dp`    | profiler             | `plugins/editor/editor.lua` |
| `<leader>f`     | file/find            | `plugins/editor/editor.lua` |
| `<leader>g`     | git                  | `plugins/editor/editor.lua` |
| `<leader>gh`    | hunks                | `plugins/editor/editor.lua` |
| `<leader>q`     | quit/session         | `plugins/editor/editor.lua` |
| `<leader>s`     | search               | `plugins/editor/editor.lua` |
| `<leader>u`     | ui                   | `plugins/editor/editor.lua` |
| `<leader>x`     | diagnostics/quickfix | `plugins/editor/editor.lua` |
| `[`             | prev                 | `plugins/editor/editor.lua` |
| `]`             | next                 | `plugins/editor/editor.lua` |
| `g`             | goto                 | `plugins/editor/editor.lua` |
| `gs`            | surround             | `plugins/editor/editor.lua` |
| `z`             | fold                 | `plugins/editor/editor.lua` |
| `<leader>b`     | buffer               | `plugins/editor/editor.lua` |
| `<leader>w`     | windows              | `plugins/editor/editor.lua` |

## Toggle 开关（通过 `<leader>u` 前缀）

| 键           | 描述            | 来源                |
| ------------ | --------------- | ------------------- |
| `<leader>us` | 拼写检查        | `plugins/ui/ui.lua` |
| `<leader>uw` | 自动换行        | `plugins/ui/ui.lua` |
| `<leader>uL` | 相对行号        | `plugins/ui/ui.lua` |
| `<leader>ud` | 诊断显示        | `plugins/ui/ui.lua` |
| `<leader>ul` | 行号            | `plugins/ui/ui.lua` |
| `<leader>uc` | 隐藏级别        | `plugins/ui/ui.lua` |
| `<leader>uT` | Treesitter 高亮 | `plugins/ui/ui.lua` |
| `<leader>ub` | 背景明暗切换    | `plugins/ui/ui.lua` |
| `<leader>uh` | 内联提示        | `plugins/ui/ui.lua` |
| `<leader>ug` | 缩进线          | `plugins/ui/ui.lua` |
| `<leader>uD` | 暗淡非活动文本  | `plugins/ui/ui.lua` |

---

**说明**

- 所有 `<leader>` 为空格键，`<localleader>` 为 `\`。
- 部分映射仅在其所在插件激活时有效（如 gitsigns、noice、snacks）。
- 缓存区本地映射（q 关闭特殊窗口）会在 help、man、qf 等文件类型中自动生效。
- 多光标映射会覆盖默认的 `<C-n>` 行为。
