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
FORMATTER_HANDLERS["string"] = function(v, _cf)
  return v
end

-- Handler: FormatterNode table ({ kind = "formatter", strategy = ..., fn = ..., name = ... })
FORMATTER_HANDLERS["table"] = function(v, cf)
  if v.kind ~= "formatter" then return nil end

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
      end
    end
  end

  -- Build the conform spec with custom formatter registration
  local spec = {
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
  }

  -- If we have custom formatters (strategies), register them in config()
  -- This runs AFTER conform is loaded, so require("conform") works.
  if next(custom_formatters) ~= nil then
    spec.config = function(_, opts)
      local conform = require("conform")

      -- Register each strategy as a custom conform formatter.
      -- The formatter's format() function:
      --   1. Calls strategy_fn(bufnr) to get the actual formatter list
      --      (e.g., {"ruff_format"} or {"isort", "black"})
      --   2. Runs the first available formatter from that list
      --   3. Returns the formatted lines
      --
      -- This preserves builtin.lua's runtime availability checking.
      for strategy_name, strategy_fn in pairs(custom_formatters) do
        conform.formatters[strategy_name] = {
          -- conform calls format(self, ctx) where ctx has bufnr
          -- We need to return the formatted text
          format = function(self, ctx)
            local candidates = strategy_fn(ctx.bufnr) or {}
            -- Try each candidate formatter until one works
            for _, fmt_name in ipairs(candidates) do
              local formatter = conform.formatters[fmt_name]
              if formatter and formatter.format then
                -- Get the current buffer lines
                local lines = vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
                local result = formatter.format(formatter, ctx, lines)
                if result and type(result) == "table" then
                  return result
                end
              end
            end
            -- No formatter worked — return original lines unchanged
            return vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
          end,
        }
      end

      conform.setup(opts)
    end
  end

  return { spec }
end

return M
