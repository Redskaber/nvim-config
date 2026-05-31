-- lua/runtime/adapters/image.lua
-- P3: Capability adapter for 'image' cap_type.
-- Generates LazySpecs for image-related plugins.

local M = {}

local util = require("core.kernel.util")

--- Builds LazySpecs for image capabilities.
---@param ir IR The current Intermediate Representation.
---@param caps_by_name table<string, table>  Map of module_name to image capability tables.
---@return LazySpec[]  An array of LazySpecs.
function M.build(ir, caps_by_name)
  if not caps_by_name or util.tbl_isempty(caps_by_name) then
    return {}
  end

  local specs = {}
  local image_nvim_opts = {
    integrations = {},
  }
  local chaf-nvim_needed = false
  local seen_plugins = {}

  for mod_name, cap in pairs(caps_by_name) do
    -- Process image.nvim related options
    if cap.max_width then image_nvim_opts.max_width = cap.max_width end
    if cap.max_height then image_nvim_opts.max_height = cap.max_height end

    if cap.integrations then
      if cap.integrations.markdown then
        image_nvim_opts.integrations.markdown = { enabled = true }
      end
      -- Add other integrations as needed
    end

    -- Handle fallback for chafa.nvim
    if cap.fallback == "chafa" then
      chaf-nvim_needed = true
    end

    -- Collect unique plugins
    if cap.plugins then
      for _, plugin_entry in ipairs(cap.plugins) do
        if not seen_plugins[plugin_entry.name] then
          table.insert(specs, {
            plugin_entry.name,
            opts = plugin_entry.opts or {},
            _source = ("ltos:cap:image:%s"):format(plugin_entry.name),
          })
          seen_plugins[plugin_entry.name] = true
        end
      end
    end

    -- Mason packages (if any)
    if cap.mason then
      if type(cap.mason) == "table" then
        for _, pkg in ipairs(cap.mason) do
          table.insert(specs, {
            "mason.nvim",
            opts = function(_, opts)
              opts.ensure_installed = opts.ensure_installed or {}
              table.insert(opts.ensure_installed, pkg)
            end,
            _source = ("ltos:cap:image:mason:%s"):format(pkg),
          })
        end
      else
        -- Handle single mason package string if needed
      end
    end
  end

  -- Add image.nvim spec if any image capabilities were found
  if next(caps_by_name) ~= nil then
    table.insert(specs, {
      "nvim-image.lua", -- Assuming this is the main image plugin
      opts = image_nvim_opts,
      _source = "ltos:cap:image",
    })
  end

  -- Add chafa.nvim if required by fallback
  if chaf-nvim_needed then
    table.insert(specs, {
      "princejoogie/chafa.nvim",
      _source = "ltos:cap:image:chafa",
    })
  end

  return specs
end

return M
