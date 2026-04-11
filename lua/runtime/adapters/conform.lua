-- ~/.config/nvim/lua/runtime/adapters/conform.lua
-- Backend layer: IR → conform.nvim LazySpec.
-- Builds formatters_by_ft from IR.caps.
-- FormatterNode.fn closures are preserved as conform custom formatters.

local M = {}

---@param ir table
---@return table[]
function M.build(ir)
  if not ir.caps then
    vim.notify("[ltos:conform] IR missing required field: caps", vim.log.levels.WARN)
    return {}
  end

  -- Merge all formatter maps across caps: { [ft]: (string|fun)[] }
  local formatters_by_ft = {}

  for _, cap in pairs(ir.caps) do
    if cap.formatters then
      for ft, fmts in pairs(cap.formatters) do
        if not formatters_by_ft[ft] then
          formatters_by_ft[ft] = {}
        end
        for _, v in ipairs(fmts) do
          if type(v) == "string" then
            -- Plain formatter name
            formatters_by_ft[ft][#formatters_by_ft[ft] + 1] = v
          elseif type(v) == "table" and v.kind == "formatter" then
            if v.fn then
              -- FormatterNode with resolved fn → conform stop_after_first wrapper
              formatters_by_ft[ft][#formatters_by_ft[ft] + 1] = {
                -- conform supports function formatters via a custom entry
                -- We use a { name, fn } pattern via conform's formatters table
                name = v.name or v.strategy or "ltos_dynamic",
                fn = v.fn,
              }
            elseif v.name then
              formatters_by_ft[ft][#formatters_by_ft[ft] + 1] = v.name
            end
          end
        end
      end
    end
  end

  return {
    {
      "stevearc/conform.nvim",
      _source = "ltos:conform",
      opts = {
        formatters_by_ft = formatters_by_ft,
        format_on_save = false, -- controlled by vim.g.autoformat via LazyVim
        default_format_opts = {
          timeout_ms = 3000,
          async = false,
          quiet = false,
          lsp_fallback = true,
        },
      },
    },
  }
end

return M
