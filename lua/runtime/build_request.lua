-- lua/runtime/build_request.lua
-- BuildRequest: single orchestrator entry for all vim.g / runtime config reads.
-- Layer 4 only — passes and adapters read ir.meta.build_request, never vim.g.

local M = {}

local DEFAULT_BASE_TOOLS = { "codespell" }

---@class BuildRequest
---@field profile         string
---@field modules         string[]
---@field overrides       table<string, { use_mason: boolean, pkg: string|nil }>
---@field prefer_system   boolean   true when profile == "nix"
---@field base_tools      string[]
---@field base_parsers?   string[]|nil  nil → adapter uses DEFAULT_BASE_PARSERS

--- Construct a BuildRequest from vim globals (call only from runtime/init.lua).
---@param profile string
---@param modules string[]
---@return BuildRequest
function M.from_vim(profile, modules)
  local overrides = vim.g.ltos_tool_overrides
  if type(overrides) ~= "table" then
    overrides = {}
  end

  local base_tools = vim.g.ltos_base_mason_tools
  if type(base_tools) ~= "table" then
    base_tools = DEFAULT_BASE_TOOLS
  end

  local base_parsers = vim.g.ltos_base_parsers
  if type(base_parsers) ~= "table" then
    base_parsers = nil
  end

  return {
    profile = profile,
    modules = modules,
    overrides = overrides,
    prefer_system = profile == "nix",
    base_tools = base_tools,
    base_parsers = base_parsers,
  }
end

--- Context for toolchain/rules.resolve (Layer 3 pure input).
---@param req BuildRequest
---@return { prefer_system: boolean }
function M.rules_ctx(req)
  return { prefer_system = req.prefer_system == true }
end

return M
