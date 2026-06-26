-- lua/runtime/adapters/image.lua
-- P3: Capability adapter for 'image' cap_type.

local M = {}

local util = require("core.kernel.util")

local IMAGE_NVIM = "3rd/image.nvim"
local CHAFA_NVIM = "princejoogie/chafa.nvim"

---@param ir IR
---@param caps_by_name table<string, table>
---@return LazySpec[]
function M.build(ir, caps_by_name)
  if util.tbl_isempty(caps_by_name) then
    return {}
  end

  local specs = {}
  local image_nvim_opts = { integrations = {} }
  local chafa_needed = false
  local seen_plugins = {}

  for _, cap in pairs(caps_by_name) do
    if cap.max_width then
      image_nvim_opts.max_width = cap.max_width
    end
    if cap.max_height then
      image_nvim_opts.max_height = cap.max_height
    end

    if cap.integrations and cap.integrations.markdown then
      image_nvim_opts.integrations.markdown = { enabled = true }
    end

    if cap.fallback == "chafa" then
      chafa_needed = true
    end

    if cap.plugins then
      for _, plugin_entry in ipairs(cap.plugins) do
        local name = plugin_entry.name
        if type(name) == "string" and not seen_plugins[name] then
          specs[#specs + 1] = {
            name,
            opts = plugin_entry.opts or {},
            _source = ("ltos:cap:image:%s"):format(name),
          }
          seen_plugins[name] = true
        end
      end
    end
  end

  if not seen_plugins[IMAGE_NVIM] then
    specs[#specs + 1] = {
      IMAGE_NVIM,
      opts = image_nvim_opts,
      _source = "ltos:cap:image",
    }
  end

  if chafa_needed and not seen_plugins[CHAFA_NVIM] then
    specs[#specs + 1] = {
      CHAFA_NVIM,
      _source = "ltos:cap:image:chafa",
    }
  end

  return specs
end

return M

