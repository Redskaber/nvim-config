-- lua/plugins/theme/transparency.lua

local M = {}

--- Returns all highlight group transparency config
---@param colors table Catppuccin colors
---@return table highlight groups
function M.highlights(colors)
  -- ── Core ──────────────────────────────────────────────────────
  local t = {
    Normal = { bg = "none" },
    NormalSB = { bg = "none" },
    NormalFloat = { bg = "none" },
    FloatBorder = { bg = "none", fg = colors.overlay0 },
    FloatTitle = { bg = "none" },
    CursorLine = { bg = "none" },
    CmdlineNormal = { bg = "none" },
    MsgArea = { bg = "none" },

    -- ── NeoTree ──────────────────────────────────────────────────
    NeoTreeNormal = { bg = "none" },
    NeoTreeNormalNC = { bg = "none" },
    NeoTreeRootName = { bg = "none" },
    NeoTreeDirectoryName = { bg = "none" },
    NeoTreeFileIcon = { bg = "none" },
    NeoTreeFileName = { bg = "none" },
    NeoTreeGitModified = { bg = "none" },
    NeoTreeIndentMarker = { bg = "none" },
    NeoTreeStatusLineNC = { bg = "none" },

    -- ── Noice / Notify ────────────────────────────────────────────
    NoiceCmdlinePopup = { bg = "none" },
    NoicePopup = { bg = "none" },
    NotifyERRORBody = { bg = "none" },
    NotifyWARNBody = { bg = "none" },
    NotifyINFOBody = { bg = "none" },
    NotifyDEBUGBody = { bg = "none" },
    NotifyTRACEBody = { bg = "none" },

    -- ── Telescope / FZF ───────────────────────────────────────────
    TelescopeNormal = { bg = "none" },
    TelescopePreviewNormal = { bg = "none" },
    TelescopeResultsNormal = { bg = "none" },
    TelescopePromptNormal = { bg = "none" },
    TelescopePreviewTitle = { bg = "none" },
    TelescopePromptTitle = { bg = "none" },
    TelescopeResultsTitle = { bg = "none" },
    TelescopeBorder = { bg = "none", fg = colors.overlay0 },

    -- ── Mini components ───────────────────────────────────────────
    MiniTablineCurrent = { bg = "none" },
    MiniTablineVisible = { bg = "none" },
    MiniTablineHidden = { bg = "none" },
    MiniTablineFill = { bg = "none" },
    MiniStatuslineModeNormal = { bg = "none" },
    MiniStatuslineModeVisual = { bg = "none" },
    MiniStatuslineFilename = { bg = "none" },
    MiniPickNormal = { bg = "none" },
    MiniPickPrompt = { bg = "none" },

    -- ── Bufferline ────────────────────────────────────────────────
    BufferLineFill = { bg = "none" },
    BufferLineBackground = { bg = "none" },

    -- ── Which-Key ─────────────────────────────────────────────────
    WhichKey = { bg = "none" },
    WhichKeyGroup = { bg = "none" },
    WhichKeyDesc = { bg = "none" },
    WhichKeySeperator = { bg = "none" },
    WhichKeyBorder = { bg = "none", fg = colors.gray0 },
    WhichKeyNormal = { bg = "none" },

    -- ── Dashboard / Alpha ─────────────────────────────────────────
    AlphaHeader = { bg = "none" },
    AlphaButtons = { bg = "none" },
    AlphaFooter = { bg = "none" },
    AlphaNormal = { bg = "none" },
    SnacksDashboard = { bg = "none" },

    -- ── Completion menu ───────────────────────────────────────────
    Pmenu = { bg = "none" },
    PmenuSel = { bg = colors.surface0 },
    PumNormal = { bg = "none" },
    PumSel = { bg = "none", fg = colors.magenta },
    PumMenu = { bg = "none" },
    PumSep = { bg = "none", fg = colors.overlay0 },

    -- ── Gutter ────────────────────────────────────────────────────
    SignColumn = { bg = "none" },
    FoldColumn = { bg = "none" },
    LineNr = { bg = "none" },
    CursorLineNr = { bg = "none" },
    NonText = { bg = "none" },
    EndOfBuffer = { bg = "none" },

    -- ── Diff ──────────────────────────────────────────────────────
    DiffAdd = { bg = "none", fg = colors.green },
    DiffChange = { bg = "none", fg = colors.yellow },
    DiffDelete = { bg = "none", fg = colors.red },
    DiffText = { bg = "none", fg = colors.blue },

    -- ── Indent Blankline ──────────────────────────────────────────
    IndentBlanklineContextStart = { bg = "none" },
    IndentBlanklineChar = { bg = "none" },
  }
  return t
end

return M
