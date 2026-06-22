-- lua/toolchain/rules.lua
-- Layer 3 strategy: tool resolution rule pipeline.
-- Overrides and profile context are injected by Layer 4 — no vim.g access.

local env = require("core.kernel.env")
local mappings = require("toolchain.mappings")

local M = {}

--- Rule 1: user override (highest priority)
local function override_rule(tool, overrides, _)
  if overrides[tool] then
    return overrides[tool]
  end
  if mappings.overrides[tool] then
    return mappings.overrides[tool]
  end
  return nil
end

--- Rule 2: profile nix — prefer system binary when on PATH
local function profile_system_rule(tool, _, ctx)
  if ctx and ctx.prefer_system and env.has(tool) then
    return { use_mason = false, pkg = nil }
  end
  return nil
end

--- Rule 3: system_tools whitelist
local function system_tool_rule(tool, _, _)
  if mappings.system_tools[tool] then
    return { use_mason = false, pkg = nil }
  end
  return nil
end

--- Rule 4: Nix host — if binary present on PATH, use system
local function nix_env_rule(tool, _, _)
  if env.is_nix and env.has(tool) then
    return { use_mason = false, pkg = nil }
  end
  return nil
end

--- Rule 5: explicit tool → mason pkg mapping
local function mapping_rule(tool, _, _)
  local pkg = mappings.tool_to_mason[tool]
  if pkg ~= nil then
    return { use_mason = true, pkg = pkg }
  end
  return nil
end

--- Rule 6: identity fallback
local function identity_rule(tool, _, _)
  return { use_mason = true, pkg = tool }
end

local RULES = {
  override_rule,
  profile_system_rule,
  system_tool_rule,
  nix_env_rule,
  mapping_rule,
  identity_rule,
}

--- Resolve a tool name → { use_mason: boolean, pkg: string|nil }
---@param tool string
---@param overrides? table<string, { use_mason: boolean, pkg: string|nil }>
---@param ctx? { prefer_system?: boolean }
---@return { use_mason: boolean, pkg: string|nil }
function M.resolve(tool, overrides, ctx)
  overrides = overrides or {}
  ctx = ctx or {}
  for _, rule in ipairs(RULES) do
    local result = rule(tool, overrides, ctx)
    if result ~= nil then
      return result
    end
  end
  return { use_mason = true, pkg = tool }
end

---@param tool string
---@param overrides? table
---@param ctx? table
---@return boolean
function M.use_mason(tool, overrides, ctx)
  return M.resolve(tool, overrides, ctx).use_mason
end

return M