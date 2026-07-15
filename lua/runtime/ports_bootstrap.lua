-- lua/runtime/ports_bootstrap.lua
-- Layer 4: wire vim host APIs into core/compiler ports (once per session).
--
-- FIX (2026-07-15): _done guard is removed so that setup() can be called
-- again after a spec (e.g. ports_spec) resets ports to broken defaults via
-- its after_each. The configure() call is idempotent (overwrites all keys),
-- so calling it multiple times is safe. The _done flag was preventing
-- re-configuration after test suites polluted the ports state.

local M = {}

function M.setup()
  local ports = require("core.compiler.ports")
  ports.configure({
    cache_dir = function() return vim.fn.stdpath("cache") .. "/ltos" end,
    json_encode = function(t) return vim.json.encode(t) end,
    json_decode = function(s) return vim.json.decode(s) end,
    read_file = function(path)
      local f = io.open(path, "r")
      if not f then
        return nil
      end
      local content = f:read("*a")
      f:close()
      return content
    end,
    resolve_runtime_file = function(rel)
      local results = vim.api.nvim_get_runtime_file(rel, false)
      return results and results[1]
    end,
    debug_cache = function() return vim.g.ltos_debug == true or vim.g.ltos_debug_cache == true end,
    notify = function(level, msg) vim.notify(msg, level) end,
    ensure_cache_dir = function(dir)
      if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
      end
    end,
  })

  if vim.g.ltos_debug_invariants then
    require("core.compiler.invariants").enable()
  end
end

return M