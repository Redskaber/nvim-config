-- ~/.config/nvim/lua/toolchain/rules.lua
-- Strategy layer: toolchain resolution engine (Strategy pattern).
--
-- resolve(tool) → { use_mason, pkg }
-- Priority: user overrides → system_tools → Nix detection → mappings → identity
--
-- Codegen adapters call only use_mason() / mason_pkg(); no tool-selection logic there.

local env = require("core.env")
local mappings = require("toolchain.mappings")

local M = {}

---@param tool string
---@return { use_mason: boolean, pkg: string|nil }
function M.resolve(tool)
  local result = mappings.resolve(tool)

  -- Respect system-only decision from mappings
  if not result.use_mason then
    return result
  end

  -- Nix overlay: if binary is available from Nix, prefer system
  if env.prefer_system(tool) then
    return { use_mason = false, pkg = nil }
  end

  return result
end

---@param tool string
---@return boolean
function M.use_mason(tool)
  return M.resolve(tool).use_mason
end

---@param tool string
---@return string|nil
function M.mason_pkg(tool)
  return M.resolve(tool).pkg
end

--- Resolve LSP server; explicit_mason=false opts out of mason.
---@param server          string
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
