-- lua/plugins/init.lua
-- Layer 5 · app — plugin registry aggregator.
--
-- Single entry point for lazy.nvim's { import = "plugins" }.
-- lazy.nvim's lsmod() picks up this init.lua automatically when scanning
-- the plugins/ directory.
--
-- FIX-ROBUST-V2 (2026-06-23): Convention-based auto-discovery.
--
-- ═══════════════════════════════════════════════════════════════════════════
-- LOADING CONVENTION
-- ═══════════════════════════════════════════════════════════════════════════
--
-- What gets auto-loaded:
--   Files that return a LazySpec table (plugin declaration).
--
-- What does NOT get auto-loaded:
--   1. init.lua (this file — the aggregator)
--   2. Files starting with _ (underscore = private/helper module)
--      e.g. _utils.lua, _helpers.lua
--   3. Files that don't return a table (library modules)
--      e.g. transparency.lua (returns M, not a spec table)
--
-- Why this convention:
--   - Plugin spec files always `return { ... }` (LazySpec table)
--   - Helper/library files use `local M = {} ... return M` or don't return
--   - The underscore prefix is a common Lua convention for "private"
--   - This is deterministic: no whitelist/blacklist maintenance
--
-- How to add a new plugin:
--   1. Create lua/plugins/<category>/<name>.lua
--   2. Make it `return { ... }` (LazySpec table)
--   3. Done — auto-discovered on next startup
--
-- How to add a helper module (not a plugin):
--   Option A: Name it with _ prefix: _helper.lua
--   Option B: Don't return a table (return M or nothing)
--   Either way, it won't be auto-loaded as a plugin spec.
--
-- ═══════════════════════════════════════════════════════════════════════════

local specs = {}

-- Auto-discover all .lua files under plugins/ (recursively).
local plugin_files = vim.fn.globpath(vim.o.rtp, "lua/plugins/**/*.lua", true, true)

-- Sort for deterministic load order (important for spec merge priority)
table.sort(plugin_files)

for _, filepath in ipairs(plugin_files) do
  local basename = filepath:match("([^/]+)%.lua$")

  -- Skip rules:
  -- 1. init.lua (this file)
  -- 2. Files starting with _ (private/helper modules by convention)
  if basename ~= "init" and basename:sub(1, 1) ~= "_" then
    -- Convert filepath to module name: lua/plugins/ai/ai.lua -> plugins.ai.ai
    local modname = filepath:match("lua/(plugins/.+)%.lua$")
    if modname then
      modname = modname:gsub("/", ".")
      local ok, result = pcall(require, modname)
      if not ok then
        -- Surface load errors without crashing the whole startup
        vim.notify("[plugins.init] failed to load " .. modname .. ":\n" .. tostring(result), vim.log.levels.ERROR)
      elseif type(result) == "table" then
        -- only accept tables that look like LazySpec.
        -- A LazySpec is either:
        --   - A table with [1] = "repo/name" (string) — single spec
        --   - A table where [1] is itself a table — list of specs
        -- Library modules (local M = {} ... return M) return tables too,
        -- but they don't have [1] as string or table-of-tables.
        --
        -- Heuristic: if result[1] is a string (repo name) or a table (spec),
        -- treat it as LazySpec. Otherwise skip (it's a library module).
        local is_spec = false
        if #result > 0 then
          if type(result[1]) == "string" then
            -- Single spec: { "repo/name", opts = {...} }
            is_spec = true
          elseif type(result[1]) == "table" then
            -- List of specs: { { "repo1" }, { "repo2" } }
            is_spec = true
          end
        end

        if is_spec then
          if type(result[1]) == "table" then
            -- List of specs: flatten into specs
            for _, spec in ipairs(result) do
              specs[#specs + 1] = spec
            end
          else
            -- Single spec table
            specs[#specs + 1] = result
          end
        end
        -- If not is_spec: silently skip (library module like transparency.lua)
      end
    end
  end
end

return specs
