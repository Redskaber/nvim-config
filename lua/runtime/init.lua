-- ~/.config/nvim/lua/runtime/init.lua
-- Compiler kernel: orchestrator.
-- Resolves profile via ProviderRegistry, drives two-tier cache (spec + ast),
-- and calls into runtime/pipeline.lua for full pipeline runs.
-- All vim.g reads for the build are consolidated in BuildRequest.from_vim().

local M = {}

local provider_registry = require("runtime.providers.registry")
local build_request_mod = require("runtime.build_request")

local function valid_profiles()
  local set = { full = true }
  for _, name in ipairs(provider_registry.list_profiles()) do
    set[name] = true
  end
  return set
end

---@return string
local function resolve_profile()
  local raw = vim.g.ltos_profile
  if raw == nil then
    return "full"
  end
  if valid_profiles()[raw] then
    return raw
  end
  vim.notify(('[ltos] invalid profile %q — falling back to "full"'):format(tostring(raw)), vim.log.levels.WARN)
  return "full"
end

---@param modules string[]
---@return table<string, string>
local function compute_module_hashes(modules)
  local util = require("core.kernel.util")
  local hashes = {}
  for _, mod in ipairs(modules) do
    local path = vim.api.nvim_get_runtime_file(mod:gsub("%.", "/") .. ".lua", false)[1]
    if path then
      hashes[mod] = util.file_content_hash(path) or "?"
    end
  end
  return hashes
end

---@param payload any
---@return { caps: table, module_hashes?: table<string, string> }|nil
local function normalise_ast_payload(payload)
  if not payload then
    return nil
  end
  if payload.caps then
    return payload
  end
  if type(payload) == "table" then
    return { caps = payload, module_hashes = {} }
  end
  return nil
end

---@param modules string[]
---@param cached_entry { caps: table, module_hashes?: table<string, string> }
---@return "skip"|"partial"|"full"
---@return table|nil
local function ast_reuse_strategy(modules, cached_entry)
  local current = compute_module_hashes(modules)
  local old = cached_entry.module_hashes or {}
  local all_match = true
  local any_match = false

  for _, mod in ipairs(modules) do
    if old[mod] and old[mod] == current[mod] then
      any_match = true
    else
      all_match = false
    end
  end

  if all_match and next(old) ~= nil then
    return "skip", cached_entry.caps
  end
  if any_match then
    return "partial", { caps = cached_entry.caps, module_hashes = old, current_hashes = current }
  end
  return "full", nil
end

---@param modules string[]
---@param profile string
---@return table[]|nil
local function try_cache(modules, profile)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile)
  if key == "" then
    return nil
  end

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
---@param specs table[]
local function persist_cache(modules, profile, specs)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile)
  if key ~= "" then
    cache.save("spec", key, specs)
  end
end

---@param modules string[]
---@param profile string
---@return table|nil
local function try_ast_cache(modules, profile)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile)
  if key == "" then
    return nil
  end
  local cached = normalise_ast_payload(cache.load("ast", key))
  if cached then
    if vim.g.ltos_debug or vim.g.ltos_debug_cache then
      vim.notify("[ltos] ast cache hit — evaluating incremental reuse", vim.log.levels.DEBUG)
    end
    return cached
  end
  return nil
end

---@param modules string[]
---@param profile string
---@param caps table
---@param module_hashes table<string, string>
local function persist_ast_cache(modules, profile, caps, module_hashes)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile)
  if key ~= "" then
    cache.save("ast", key, { caps = caps, module_hashes = module_hashes or {} })
  end
end

---@return string[]
function M.lang_modules()
  return provider_registry.resolve(resolve_profile())
end

M.LANG_MODULES = setmetatable({}, {
  __index = function()
    return M.lang_modules()
  end,
  __len = function()
    return #M.lang_modules()
  end,
  __pairs = function()
    return pairs(M.lang_modules())
  end,
  __ipairs = function()
    return ipairs(M.lang_modules())
  end,
})

---@return table[]
function M.build()
  local profile = resolve_profile()
  local modules = provider_registry.resolve(profile)
  local req = build_request_mod.from_vim(profile, modules)

  local cached = try_cache(modules, profile)
  if cached then
    return cached
  end

  local cached_ast = try_ast_cache(modules, profile)
  local cached_caps = nil
  local ast_seed = nil

  if cached_ast then
    local strategy, seed = ast_reuse_strategy(modules, cached_ast)
    if strategy == "skip" then
      cached_caps = seed
    elseif strategy == "partial" then
      ast_seed = seed
      if vim.g.ltos_debug or vim.g.ltos_debug_cache then
        vim.notify("[ltos] ast partial invalidation — incremental collect", vim.log.levels.DEBUG)
      end
    end
  end

  local pipeline = require("runtime.pipeline")
  local specs, run_ir = pipeline.run(modules, profile, cached_caps, ast_seed, req)

  persist_cache(modules, profile, specs)

  if run_ir and run_ir.caps then
    local hashes = (run_ir.meta and run_ir.meta.module_hashes) or compute_module_hashes(modules)
    persist_ast_cache(modules, profile, run_ir.caps, hashes)
  end
  return specs
end

function M.setup_commands()
  require("runtime.commands").setup()
end

return M
