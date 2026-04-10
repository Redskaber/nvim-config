-- ~/.config/nvim/lua/core/toolchain.lua
-- Resolves tool sources with per-capability-kind awareness.
-- source(tool, kind?) → "system"|"mason"

local env = require("core.env")

local M = {}

local ALWAYS_SYSTEM = {
  rustup = true,
  nix = true,
  git = true,
  make = true,
  cc = true,
}

--- Full resolution: "system" beats Mason when Nix owns the tool.
---@param tool string
---@param _kind? string  reserved for future per-kind overrides
---@return "system"|"mason"
function M.source(tool, _kind)
  if ALWAYS_SYSTEM[tool] then
    return "system"
  end
  if env.prefer_system(tool) then
    return "system"
  end
  return "mason"
end

--- Convenience predicate.
---@param tool string
---@return boolean
function M.use_mason(tool)
  return M.source(tool) == "mason"
end

--- Build a deduplicated Mason ensure_installed list from a raw list,
--- filtering out system-managed tools. Also accepts an optional set of
--- already-seen tools to avoid cross-adapter duplication.
---@param tools string[]
---@param seen? table<string,boolean>
---@return string[]
function M.mason_list(tools, seen)
  seen = seen or {}
  local out = {}
  for _, t in ipairs(tools) do
    if M.use_mason(t) and not seen[t] then
      out[#out + 1] = t
      seen[t] = true
    end
  end
  return out
end

return M
