-- lua/runtime/adapters/conform.lua
-- REFACTOR (TODO-5.4): pure IR reader — no side-effects, no vim API calls.
-- Missing IR fields: return { error = "..." } for emitter to surface.

local M = {}

-- Jump-table for formatter node dispatch.
-- Each handler receives (node, custom_formatters_map) and returns:
--   string — the conform formatter name to add to formatters_by_ft
--   nil    — skip this node (invalid or incomplete)
--
-- To add a new formatter node type:
--   1. Write handler: local function handle_mytype(node, cf) ... return name end
--   2. Register: FORMATTER_HANDLERS["mytype"] = handle_mytype
-- No changes needed to the main loop — it dispatches via the map.
local FORMATTER_HANDLERS = {}

-- Handler: plain string formatter ("stylua")
FORMATTER_HANDLERS["string"] = function(v, _cf) return v end

-- Handler: FormatterNode table ({ kind = "formatter", strategy = ..., fn = ..., name = ... })
FORMATTER_HANDLERS["table"] = function(v, cf)
  if v.kind ~= "formatter" then
    return nil
  end

  local strategy = v.strategy
  local name = v.name

  if strategy and v.fn then
    -- Strategy with resolve function: register as custom conform formatter.
    -- The strategy name becomes a conform formatter name; conform calls
    -- our format() at format time, which calls v.fn(bufnr) dynamically.
    cf[strategy] = v.fn
    return strategy
  elseif name and type(name) == "string" then
    -- No strategy, but has explicit name — use as plain string
    return name
  elseif strategy then
    -- Strategy without fn (normalize didn't run?) — use strategy name.
    -- conform may not know it, but it won't crash.
    return strategy
  end
  -- Neither strategy nor name: skip
  return nil
end

-- Use conform's custom formatter mechanism.
--
-- Previous attempts failed because:
--   v1: Output { name, fn } table → conform rejects table elements in formatters_by_ft
--   v2: Hardcoded STRATEGY_EXPANSION map → brittle, breaks on plugin updates
--   v2.5: Parse strategy name "A_or_B" → names don't match conform formatter names
--         (e.g., "ruff_or_black" → "ruff" but conform expects "ruff_format")
--
-- Correct approach: register strategy as a conform custom formatter.
-- conform supports custom formatters via:
--   require("conform").formatters[strategy_name] = {
--     command = ..., -- or
--     format = function(self, ctx, lines) ... end,
--   }
--
-- But conform's formatters_by_ft still only accepts strings.
-- So we:
--   1. Register each strategy as a custom conform formatter (in config function)
--   2. Use the strategy name as a string in formatters_by_ft
--   3. conform calls the custom formatter's format() at format time
--
-- The custom formatter's format() calls v.fn(bufnr) to get the actual
-- formatter list, then delegates to the first available conform formatter.
-- This preserves the runtime availability checking that builtin.lua's
-- resolve() provides.

---@param ir table
---@return table[]  LazySpec[] or { _error = string }[]
function M.build(ir)
  if not ir.caps then
    return { { _ltos_error = "[ltos:conform] IR missing field: caps" } }
  end

  local formatters_by_ft = {}
  -- Collect strategies that need custom formatter registration
  -- Map: strategy_name → fn (the resolve function injected by normalize)
  local custom_formatters = {}

  for _, cap in pairs(ir.caps) do
    if cap.formatters then
      for ft, fmts in pairs(cap.formatters) do
        -- FIX (2026-06-24): Skip empty formatter lists entirely.
        -- Empty tables (e.g., { } from commented-out formatters) would
        -- create formatters_by_ft[ft] = {} which tells conform "this ft
        -- has formatters but none specified" — conform then falls back
        -- to LSP formatting. Skipping prevents unwanted LSP fallback.
        if #fmts == 0 then
          goto continue
        end
        if not formatters_by_ft[ft] then
          formatters_by_ft[ft] = {}
        end
        for _, v in ipairs(fmts) do
          -- FIX-ROBUST-V2: jump-table dispatch for formatter node types.
          -- Each handler returns a string (formatter name) or nil (skip).
          -- This replaces the if/elseif type-check chain.
          local handler = FORMATTER_HANDLERS[type(v)]
          if handler then
            local name = handler(v, custom_formatters)
            if name then
              formatters_by_ft[ft][#formatters_by_ft[ft] + 1] = name
            end
          end
        end
        ::continue::
      end
    end
  end

  return {
    {
      "stevearc/conform.nvim",
      _source = "ltos:conform",
      opts = function(_, opts)
        opts.formatters_by_ft = opts.formatters_by_ft or {}
        for ft, fmts in pairs(formatters_by_ft) do
          if not opts.formatters_by_ft[ft] then
            opts.formatters_by_ft[ft] = fmts
          else
            local seen = {}
            for _, f in ipairs(opts.formatters_by_ft[ft]) do
              seen[f] = true
            end
            for _, f in ipairs(fmts) do
              if not seen[f] then
                opts.formatters_by_ft[ft][#opts.formatters_by_ft[ft] + 1] = f
                seen[f] = true
              end
            end
          end
        end
        -- Register custom strategy formatters if any
        for strategy_name, strategy_fn in pairs(custom_formatters) do
          opts.formatters = opts.formatters or {}
          if not opts.formatters[strategy_name] then
            opts.formatters[strategy_name] = {
              format = function(self, ctx)
                local candidates = strategy_fn(ctx.bufnr) or {}
                local conform = require("conform")
                for _, fmt_name in ipairs(candidates) do
                  local formatter = conform.formatters[fmt_name]
                  if formatter and formatter.format then
                    local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
                    local result = formatter.format(formatter, ctx, lines)
                    if result and type(result) == "table" then
                      return result
                    end
                  end
                end
                return vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
              end,
            }
          end
        end
        return opts
      end,
    },
  }
end

return M
