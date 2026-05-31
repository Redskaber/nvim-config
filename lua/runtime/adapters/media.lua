-- lua/runtime/adapters/media.lua
-- P3: Capability adapter for 'media' cap_type.
-- Generates LazySpecs for media-related plugins.

local M = {}

local util = require("core.kernel.util")

--- Builds LazySpecs for media capabilities.
---@param ir IR The current Intermediate Representation.
---@param caps_by_name table<string, table>  Map of module_name to media capability tables.
---@return LazySpec[]  An array of LazySpecs.
function M.build(ir, caps_by_name)
  if not caps_by_name or util.tbl_isempty(caps_by_name) then
    return {}
  end

  local specs = {}
  local seen_viewers = {}
  local mason_packages = {}

  for mod_name, cap in pairs(caps_by_name) do
    if cap.viewers then
      for _, viewer_entry in ipairs(cap.viewers) do
        if viewer_entry.plugin and not seen_viewers[viewer_entry.plugin] then
          table.insert(specs, {
            viewer_entry.plugin,
            opts = viewer_entry.opts or {},
            _source = ("ltos:cap:media:viewer:%s"):format(viewer_entry.plugin),
          })
          seen_viewers[viewer_entry.plugin] = true
        end
      end
    end

    if cap.mason then
      if type(cap.mason) == "table" then
        for _, pkg in ipairs(cap.mason) do
          mason_packages[pkg] = true
        end
      else
        mason_packages[cap.mason] = true
      end
    end
  end

  -- Add mason spec for all collected mason packages
  local ensure_installed_mason = {}
  for pkg in pairs(mason_packages) do
    table.insert(ensure_installed_mason, pkg)
  end
  if #ensure_installed_mason > 0 then
    table.insert(specs, {
      "mason.nvim",
      opts = function(_, opts)
        opts.ensure_installed = opts.ensure_installed or {}
        util.list_extend(opts.ensure_installed, ensure_installed_mason)
      end,
      _source = "ltos:cap:media:mason",
    })
  end

  return specs
end

return M
