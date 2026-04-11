-- ~/.config/nvim/lua/runtime/init.lua
-- Orchestrator: declares lang module list, runs pipeline, returns specs.
-- Supports vim.g.ltos_profile (minimal/full/nix) and pipeline result caching.

local M = {}

local VALID_PROFILES = { minimal = true, full = true, nix = true }

-- Core modules always included regardless of profile.
local CORE_MODULES = {
  "modules.lang.lua_lang",
}
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

--- Resolve and validate the active profile from vim.g.ltos_profile.
---@return string  one of "minimal" | "full" | "nix"
local function resolve_profile()
  local raw = vim.g.ltos_profile
  if raw == nil then
    return "full"
  end
  if VALID_PROFILES[raw] then
    return raw
  end
  vim.notify(string.format('[ltos] invalid profile %q — falling back to "full"', tostring(raw)), vim.log.levels.WARN)
  return "full"
end

--- Filter the module list for the "minimal" profile.
--- Keeps only modules whose basename appears in CORE_MODULES.
---@param modules string[]
---@return string[]
local function filter_minimal(modules)
  local core_set = {}
  for _, m in ipairs(CORE_MODULES) do
    core_set[m] = true
  end
  local out = {}
  for _, m in ipairs(modules) do
    if core_set[m] then
      out[#out + 1] = m
    end
  end
  return out
end
--- Build the complete plugin spec list for lazy.nvim.
--- Reads vim.g.ltos_profile, attempts cache load, falls back to full pipeline.
---@return table[]
function M.build()
  local profile = resolve_profile()

  local modules = M.LANG_MODULES
  if profile == "minimal" then
    modules = filter_minimal(modules)
  end

  local cache = require("core.cache")
  local key = cache.key(modules)

  -- Cache hit: skip pipeline entirely
  local cached = cache.load(key, profile)
  if cached then
    return cached
  end

  -- Full pipeline run
  local specs = require("runtime.pipeline").run(modules)

  -- Persist result for next startup
  cache.save(key, profile, specs)

  return specs
end

--- Register LTOS user commands (:LtosDebug, :LtosInfo).
--- Called once after build() completes.
function M.setup_commands()
  require("runtime.commands").setup()
end

return M
