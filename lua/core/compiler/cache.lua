-- lua/core/compiler/cache.lua
-- Layer 1 compiler: backward-compatible facade over cache/ subsystem.
-- REFACTOR: delegates to cache/key.lua + cache/store.lua + cache/policy.lua

local key_mod = require("core.compiler.cache.key")
local policy = require("core.compiler.cache.policy")

local M = {}

-- Key computation
M.key = key_mod.compute

-- Tier operations
M.load = policy.load
M.save = policy.save
M.invalidate = policy.invalidate
M.invalidate_all = policy.invalidate_all
M.stats = policy.stats
M.is_cacheable = policy.is_cacheable
M.mark_uncacheable = policy.mark_uncacheable

-- Spec-tier shorthands
function M.load_specs(key) return M.load("spec", key) end
function M.save_specs(key, specs) M.save("spec", key, specs) end

return M
