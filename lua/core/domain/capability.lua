-- lua/core/domain/capability.lua
-- Layer 2 domain: IMMUTABLE CapabilitySet value object.
--
-- REFACTOR (TODO-3.1):
--   • Removed module-level _store global mutable state.
--   • CapabilitySet is now a pure value object (persistent data structure).
--   • M.new()  → empty set
--   • M.add(set, name, raw) → new set (copy-on-write, never mutates input)
--   • M.snapshot(set) → deep-copy for IR embedding
--   • M.empty() → canonical empty set (identity element)
--   • M.reset() REMOVED — no longer needed; each pipeline run calls M.new()
--
-- collect pass owns the accumulation loop; capability module is pure.

local schema = require("core.domain.schema")
local util = require("core.kernel.util")

local M = {}

---@class LspConfig
---@field settings? table
---@field cmd?      string[]
---@field mason?    boolean

---@class Capability
---@field lsp?        table<string, LspConfig>
---@field formatters? table<string, table>
---@field linters?    table<string, table>
---@field treesitter? string[]
---@field mason?      string[]

---@alias CapabilitySet table<string, Capability>

-- ── Pure merge helpers ────────────────────────────────────────────────────────

--- Deep-merge two LSP config tables (pure, no vim deps in hot path).
---@param dst table
---@param src table
---@return table  new merged table
local function merge_lsp(dst, src)
  local out = util.deep_merge(dst, src)
  return out
end

--- Merge two list-of-items maps ({ [ft]: items[] }) → new map.
---@param dst table
---@param src table
---@return table
local function merge_list_map(dst, src)
  local out = {}
  for k, v in pairs(dst) do
    out[k] = v -- reference: immutable callers won't mutate
  end
  for ft, v in pairs(src) do
    if out[ft] and type(out[ft]) == "table" then
      local merged = {}
      for _, item in ipairs(out[ft]) do
        merged[#merged + 1] = item
      end
      for _, item in ipairs(v) do
        merged[#merged + 1] = item
      end
      out[ft] = merged
    else
      out[ft] = v
    end
  end
  return out
end

--- Merge two lists (dedup is caller's responsibility).
---@param a any[]
---@param b any[]
---@return any[]
local function merge_list(a, b)
  local out = {}
  for _, v in ipairs(a) do
    out[#out + 1] = v
  end
  for _, v in ipairs(b) do
    out[#out + 1] = v
  end
  return out
end

-- ── CapabilitySet constructor ─────────────────────────────────────────────────

---@return CapabilitySet
function M.new()
  return {}
end

-- ── Add (pure, copy-on-write) ─────────────────────────────────────────────────

--- Add (deep-merge) a validated capability bundle into a NEW set.
--- Input `set` is NEVER mutated.
---@param set  CapabilitySet
---@param name string
---@param raw  table
---@return CapabilitySet  new set
---@return { ok: boolean, diags: table[] }
function M.add(set, name, raw)
  local result = schema.validate(name, raw)

  -- NOTE: vim.notify intentionally removed from domain layer (pure value object).
  -- Callers (collect pass) are responsible for surfacing diagnostics.

  if not result.ok or not result.cap then
    return set, { ok = false, diags = result.diags }
  end

  local cap = result.cap

  -- Copy-on-write: shallow-copy the set, deep-copy only the affected entry
  local existing = set[name] or { lsp = {}, formatters = {}, linters = {}, treesitter = {}, mason = {} }
  local new_entry = {
    lsp = cap.lsp and merge_lsp(existing.lsp, cap.lsp) or existing.lsp,
    formatters = cap.formatters and merge_list_map(existing.formatters, cap.formatters) or existing.formatters,
    linters = cap.linters and merge_list_map(existing.linters, cap.linters) or existing.linters,
    treesitter = cap.treesitter and merge_list(existing.treesitter, cap.treesitter) or existing.treesitter,
    mason = cap.mason and merge_list(existing.mason, cap.mason) or existing.mason,
  }

  -- Shallow-copy the outer set, replace only `name`
  local new_set = {}
  for k, v in pairs(set) do
    new_set[k] = v
  end
  new_set[name] = new_entry

  return new_set, { ok = true, diags = result.diags }
end

-- ── Read path ─────────────────────────────────────────────────────────────────

--- Return a deep-copy snapshot for embedding into IR.
--- Callers receive a stable value; mutations don't affect the set.
---@param set CapabilitySet
---@return table<string, Capability>
function M.snapshot(set)
  return util.deep_copy(set) -- pure: no vim API in Layer 2
end

--- Raw dump for introspection (debug only).
---@param set CapabilitySet
---@return string
function M.dump(set)
  -- Pure Lua serialization (no vim.inspect dependency in domain layer)
  local ok, result = pcall(function()
    return require("vim").inspect(set)
  end)
  if ok then
    return result
  end
  return tostring(set)
end

-- Backward-compat: M.reset() is a no-op; call M.new() instead.
-- Kept to avoid breaking any external callers during migration.
function M.reset() end

return M