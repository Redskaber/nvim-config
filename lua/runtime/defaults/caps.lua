-- lua/runtime/defaults/caps.lua
-- Default external capability module list (P3: data-driven, no hardcode in passes).
--
-- FIX-ROBUST-V2 (2026-06-23): Convention-based auto-discovery for cap modules.
--
-- ═══════════════════════════════════════════════════════════════════════════
-- LOADING CONVENTION
-- ═══════════════════════════════════════════════════════════════════════════
--
-- What gets auto-loaded:
--   Files in modules/cap/, modules/editor/, modules/ai/, modules/keybind/
--   that return a DSL table with `cap_type` and `version` fields.
--
-- What does NOT get auto-loaded:
--   1. init.lua (if exists)
--   2. Files starting with _ (underscore = private/helper)
--   3. Files that don't have cap_type + version (not valid DSL)
--
-- Why this convention:
--   - All cap DSL modules have `cap_type` and `version` fields (INV-8)
--   - Helper modules don't have these fields
--   - ext_schema.validate() will reject invalid modules anyway
--   - This is deterministic: no whitelist maintenance
--
-- modules/capability/ is NOT in the discovery paths — it's the meta-layer
-- (graph/lifecycle/registry/schema), not cap declarations.
--
-- ═══════════════════════════════════════════════════════════════════════════

local M = {}

--- Auto-discover all cap module paths.
--- Only files that look like cap DSL (have cap_type + version) are included.
---@return string[]
function M.discover()
  local paths = {}

  -- Discovery directories (relative to lua/)
  -- These are the ONLY directories that contain cap DSL modules.
  -- modules/capability/ is intentionally excluded (meta-layer, not DSL).
  -- modules/lang/ is handled separately by provider_interface.discover().
  local dirs = {
    "modules/cap",
    "modules/editor",
    "modules/ai",
    "modules/keybind",
  }

  for _, dir in ipairs(dirs) do
    local files = vim.fn.globpath(vim.o.rtp, "lua/" .. dir .. "/*.lua", true, true)
    for _, filepath in ipairs(files) do
      local basename = filepath:match("([^/]+)%.lua$")

      -- Skip rules:
      -- 1. init.lua
      -- 2. Files starting with _ (private/helper by convention)
      if basename ~= "init" and basename:sub(1, 1) ~= "_" then
        -- Convert: lua/modules/cap/image.lua -> modules.cap.image
        local modname = filepath:match("lua/(modules/.+)%.lua$")
        if modname then
          modname = modname:gsub("/", ".")

          -- FIX-ROBUST-V2: validate that the module is a cap DSL before including.
          -- This prevents helper modules (e.g. utils.lua) from being loaded as caps.
          -- A valid cap DSL has `cap_type` (string) and `version` (number) fields.
          local ok, mod = pcall(require, modname)
          if
            ok
            and type(mod) == "table"
            and type(mod.cap_type) == "string"
            and type(mod.version) == "number"
          then
            paths[#paths + 1] = modname
          end
          -- If not valid cap DSL: silently skip (helper module)
        end
      end
    end
  end

  -- Sort for deterministic order
  table.sort(paths)

  return paths
end

-- Backward-compatible: return table with .modules key
-- This is consumed by collect_ext.setup() which expects { modules = { ... } }
M.modules = M.discover()

return M
