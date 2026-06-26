-- lua/runtime/emitter/init.lua
-- Runtime emitter: the ONLY layer allowed to call vim API side-effects
-- during codegen output assembly.
--
-- REFACTOR (TODO-5.4):
--   • Adapters produce data (LazySpec tables) — no vim.notify in hot path.
--   • Emitter assembles specs + surfaces warnings via vim.notify.
--   • This preserves the contract: adapters/*.lua = pure IR readers.

local M = {}

--- Drive all adapters, surface warnings, return flat LazySpec[].
---@param ir      table   LIR-stage IR
---@param adapters string[]  ordered adapter module paths
---@return table[]  LazySpec[]
function M.emit(ir, adapters)
  local specs = {}

  for _, adapter_path in ipairs(adapters) do
    local ok, adapter = pcall(require, adapter_path)
    if not ok then
      -- Emitter surfaces the load failure (vim API side-effect)
      vim.notify(
        ("[emitter] failed to load adapter %s: %s"):format(adapter_path, tostring(adapter)),
        vim.log.levels.ERROR
      )
    elseif type(adapter.build) ~= "function" then
      vim.notify(("[emitter] adapter %s has no build()"):format(adapter_path), vim.log.levels.WARN)
    else
      local build_ok, result = pcall(adapter.build, ir)
      if build_ok and type(result) == "table" then
        for _, spec in ipairs(result) do
          specs[#specs + 1] = spec
        end
      elseif not build_ok then
        vim.notify(
          ("[emitter] adapter %s build() failed: %s"):format(adapter_path, tostring(result)),
          vim.log.levels.WARN
        )
      end
    end
  end

  return specs
end

return M