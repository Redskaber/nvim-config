-- ~/.config/nvim/lua/toolchain/rules.lua
-- Toolchain resolution engine: implements ToolchainStrategy interface (P1-2).
--
-- resolve(tool) → { use_mason, pkg }
-- Priority: user overrides → system_tools → Nix detection → mappings default
-- Codegen adapters call only use_mason() / mason_pkg(); no tool-selection logic there.

local env = require("core.env")
local mappings = require("toolchain.mappings")

local M = {}

--- Unified resolution entry point.
---@param tool string
---@return { use_mason: boolean, pkg: string|nil }
function M.resolve(tool)
  local result = mappings.resolve(tool)

  -- If mappings already decided system-only, respect it
  if not result.use_mason then
    return result
  end

  -- Layer Nix detection: if running under Nix and binary available, prefer system
  if env.prefer_system(tool) then
    return { use_mason = false, pkg = nil }
  end

  return result
end

--- Determine whether a tool should be installed via mason.
---@param tool string
---@return boolean
function M.use_mason(tool)
  return M.resolve(tool).use_mason
end

--- Resolve a tool name to its mason package name, or nil if system-only.
---@param tool string
---@return string|nil
function M.mason_pkg(tool)
  return M.resolve(tool).pkg
end

--- Resolve an LSP server name to its mason package name.
--- explicit_mason=false means the lang module opted out of mason.
---@param server         string
---@param explicit_mason? boolean
---@return string|nil
function M.mason_lsp_pkg(server, explicit_mason)
  if explicit_mason == false then
    return nil
  end
  local result = M.resolve(server)
  if not result.use_mason then
    return nil
  end
  return mappings.lsp_pkg(server)
end

--- Deduplicate and filter a raw tool list to mason-installable packages.
---@param tools string[]
---@param seen? table<string, boolean>
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
