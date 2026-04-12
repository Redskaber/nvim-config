-- ~/.config/nvim/lua/runtime/init.lua
-- Compiler kernel: orchestrator.
-- Declares lang module list, resolves profile, drives three-tier cache,
-- and calls into runtime/pipeline.lua for full pipeline runs.

local M = {}

local VALID_PROFILES = { minimal = true, full = true, nix = true }

-- Core modules always loaded regardless of profile
local CORE_MODULES = {
  "modules.lang.lua_lang",
}

-- Full module registry — add new lang modules here
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

-- ── Profile resolution ────────────────────────────────────────────────────────

---@return string  "minimal" | "full" | "nix"
local function resolve_profile()
  local raw = vim.g.ltos_profile
  if raw == nil then
    return "full"
  end
  if VALID_PROFILES[raw] then
    return raw
  end
  vim.notify(('[ltos] invalid profile %q — falling back to "full"'):format(tostring(raw)), vim.log.levels.WARN)
  return "full"
end

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

-- ── Three-tier cache logic (TODO-5.3) ────────────────────────────────────────
-- Cache flow:
--   spec tier hit  → return immediately (full skip)
--   spec tier miss → run pipeline → save spec tier
--
-- Future: ast tier / ir tier can be leveraged for partial rebuilds.
-- For now the spec tier provides the startup-time win; partial rebuild
-- is wired up but uses the same key (mtime-based, per-module).

---@param modules string[]
---@param profile string
---@return table[]|nil   cached specs, or nil on miss
local function try_cache(modules, profile)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile)
  if key == "" then
    return nil
  end

  -- Spec tier: full skip if hit
  local specs = cache.load("spec", key)
  if specs then
    if vim.g.ltos_debug then
      vim.notify("[ltos] spec cache hit — skipping pipeline", vim.log.levels.DEBUG)
    end
    return specs
  end
  return nil
end

---@param modules string[]
---@param profile string
---@param specs   table[]
local function persist_cache(modules, profile, specs)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile)
  if key ~= "" then
    cache.save("spec", key, specs)
  end
end

-- ── Public API ────────────────────────────────────────────────────────────────

--- Build the complete plugin spec list for lazy.nvim.
---@return table[]
function M.build()
  local profile = resolve_profile()
  local modules = (profile == "minimal") and filter_minimal(M.LANG_MODULES) or M.LANG_MODULES

  -- Try spec-tier cache first (fastest path)
  local cached = try_cache(modules, profile)
  if cached then
    return cached
  end

  -- Full pipeline run
  local pipeline = require("runtime.pipeline")
  local specs = pipeline.run(modules, profile)

  -- Persist for next startup
  persist_cache(modules, profile, specs)

  return specs
end

--- Register LTOS user commands (:LtosDebug, :LtosInfo, :LtosGraph, :LtosTrace, :LtosIR).
function M.setup_commands()
  require("runtime.commands").setup()
end

return M
