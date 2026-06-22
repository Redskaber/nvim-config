-- lua/runtime/adapters/ai.lua
-- P3: Capability adapter for 'ai' cap_type (old signature: build(ir)).
-- Generates LazySpecs for AI-related plugins.

local M = {}

local util = require("core.kernel.util")

--- Builds LazySpecs for AI capabilities (old signature).
---@param ir IR The current Intermediate Representation.
---@return LazySpec[]  An array of LazySpecs.
function M.build(ir)
  local specs = {}
  local ai_caps = ir.ext_caps and ir.ext_caps.ai or {}

  if util.tbl_isempty(ai_caps) then
    return {}
  end

  local completion_providers = {}
  local chat_providers = {}
  local seen_plugins = {}

  for mod_name, cap in pairs(ai_caps) do
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

  return specs
end

return M