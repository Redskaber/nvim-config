-- ~/.config/nvim/lua/toolchain/rules.lua
-- Toolchain resolution engine.

local env = require("core.env")
local mappings = require("toolchain.mappings")

local M = {}

--- Determine whether a tool should be installed via mason.
---@param tool string  raw tool/server name
---@return boolean
function M.use_mason(tool)
  if mappings.always_system[tool] then
    return false
  end
  if env.prefer_system(tool) then
    return false
  end
  return true
end

--- Resolve a raw tool name to its mason package name, or nil if system-only.
---@param tool string
---@return string|nil
function M.mason_pkg(tool)
  if not M.use_mason(tool) then
    return nil
  end
  return mappings.tool_pkg(tool)
end

--- Same for LSP servers.
---@param server string
---@return string|nil
function M.mason_lsp_pkg(server, explicit_mason)
  -- explicit_mason=false means the lang module opted out
  if explicit_mason == false then
    return nil
  end
  if not M.use_mason(server) then
    return nil
  end
  return mappings.lsp_pkg(server)
end

--- Deduplicate and filter a raw tools list to mason-installable packages.
---@param tools string[]
---@param seen? table<string,boolean>
---@return string[]
function M.mason_list(tools, seen)
  seen = seen or {}
  local out = {}
  for _, t in ipairs(tools) do
    local pkg = M.mason_pkg(t)
    if pkg and not seen[pkg] then
      out[#out + 1] = pkg
      seen[pkg] = true
    end
  end
  return out
end

return M
