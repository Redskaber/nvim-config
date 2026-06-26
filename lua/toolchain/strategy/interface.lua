-- lua/toolchain/strategy/interface.lua
-- Layer 3 strategy: Strategy type contract (pure type annotations, no implementation).
--
-- All strategy implementations must satisfy this interface.
-- Consumers depend on this interface, not on concrete implementations.

---@class EnvContext
---@field is_nix boolean
---@field is_ssh boolean
---@field has    fun(cmd: string): boolean

---@class Strategy
---@field name     string                                        unique strategy identifier
---@field applies  fun(tool: string, env: EnvContext): boolean   returns true if this strategy handles the tool
---@field resolve  fun(bufnr: integer): string[]                 returns list of formatter/tool names for the buffer
---@field priority integer                                       higher = preferred when multiple strategies apply

-- This module exports nothing at runtime — it exists solely for LuaLS type checking.
return {}

