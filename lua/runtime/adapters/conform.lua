-- lua/runtime/adapters/conform.lua
-- REFACTOR (TODO-5.4): pure IR reader — no vim.notify, no vim API calls.
-- Missing IR fields: return { error = "..." } for emitter to surface.

local M = {}

---@param ir table
---@return table[]  LazySpec[] or { _error = string }[]
function M.build(ir)
  if not ir.caps then
    -- Pure return; emitter will surface this as a warning
    return { { _ltos_error = "[ltos:conform] IR missing field: caps" } }
  end

  local formatters_by_ft = {}

  for _, cap in pairs(ir.caps) do
    if cap.formatters then
      for ft, fmts in pairs(cap.formatters) do
        if not formatters_by_ft[ft] then
          formatters_by_ft[ft] = {}
        end
        for _, v in ipairs(fmts) do
          if type(v) == "string" then
            formatters_by_ft[ft][#formatters_by_ft[ft] + 1] = v
          elseif type(v) == "table" and v.kind == "formatter" then
            if v.fn then
              formatters_by_ft[ft][#formatters_by_ft[ft] + 1] = {
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
        format_on_save = false,
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
