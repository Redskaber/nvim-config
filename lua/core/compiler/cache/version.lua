-- lua/core/compiler/cache/version.lua
-- Single source of truth for cache / IR schema version numbers.
-- Bump CACHE_VERSION when serialized cache payload format changes.
-- Bump SCHEMA_VERSION when IR field semantics change (usually in lockstep).

local M = {}

M.CACHE_VERSION = 4
M.SCHEMA_VERSION = 4

return M
