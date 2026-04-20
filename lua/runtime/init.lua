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
  "modules.lang.asm",
  "modules.lang.c_cpp",
  "modules.lang.go",
  "modules.lang.java",
  "modules.lang.kotlin",
  "modules.lang.lisp",
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

-- ── Three-tier cache logic (TODO-7.1) ────────────────────────────────────────
-- Cache flow:
--   spec tier hit  → return immediately (full skip)
--   ast tier hit   → skip collect phase, resume from normalize
--   spec tier miss → run pipeline → save spec + ast tiers
--
-- Per-module incremental: each module has its own content hash.
-- Only changed modules trigger re-validation; unchanged modules
-- are restored from the AST tier cache.

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
    if vim.g.ltos_debug or vim.g.ltos_debug_cache then
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

--- Try to load AST-tier cached caps for incremental rebuild.
--- Returns cached caps table or nil on miss.
---@param modules string[]
---@param profile string
---@return table|nil  cached IR.caps snapshot
local function try_ast_cache(modules, profile)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile)
  if key == "" then
    return nil
  end
  local cached = cache.load("ast", key)
  if cached then
    if vim.g.ltos_debug or vim.g.ltos_debug_cache then
      vim.notify("[ltos] ast cache hit — skipping collect phase", vim.log.levels.DEBUG)
    end
    return cached
  end
  return nil
end

---@param modules string[]
---@param profile string
---@param caps    table   IR.caps snapshot
local function persist_ast_cache(modules, profile, caps)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile)
  if key ~= "" then
    cache.save("ast", key, caps)
  end
end
-- ── Public API ────────────────────────────────────────────────────────────────

--- Build the complete plugin spec list for lazy.nvim.
---@return table[]
function M.build()
  local profile = resolve_profile()
  local modules = (profile == "minimal") and filter_minimal(M.LANG_MODULES) or M.LANG_MODULES

  -- Spec tier: full skip (fastest path)
  local cached = try_cache(modules, profile)
  if cached then
    return cached
  end

  -- AST tier: skip collect phase, resume from normalize (TODO-7.1)
  local cached_caps = try_ast_cache(modules, profile)

  -- Full pipeline run (with optional AST cache injection)
  local pipeline = require("runtime.pipeline")
  local specs, run_ir = pipeline.run(modules, profile, cached_caps)

  -- Persist spec tier for next startup
  persist_cache(modules, profile, specs)

  -- Persist AST tier from the run IR (no second pipeline run needed).
  -- Only when we ran a full collect (no cached_caps); caps are in run_ir.
  if not cached_caps and run_ir and run_ir.caps then
    persist_ast_cache(modules, profile, run_ir.caps)
  end
  return specs
end

--- Register LTOS user commands (:LtosDebug, :LtosInfo, :LtosGraph, :LtosTrace, :LtosIR).
function M.setup_commands()
  require("runtime.commands").setup()
end

return M
