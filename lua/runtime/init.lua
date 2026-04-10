-- ~/.config/nvim/lua/runtime/init.lua
-- Orchestrator: load all lang modules → collect capabilities →
-- build plugin specs via adapters → return to lazy.nvim.

local M = {}

-- Eagerly load all language modules so they register their capabilities.
-- Each module calls core.capability.register() as a side-effect.
local LANG_MODULES = {
  "modules.lang.c_cpp",
  "modules.lang.go",
  "modules.lang.lua_lang",
  "modules.lang.markup",
  "modules.lang.nix",
  "modules.lang.python",
  "modules.lang.rust",
  "modules.lang.shell",
  "modules.lang.typescript",
  "modules.lang.zig",
}

local function load_langs()
  for _, mod in ipairs(LANG_MODULES) do
    local ok, err = pcall(require, mod)
    if not ok then
      vim.notify("[runtime] failed to load " .. mod .. ": " .. tostring(err), vim.log.levels.WARN)
    end
  end
end

--- Build the complete plugin spec table from the capability registry.
--- Called once by config/lazy.lua; result is passed to lazy.nvim.
---@return table[]  flat list of lazy plugin specs
function M.build()
  load_langs()

  local caps = require("core.capability").all()

  local lsp_adapter = require("runtime.adapters.lsp")
  local mason_adapter = require("runtime.adapters.mason")
  local ts_adapter = require("runtime.adapters.treesitter")
  local fmt_adapter = require("runtime.adapters.conform")
  local lint_adapter = require("runtime.adapters.lint")

  local specs = {}

  -- Each adapter receives the full capability table and appends to specs.
  for _, spec in ipairs(lsp_adapter.build(caps)) do
    specs[#specs + 1] = spec
  end
  for _, spec in ipairs(mason_adapter.build(caps)) do
    specs[#specs + 1] = spec
  end
  for _, spec in ipairs(ts_adapter.build(caps)) do
    specs[#specs + 1] = spec
  end
  for _, spec in ipairs(fmt_adapter.build(caps)) do
    specs[#specs + 1] = spec
  end
  for _, spec in ipairs(lint_adapter.build(caps)) do
    specs[#specs + 1] = spec
  end

  return specs
end

return M
