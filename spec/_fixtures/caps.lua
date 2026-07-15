-- spec/_fixtures/caps.lua
-- Shared capability DSL fixtures for ext_caps / cap adapter tests.

local M = {}

function M.image_cap(overrides)
  return vim.tbl_deep_extend("force", {
    cap_type = "image",
    version = 1,
    backend = "kitty",
    fallback = "chafa",
    filetypes = { "png", "jpg", "jpeg", "gif", "webp" },
    max_width = 80,
    max_height = 30,
    integrations = { markdown = true },
    mason = {},
  }, overrides or {})
end

function M.media_cap(overrides)
  return vim.tbl_deep_extend("force", {
    cap_type = "media",
    version = 1,
    viewers = {
      { kind = "pdf", plugin = "pdf-view.nvim", filetypes = { "pdf" } },
      { kind = "image", plugin = "3rd/image.nvim", filetypes = { "png", "jpg" } },
    },
    mason = {},
  }, overrides or {})
end

function M.ai_cap(overrides)
  return vim.tbl_deep_extend("force", {
    cap_type = "ai",
    version = 1,
    completion = { provider = "copilot" },
    chat = { provider = "codecompanion", adapter = "anthropic" },
    plugins = {
      { name = "github/copilot.vim", cmd = { "Copilot" } },
      {
        name = "olimorris/codecompanion.nvim",
        cmd = { "CodeCompanionChat" },
        keys = {
          {
            lhs = "<leader>ai",
            rhs = "<cmd>CodeCompanionChat Toggle<cr>",
            mode = "n",
            desc = "AI: toggle chat",
          },
        },
        opts = { log_level = "ERROR" },
      },
    },
  }, overrides or {})
end

function M.keybind_cap(overrides)
  return vim.tbl_deep_extend("force", {
    cap_type = "keybind",
    version = 1,
    preset = "helix",
    groups = {
      { prefix = "<leader>g", name = "git", icon = "" },
      { prefix = "<leader>s", name = "search", icon = "" },
    },
  }, overrides or {})
end

--- All four standard cap buckets (non-empty).
function M.all_caps()
  return {
    image = { image = M.image_cap() },
    media = { media = M.media_cap() },
    ai = { ai = M.ai_cap() },
    keybind = { keybind = M.keybind_cap() },
  }
end

--- Empty cap buckets baseline.
function M.empty_caps() return { image = {}, media = {}, ai = {}, keybind = {} } end

return M