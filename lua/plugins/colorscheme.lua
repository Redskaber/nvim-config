-- ~/.config/nvim/lua/plugins/colorscheme.lua
-- author: redskaber
-- datetime: 2025-12-12
-- effect: configured Catppuccin theme(Mocha) and enabled transparent background and use other plugins.

return {
  -- ▼ LazyVim theme ▼
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin", -- default theme
    },
  },

  -- ▼ Catppuccin core configured ▼
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000, -- priority
    opts = {
      flavour = "mocha", -- sub theme
      transparent_background = true, -- enabled global transparent
      show_end_of_buffer = false, -- shadow cache area ~

      -- LSP diagonsis underlines types
      lsp_styles = {
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },

      -- plugins（启用与各插件的视觉适配）
      integrations = {
        aerial = true, -- 代码大纲
        alpha = true, -- 启动界面
        cmp = true, -- 补全菜单
        dashboard = true, -- 仪表盘
        lualine = true, -- 状态栏
        flash = true, -- 快速跳转高亮
        fzf = true, -- FZF 搜索
        grug_far = true, -- 全局替换
        gitsigns = true, -- Git 行标记
        headlines = true, -- Markdown 标题高亮
        illuminate = true, -- 当前行/词高亮
        indent_blankline = { enabled = true }, -- 缩进参考线
        leap = true, -- Leap 跳转
        lsp_trouble = true, -- Trouble LSP 问题面板
        mason = true, -- Mason 安装器 UI
        mini = true, -- Mini.nvim 插件套件
        navic = { enabled = true, custom_bg = "lualine" }, -- LSP 导航栏（背景匹配 lualine）
        neotest = true, -- 测试运行器
        neotree = true, -- 文件树
        noice = true, -- 增强通知与命令行
        notify = true, -- 通知系统
        snacks = true, -- Snacks UI 组件
        telescope = true, -- Telescope 搜索
        treesitter_context = true, -- Treesitter 上下文高亮
        which_key = true, -- 快捷键提示
      },

      -- 自定义高亮：实现全局透明（保留部分关键元素背景以保证可读性）
      custom_highlights = function(colors)
        return {
          -- ▼ 核心区域透明化 ▼
          Normal = { bg = "none" },
          NormalSB = { bg = "none" }, -- 状态栏背景（注意：实际由 lualine 控制）

          -- ▼ 浮动窗口 & 弹窗 ▼
          NormalFloat = { bg = "none" },
          FloatBorder = { bg = "none", fg = colors.overlay0 },
          FloatTitle = { bg = "none" },

          -- ▼ 命令行 & 消息区 ▼
          CmdlineNormal = { bg = "none" },
          MsgArea = { bg = "none" },

          -- ▼ NeoTree 文件树 ▼
          NeoTreeNormal = { bg = "none" },
          NeoTreeNormalNC = { bg = "none" },
          NeoTreeRootName = { bg = "none" },
          NeoTreeDirectoryName = { bg = "none" },
          NeoTreeFileIcon = { bg = "none" },
          NeoTreeFileName = { bg = "none" },
          NeoTreeGitModified = { bg = "none" },
          NeoTreeIndentMarker = { bg = "none" },
          NeoTreeStatusLineNC = { bg = "none" },

          -- ▼ Noice & Notify 通知系统 ▼
          NoiceCmdlinePopup = { bg = "none" },
          NoicePopup = { bg = "none" },
          NotifyERRORBody = { bg = "none" },
          NotifyWARNBody = { bg = "none" },
          NotifyINFOBody = { bg = "none" },
          NotifyDEBUGBody = { bg = "none" },
          NotifyTRACEBody = { bg = "none" },

          -- ▼ Telescope / FZF 搜索界面 ▼
          TelescopeNormal = { bg = "none" },
          TelescopePreviewNormal = { bg = "none" },
          TelescopeResultsNormal = { bg = "none" },
          TelescopePromptNormal = { bg = "none" },
          TelescopePreviewTitle = { bg = "none" },
          TelescopePromptTitle = { bg = "none" },
          TelescopeResultsTitle = { bg = "none" },
          TelescopeBorder = { bg = "none", fg = colors.overlay0 },

          -- ▼ Mini.nvim 组件 ▼
          MiniTablineCurrent = { bg = "none" },
          MiniTablineVisible = { bg = "none" },
          MiniTablineHidden = { bg = "none" },
          MiniTablineFill = { bg = "none" },
          MiniStatuslineModeNormal = { bg = "none" },
          MiniStatuslineModeVisual = { bg = "none" },
          MiniStatuslineFilename = { bg = "none" },
          MiniPickNormal = { bg = "none" },
          MiniPickPrompt = { bg = "none" },

          -- ▼ Bufferline（顶部标签栏） ▼
          BufferLineFill = { bg = "none" },
          BufferLineBackground = { bg = "none" },

          -- ▼ Which-Key 快捷键提示 ▼
          WhichKey = { bg = "none" },
          WhichKeyGroup = { bg = "none" },
          WhichKeyDesc = { bg = "none" },
          WhichKeySeperator = { bg = "none" },
          WhichKeyBorder = { bg = "none", fg = colors.gray0 },

          -- ▼ Dashboard / Alpha 启动页 ▼
          AlphaHeader = { bg = "none" },
          AlphaButtons = { bg = "none" },
          AlphaFooter = { bg = "none" },
          AlphaNormal = { bg = "none" },
          SnacksDashboard = { bg = "none" },

          -- ▼ 补全菜单 (Pmenu) ▼
          Pmenu = { bg = "none" },
          PmenuSel = { bg = colors.surface0 }, -- 选中项保留背景，提升可读性
          PumNormal = { bg = "none" },
          PumSel = { bg = "none", fg = colors.magenta },
          PumMenu = { bg = "none" },
          PumSep = { bg = "none", fg = colors.overlay0 },

          -- ▼ 辅助列（行号、符号列等） ▼
          SignColumn = { bg = "none" },
          FoldColumn = { bg = "none" },
          LineNr = { bg = "none" },
          CursorLineNr = { bg = "none" },
          NonText = { bg = "none" },
          EndOfBuffer = { bg = "none" },

          -- ▼ Diff 区域（颜色仅用前景，背景透明） ▼
          DiffAdd = { bg = "none", fg = colors.green },
          DiffChange = { bg = "none", fg = colors.yellow },
          DiffDelete = { bg = "none", fg = colors.red },
          DiffText = { bg = "none", fg = colors.blue },

          -- ▼ Indent Blankline（Mini 版） ▼
          IndentBlanklineContextStart = { bg = "none" },
          IndentBlanklineChar = { bg = "none" },
        }
      end,
    },

    -- ▼ 可选依赖：Bufferline 高亮适配 ▼
    specs = {
      {
        "akinsho/bufferline.nvim",
        optional = true,
        opts = function(_, opts)
          -- 仅在使用 catppuccin 时注入其专用 bufferline 主题
          if (vim.g.colors_name or ""):find("catppuccin") then
            opts.highlights = require("catppuccin.special.bufferline").get_theme()
          end
        end,
      },
    },
  },
}
