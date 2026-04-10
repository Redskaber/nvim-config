-- ~/.config/nvim/lua/runtime/init.lua
-- Orchestrator: declares lang module list, runs pipeline, returns specs.
-- Zero adapter logic here; all stages live in runtime/pipeline.lua.

local M = {}

-- Exported so runtime.debug can reference without re-declaring.
M.LANG_MODULES = {
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

--- Build the complete plugin spec list for lazy.nvim.
---@return table[]
function M.build()
  return require("runtime.pipeline").run(M.LANG_MODULES)
end

return M
