-- lua/runtime/providers/interface.lua
-- ModuleProvider contract: discover() → string[] of lang module paths.

local M = {}

--- Discover lang modules from modules/lang/*.lua on the runtime path.
---@return string[]
function M.discover()
  local files = vim.fn.globpath(vim.o.rtp, "lua/modules/lang/*.lua", true, true)
  local seen = {}
  local modules = {}

  for _, path in ipairs(files) do
    local name = path:match("([^/]+)%.lua$")
    if name and name ~= "init" then
      local mod_name = (name == "lua") and "lua_lang" or name
      local mod_path = "modules.lang." .. mod_name
      if not seen[mod_path] then
        seen[mod_path] = true
        modules[#modules + 1] = mod_path
      end
    end
  end

  table.sort(modules)
  return modules
end

return M