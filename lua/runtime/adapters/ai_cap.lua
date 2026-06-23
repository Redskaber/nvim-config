-- lua/runtime/adapters/ai_cap.lua
-- P6-C5: Complete AI capability adapter supporting all known providers.
-- Supports: copilot, codeium, codecompanion, avante.

local M = {}

local util = require("core.kernel.util")

--- Convert DSL key entries to lazy.nvim keys format.
---@param keys table[]  DSL: { lhs, rhs, mode?, desc? }
---@return table[]      lazy.nvim: { [1]=lhs, [2]=rhs, mode=, desc= }
local function to_lazy_keys(keys)
  if not keys then
    return {}
  end
  local out = {}
  for _, k in ipairs(keys) do
    out[#out + 1] = {
      k.lhs,
      k.rhs,
      mode = k.mode or "n",
      desc = k.desc,
    }
  end
  return out
end

--- Build LazySpecs from ai caps.
---@param ir IR
---@param caps_by_name table<string, table>
---@return LazySpec[]
function M.build(ir, caps_by_name)
  if not caps_by_name or util.tbl_isempty(caps_by_name) then
    return {}
  end

  local specs = {}
  local seen_plugins = {}

  -- Track which top-level provider specs to emit
  local emit_copilot = false
  local emit_codeium = false
  local emit_codecompanion = false
  local emit_avante = false

  for _, cap in pairs(caps_by_name) do
    -- Completion provider signals
    if cap.completion and cap.completion.provider then
      local p = cap.completion.provider
      if p == "copilot" then
        emit_copilot = true
      end
      if p == "codeium" then
        emit_codeium = true
      end
    end
    -- Chat provider signals
    if cap.chat and cap.chat.provider then
      local p = cap.chat.provider
      if p == "codecompanion" then
        emit_codecompanion = true
      end
      if p == "avante" then
        emit_avante = true
      end
      if p == "copilot" then
        emit_copilot = true
      end
    end

    -- Explicit plugin declarations (highest fidelity — DSL specifies exact opts/keys)
    if cap.plugins then
      for _, plugin_entry in ipairs(cap.plugins) do
        if not seen_plugins[plugin_entry.name] then
          seen_plugins[plugin_entry.name] = true

          local spec = {
            plugin_entry.name,
            _source = ("ltos:cap:ai:%s"):format(plugin_entry.name),
          }

          if plugin_entry.cmd then
            spec.cmd = plugin_entry.cmd
          end
          if plugin_entry.opts then
            spec.opts = plugin_entry.opts
          end
          if plugin_entry.keys then
            spec.keys = to_lazy_keys(plugin_entry.keys)
          end

          specs[#specs + 1] = spec

          -- Mark provider as handled (don't emit a bare spec below)
          if plugin_entry.name == "github/copilot.vim" then
            emit_copilot = false
          end
          if plugin_entry.name == "Exafunction/codeium.vim" then
            emit_codeium = false
          end
          if plugin_entry.name == "olimorris/codecompanion.nvim" then
            emit_codecompanion = false
          end
          if plugin_entry.name == "yetone/avante.nvim" then
            emit_avante = false
          end
        end
      end
    end
  end

  -- Emit bare provider specs for providers signalled but not covered by plugins[]
  if emit_copilot and not seen_plugins["github/copilot.vim"] then
    specs[#specs + 1] = {
      "github/copilot.vim",
      cmd = { "Copilot" },
      _source = "ltos:cap:ai:copilot",
    }
  end

  if emit_codeium and not seen_plugins["Exafunction/codeium.vim"] then
    specs[#specs + 1] = {
      "Exafunction/codeium.vim",
      event = { "InsertEnter" },
      _source = "ltos:cap:ai:codeium",
    }
  end

  if emit_codecompanion and not seen_plugins["olimorris/codecompanion.nvim"] then
    specs[#specs + 1] = {
      "olimorris/codecompanion.nvim",
      cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
      _source = "ltos:cap:ai:codecompanion",
    }
  end

  if emit_avante and not seen_plugins["yetone/avante.nvim"] then
    specs[#specs + 1] = {
      "yetone/avante.nvim",
      event = { "VeryLazy" },
      _source = "ltos:cap:ai:avante",
    }
  end

  return specs
end

return M