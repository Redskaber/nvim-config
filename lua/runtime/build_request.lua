-- lua/runtime/build_request.lua
-- BuildRequest: single orchestrator entry for all vim.g / runtime config reads.
-- Layer 4 only — passes and adapters read ir.meta.build_request, never vim.g.

local M = {}

local DEFAULT_BASE_TOOLS = { "codespell" }

-- Debug flags read from vim.g once in BuildRequest,
-- then passed through IR.meta.build_request. Pipeline reads these from
-- build_request instead of touching vim.g directly (INV-9 compliance).
---@class DebugFlags
---@field enabled boolean  vim.g.ltos_debug
---@field cache   boolean  vim.g.ltos_debug_cache
---@field perf    boolean  vim.g.ltos_debug_perf
---@field trace   boolean  vim.g.ltos_debug_trace

local function read_debug_flags()
  return {
    enabled = vim.g.ltos_debug == true,
    cache = vim.g.ltos_debug_cache == true,
    perf = vim.g.ltos_debug_perf == true,
    trace = vim.g.ltos_debug_trace == true,
  }
end

---@class BuildRequest
---@field profile         string
---@field modules         string[]
---@field overrides       table<string, { use_mason: boolean, pkg: string|nil }>
---@field prefer_system   boolean   true when profile == "nix"
---@field base_tools      string[]
---@field base_parsers?   string[]|nil  nil → adapter uses DEFAULT_BASE_PARSERS
---@field debug?          DebugFlags  debug knobs (Opt-G)

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
    -- OPT-G: read debug flags once here, pass through IR.meta.build_request
    debug = read_debug_flags(),
  }
end

--- Context for toolchain/rules.resolve (Layer 3 pure input).
---@param req BuildRequest
---@return { prefer_system: boolean }
function M.rules_ctx(req) return { prefer_system = req.prefer_system == true } end

return M
