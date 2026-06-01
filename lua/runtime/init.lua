-- ~/.config/nvim/lua/runtime/init.lua
-- Compiler kernel: orchestrator.
-- P6-C2: Explicitly calls registry.setup() and cap_registry.setup()
--        instead of relying on require-time side effects.

local M = {}

require("runtime.ports_bootstrap").setup()
require("runtime.types_bootstrap").setup() -- Configure abstract type interfaces

-- P6-C2: Bootstrap registries explicitly before any pipeline use
require("runtime.adapters.registry").setup()
require("runtime.adapters.cap_registry").setup()

local provider_registry = require("runtime.providers.registry")
local build_request_mod = require("runtime.build_request")
local util = require("core.kernel.util")

local function valid_profiles()
  local set = { full = true }
  for _, name in ipairs(provider_registry.list_profiles()) do
    set[name] = true
  end
  return set
end

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

local function cap_modules()
  return require("runtime.passes.collect_ext").registered()
end

local function compute_module_hashes(modules)
  local hashes = {}
  for _, mod in ipairs(modules) do
    local path = vim.api.nvim_get_runtime_file(mod:gsub("%.", "/") .. ".lua", false)[1]
    if path then
      hashes[mod] = util.file_content_hash(path) or "?"
    end
  end
  return hashes
end

local function compute_all_hashes(lang_modules, cap_mods)
  local all = {}
  for _, m in ipairs(lang_modules) do
    all[#all + 1] = m
  end
  for _, m in ipairs(cap_mods) do
    all[#all + 1] = m
  end
  return compute_module_hashes(all)
end

local function normalise_ast_payload(payload)
  if not payload then
    return nil
  end
  if payload.caps then
    return payload
  end
  if type(payload) == "table" then
    return { caps = payload, module_hashes = {}, ext_caps = {} }
  end
  return nil
end

local function ast_reuse_strategy(lang_modules, cap_mods, cached_entry)
  local tracked = {}
  for _, m in ipairs(lang_modules) do
    tracked[#tracked + 1] = m
  end
  for _, m in ipairs(cap_mods) do
    tracked[#tracked + 1] = m
  end

  local current = compute_module_hashes(tracked)
  local old = cached_entry.module_hashes or {}
  local all_match = #tracked > 0
  local any_match = false

  for _, mod in ipairs(tracked) do
    if old[mod] and old[mod] == current[mod] then
      any_match = true
    else
      all_match = false
    end
  end

  if all_match then
    return "skip", { caps = cached_entry.caps, ext_caps = cached_entry.ext_caps }
  end
  if any_match then
    return "partial",
      {
        caps = cached_entry.caps,
        ext_caps = cached_entry.ext_caps,
        module_hashes = old,
        current_hashes = current,
      }
  end
  return "full", nil
end

local function try_cache(modules, profile)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile, cap_modules())
  if key == "" then
    return nil
  end
  return cache.load("spec", key)
end

local function persist_cache(modules, profile, specs)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile, cap_modules())
  if key ~= "" then
    cache.save("spec", key, specs)
  end
end

local function try_ast_cache(modules, profile)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile, cap_modules())
  if key == "" then
    return nil
  end
  return normalise_ast_payload(cache.load("ast", key))
end

local function persist_ast_cache(modules, profile, caps, ext_caps, module_hashes)
  local cache = require("core.compiler.cache")
  local key = cache.key(modules, profile, cap_modules())
  if key ~= "" then
    cache.save("ast", key, {
      caps = caps,
      ext_caps = ext_caps or {},
      module_hashes = module_hashes or {},
    })
  end
end

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

function M.build()
  local lifecycle = require("runtime.lifecycle")
  if lifecycle.state() == "READY" then
    lifecycle.transition("HOT_RELOAD")
  end
  lifecycle.transition("SCHEMA_LOAD")

  local profile = resolve_profile()
  local modules = provider_registry.resolve(profile)
  local caps = cap_modules()
  local req = build_request_mod.from_vim(profile, modules)

  lifecycle.transition("COMPILE")

  local cached = try_cache(modules, profile)
  if cached then
    lifecycle.transition("EMIT")
    lifecycle.transition("READY")
    return cached
  end

  local cached_ast = try_ast_cache(modules, profile)
  local cached_caps = nil
  local ast_seed = nil

  if cached_ast then
    local strategy, seed = ast_reuse_strategy(modules, caps, cached_ast)
    if strategy == "skip" then
      cached_caps = seed.caps
      ast_seed = { ext_caps = seed.ext_caps }
    elseif strategy == "partial" then
      ast_seed = seed
    end
  end

  local pipeline = require("runtime.pipeline")
  local specs, run_ir = pipeline.run(modules, profile, cached_caps, ast_seed, req)

  lifecycle.transition("EMIT")
  require("runtime.emitter.cap_effects").apply_all(run_ir)
  persist_cache(modules, profile, specs)

  if run_ir and run_ir.caps then
    local hashes = run_ir.meta and run_ir.meta.module_hashes or compute_all_hashes(modules, caps)
    persist_ast_cache(modules, profile, run_ir.caps, run_ir.ext_caps, hashes)
  end

  lifecycle.transition("READY")
  return specs
end

function M.setup_commands()
  require("runtime.commands").setup()
end

return M
