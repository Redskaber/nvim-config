-- lua/runtime/adapters/ai_cap.lua
-- P3: Capability adapter for 'ai' cap_type with the new caps_by_name signature.
-- Generates LazySpecs for AI-related plugins.

local M = {}

local util = require("core.kernel.util")

--- Builds LazySpecs for AI capabilities.
---@param ir IR The current Intermediate Representation.
---@param caps_by_name table<string, table>  Map of module_name to AI capability tables.
---@return LazySpec[]  An array of LazySpecs.
function M.build(ir, caps_by_name)
  if not caps_by_name or util.tbl_isempty(caps_by_name) then
    return {}
  end

  local specs = {}
  local completion_providers = {}
  local chat_providers = {}
  local seen_plugins = {}

  for mod_name, cap in pairs(caps_by_name) do
    if cap.completion and cap.completion.provider then
      completion_providers[cap.completion.provider] = true
    end
    if cap.chat and cap.chat.provider then
      chat_providers[cap.chat.provider] = true
    end

    -- Collect unique plugins (if any are specified within the AI cap)
    if cap.plugins then
      for _, plugin_entry in ipairs(cap.plugins) do
        if not seen_plugins[plugin_entry.name] then
          table.insert(specs, {
            plugin_entry.name,
            opts = plugin_entry.opts or {},
            _source = ("ltos:cap:ai:%s"):format(plugin_entry.name),
          })
          seen_plugins[plugin_entry.name] = true
        end
      end
    end
  end

  -- Add specs based on collected providers
  if completion_providers.copilot then
    table.insert(specs, {
      "github/copilot.vim",
      _source = "ltos:cap:ai:copilot",
    })
  end
  -- Add other completion/chat providers as needed
  -- For example, for codeium, codecompanion, avante, etc.

  return specs
end

return M
