-- lua/toolchain/rules.lua
-- Layer 3 strategy: tool resolution rule pipeline.
--
-- REFACTOR (TODO-1.1 + TODO-4.3):
--   • Added nix_rule consuming env facts (env.is_nix + env.has) — removed from env.lua
--   • Rules are now a pipeline (apply-chain), not if/else
--   • Each rule: apply(ctx, tool) -> { use_mason, pkg } | nil (nil = pass to next rule)

local env = require("core.kernel.env")
local mappings = require("toolchain.mappings")

local M = {}

-- ── Rule pipeline ─────────────────────────────────────────────────────────────

--- Rule 1: user override (highest priority)
---@param tool string
---@return table|nil
local function override_rule(tool)
  -- Check vim.g.ltos_tool_overrides first, then mappings.overrides
  local g_overrides = vim.g.ltos_tool_overrides
  if type(g_overrides) == "table" and g_overrides[tool] then
    return g_overrides[tool]
  end
  if mappings.overrides[tool] then
    return mappings.overrides[tool]
  end
  return nil
end

--- Rule 2: system_tools whitelist (rustfmt, gofmt, zigfmt, etc.)
---@param tool string
---@return table|nil
local function system_tool_rule(tool)
  if mappings.system_tools[tool] then
    return { use_mason = false, pkg = nil }
  end
  return nil
end

--- Rule 3: Nix host — if binary present on PATH, use system
--- REFACTOR: this logic was previously in env.prefer_system(); moved here.
---@param tool string
---@return table|nil
local function nix_rule(tool)
  if env.is_nix and env.has(tool) then
    return { use_mason = false, pkg = nil }
  end
  return nil
end

--- Rule 4: explicit tool → mason pkg mapping
---@param tool string
---@return table|nil
local function mapping_rule(tool)
  local pkg = mappings.tool_to_mason[tool]
  if pkg ~= nil then
    return { use_mason = true, pkg = pkg }
  end
  return nil
end

--- Rule 5: identity fallback (tool name == mason pkg name)
---@param tool string
---@return table
local function identity_rule(tool)
  return { use_mason = true, pkg = tool }
end

local RULES = {
  override_rule,
  system_tool_rule,
  nix_rule,
  mapping_rule,
  identity_rule, -- always matches; terminates chain
}

-- ── Public API ────────────────────────────────────────────────────────────────

--- Resolve a tool name → { use_mason: boolean, pkg: string|nil }
---@param tool string
---@return { use_mason: boolean, pkg: string|nil }
function M.resolve(tool)
  for _, rule in ipairs(RULES) do
    local result = rule(tool)
    if result ~= nil then
      return result
    end
  end
  -- Should never reach here (identity_rule always fires)
  return { use_mason = true, pkg = tool }
end

--- Convenience: returns true if tool should be mason-managed.
---@param tool string
---@return boolean
function M.use_mason(tool)
  return M.resolve(tool).use_mason
end

return M
