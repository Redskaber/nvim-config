-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
--
-- =============================================================================
-- 📁 文件说明
-- 本文件由 plugins.core 自动加载，用于配置 Neovim 的全局行为与 LazyVim 行为。
-- =============================================================================
-- ~/.config/nvim/lua/config/options.lua
-- author: redskaber
-- datetime: 2025-12-12
--
-- =============================================================================
-- 🔧 LazyVim 全局行为配置
-- =============================================================================

-- 设置 Leader 键（主快捷键前缀）
vim.g.mapleader = " "
-- 设置 LocalLeader 键（局部快捷键前缀）
vim.g.maplocalleader = "\\"

-- 启用 LazyVim 自动格式化功能
vim.g.autoformat = true

-- 启用 Snacks 插件的动画效果（设为 false 可全局禁用）
vim.g.snacks_animate = true

-- 指定文件/符号选择器（支持 telescope / fzf）
-- 设为 "auto" 时会自动使用通过 `:LazyExtras` 安装的选择器
vim.g.lazyvim_picker = "auto"

-- 指定代码补全引擎（支持 nvim-cmp / blink.cmp）
-- 设为 "auto" 时会自动使用通过 `:LazyExtras` 安装的补全引擎
vim.g.lazyvim_cmp = "auto"

-- 若补全引擎支持 AI 源，则优先使用 AI 补全而非内联建议
vim.g.ai_cmp = true

-- 根目录检测策略（用于 LSP、项目识别等）
-- 支持：
--   - 内置检测器（如 "lsp", "cwd"）
--   - 文件/目录模式（如 ".git", "lua"）
--   - 自定义函数（function(buf) -> string|string[]）
vim.g.root_spec = { "lsp", { ".git", "lua" }, "cwd" }

-- 在使用 LSP 检测根目录时，忽略指定的 LSP 服务器
vim.g.root_lsp_ignore = { "copilot" }

-- 隐藏弃用警告信息
vim.g.deprecation_warnings = false

-- 在 lualine 状态栏中显示 Trouble 插件的当前文档符号位置
-- 可通过 `vim.b.trouble_lualine = false` 在特定 buffer 中禁用
vim.g.trouble_lualine = true

-- disable netrw at the very start
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- =============================================================================
-- ⚙️ Neovim 基础选项 (vim.opt)
-- =============================================================================

local opt = vim.opt

-- 💾 文件与写入
opt.autowrite = true -- 修改后自动保存（在切换 buffer 或执行命令时）
opt.confirm = true -- 退出前提示保存已修改的 buffer
opt.undofile = true -- 启用持久化撤销历史
opt.undolevels = 10000 -- 撤销步数上限
opt.updatetime = 200 -- 触发 CursorHold 和保存交换文件的时间（毫秒）

-- 📋 剪贴板
-- 若在 SSH 中则不启用系统剪贴板（避免 OSC52 冲突），否则使用系统剪贴板
opt.clipboard = vim.env.SSH_CONNECTION and "" or "unnamedplus"

-- 🖱️ 鼠标与交互
opt.mouse = "a" -- 启用所有模式下的鼠标支持

-- 📏 缩进与制表符
opt.expandtab = true -- 将 Tab 转为空格
opt.shiftwidth = 2 -- 缩进宽度
opt.tabstop = 2 -- Tab 显示宽度
opt.shiftround = true -- 缩进对齐到 shiftwidth 的整数倍
opt.smartindent = true -- 智能自动缩进

-- 🔍 搜索与大小写
opt.ignorecase = true -- 默认忽略大小写
opt.smartcase = true -- 若搜索词含大写字母，则区分大小写

-- 📜 行号与光标
opt.number = true -- 显示绝对行号
opt.relativenumber = true -- 显示相对行号
opt.cursorline = true -- 高亮当前行
opt.scrolloff = 4 -- 光标上下保留 4 行上下文
opt.sidescrolloff = 8 -- 水平滚动时左右保留 8 列上下文

-- 🖼️ 显示与界面
opt.winblend = 15 -- 浮动窗口背景混合（0-100）
opt.pumblend = 20 -- 补全菜单背景混合
opt.termguicolors = true -- 启用真彩色支持
opt.laststatus = 3 -- 使用全局状态栏（仅一个）
opt.showmode = false -- 不显示模式（因有状态栏）
opt.ruler = false -- 禁用默认右下角标尺
opt.linebreak = true -- 在合适位置换行（需 wrap=true 才生效）
opt.wrap = false -- 禁用自动换行
opt.list = true -- 显示不可见字符（如 Tab、空格）
opt.conceallevel = 2 -- 隐藏 Markdown 的 * / _ 等标记，但保留替换内容
opt.fillchars = {
  foldopen = "", -- 展开的折叠符号
  foldclose = "", -- 折叠的折叠符号
  fold = " ", -- 折叠填充
  foldsep = " ", -- 折叠分隔符
  diff = "╱", -- diff 分隔符
  eob = " ", -- 文件末尾空白填充
}
opt.signcolumn = "no" -- 始终显示符号列（避免文本跳动）-- statuscolumn manager
opt.statuscolumn = [[%!v:lua.LazyVim.statuscolumn()]] -- 自定义状态列（含诊断、断点等）

-- 📂 窗口与分割
opt.splitbelow = true -- 新水平窗口在下方
opt.splitright = true -- 新垂直窗口在右侧
opt.splitkeep = "screen" -- 分割时保持屏幕内容稳定
opt.winminwidth = 5 -- 窗口最小宽度

-- 🔧 补全与命令行
opt.completeopt = "menu,menuone,noselect" -- 补全菜单行为
opt.pumheight = 10 -- 补全菜单最大项数
opt.pumblend = 10 -- 补全菜单透明度
opt.wildmode = "longest:full,full" -- 命令行补全模式
opt.inccommand = "nosplit" -- 增量替换预览（不拆分窗口）

-- 🔍 查找与 grep
opt.grepprg = "rg --vimgrep" -- 使用 ripgrep 作为 grep 程序
opt.grepformat = "%f:%l:%c:%m" -- grep 输出格式解析

-- 📄 折叠
opt.foldmethod = "indent" -- 按缩进折叠
opt.foldlevel = 99 -- 默认展开几乎所有折叠
opt.foldtext = "" -- 自定义折叠行文本（留空使用默认）

-- 📝 格式化
opt.formatexpr = "v:lua.LazyVim.format.formatexpr()" -- 使用 LazyVim 的格式化表达式
opt.formatoptions = "jcroqlnt" -- 自动格式化选项（tcqj 的扩展）

-- 🌐 会话与跳转
opt.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
opt.jumpoptions = "view" -- 跳转时恢复视图

-- 🕒 超时设置
-- 在 VSCode 中设为 1000ms（兼容性），否则设为 300ms（更快触发 which-key）
opt.timeoutlen = vim.g.vscode and 1000 or 300

-- ✏️ 虚拟编辑（Visual Block 模式下可移动到无文本区域）
opt.virtualedit = "block"

-- 📚 拼写检查语言
opt.spelllang = { "en" }

-- 📉 平滑滚动（需插件支持）
opt.smoothscroll = true

-- =============================================================================
-- 📝 特定语言/插件微调
-- =============================================================================

-- 禁用 LazyVim 对 Markdown 的推荐样式（避免干扰自定义缩进）
vim.g.markdown_recommended_style = 0

-- =============================================================================
-- 🖥️ 终端配置（可选）
-- =============================================================================
-- 如需使用 PowerShell 作为默认 shell，取消注释以下行：
-- LazyVim.terminal.setup("pwsh")
