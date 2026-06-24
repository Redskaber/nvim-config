-- lua/core/compiler/cache/version.lua
-- Single source of truth for cache / IR schema version numbers.
-- Bump CACHE_VERSION when serialized cache payload format changes.
-- Bump SCHEMA_VERSION when IR field semantics change (usually in lockstep).
--
-- Version history:
--   v5: P3 - cap modules introduced
--   v6: P6-B - Diagnostic moved to domain layer, cap_types centralized,
--              keybind presets centralized, cap modules hash in cache key
--   v7: P6-C4 - ir_version field added to IR.meta; cache policy validates
--               schema version consistency on load

local M = {}

M.CACHE_VERSION = 7
M.SCHEMA_VERSION = 7

return M
