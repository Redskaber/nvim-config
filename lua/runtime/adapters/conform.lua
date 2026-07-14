-- lua/runtime/adapters/conform.lua
-- REFACTOR (TODO-5.4): pure IR reader — no side-effects, no vim API calls.
-- Missing IR fields: return { error = "..." } for emitter to surface.
--
-- FIX-TEST-BUG (2026-06-26): opts is now a STATIC table, not a lazy function.
-- Tests index `spec.opts.formatters_by_ft`, `spec.opts.default_format_opts`,
-- `spec.opts.format_on_save` directly.
--
-- FIX-LAZYVIM-CONFORM (2026-06-26): do NOT set `spec.config` for conform.nvim.
-- LazyVim provides its own `config` function for conform.nvim that:
--   1. Calls require("conform").setup(opts)
--   2. Wires up format_on_save autocmd via LazyVim.format
--   3. Provides <leader>cf keymap and LSP format integration
-- Setting spec.config would OVERRIDE LazyVim's config, breaking all of the
-- above. Instead, custom-strategy formatters are registered via
-- `opts.formatters` (a static table) — LazyVim's config passes the full
-- opts table to conform.setup(), which registers them automatically.
-- See: https://www.lazyvim.org/plugins/formatting

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
-- Correct approach: register strategy as a conform custom formatter via
-- `opts.formatters[strategy_name] = { format = function(...) end }`.
-- conform.nvim's setup() accepts this table and registers the formatter.
-- LazyVim's config calls setup(opts), so we only need to populate opts —
-- we must NOT set spec.config (that would override LazyVim's config).
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

  -- FIX-TEST-BUG (2026-06-26): static opts table for testability.
  -- Tests index `spec.opts.formatters_by_ft` and `spec.opts.default_format_opts`
  -- directly.
  --
  -- FIX-LAZYVIM-CONFORM (2026-06-26): `formatters` field holds custom
  -- formatter definitions. LazyVim's config calls conform.setup(opts),
  -- which registers these. We do NOT set spec.config — that would
  -- override LazyVim's config and break format_on_save / keymaps.
  --
  -- FIX-LAZYVIM-FORMAT-ON-SAVE (2026-06-26): do NOT set opts.format_on_save.
  -- LazyVim manages format-on-save via LazyVim.format (an autocmd that
  -- calls conform.format() on BufWritePre). Setting opts.format_on_save
  -- here would create a SECOND format-on-save hook that conflicts with
  -- LazyVim's, causing double-format attempts or LSP/conform races.
  -- See: https://www.lazyvim.org/plugins/formatting
  local opts = {
    formatters_by_ft = formatters_by_ft,
    formatters = {},
    default_format_opts = {
      lsp_format = "fallback",
      timeout_ms = 1000,
    },
    -- format_on_save intentionally omitted — LazyVim owns this via LazyVim.format
  }

  -- Register custom-strategy formatters via opts.formatters (static table).
  -- Each entry is a conform formatter definition with a `format` closure.
  -- The closure captures `strategy_fn` at build time but only executes at
  -- format-time (when conform is loaded and a real buffer exists).
  --
  -- FIX-POLISH-3 (2026-06-26): defensive vim.api guard handles headless
  -- test scenarios where conform is not yet loaded. The format function
  -- is inside opts (NOT in a config function), respecting INV-13.
  -- FIX-P1 (2026-07-15): pcall-protect require("conform") and the inner
  -- formatter.format() call so format-on-save degrades gracefully.
  for strategy_name, strategy_fn in pairs(custom_formatters) do
    opts.formatters[strategy_name] = {
      format = function(self, ctx, lines)
        -- Defensive: vim.api may be unavailable in headless unit tests
        -- that exercise M.build() without loading conform.nvim.
        if not vim or not vim.api then
          return lines or {}
        end
        -- Defensive: conform may not be loaded yet (user disabled it, or
        -- format triggered before plugin load). Return lines unchanged.
        local ok_conform, conform = pcall(require, "conform")
        if not ok_conform or not conform then
          return lines or {}
        end
        -- conform.nvim passes `lines` (3rd arg) in newer versions;
        -- fall back to fetching from buffer for older API compatibility.
        lines = lines or vim.api.nvim_buf_get_lines(ctx.bufnr, 0, -1, false)
        local candidates = strategy_fn(ctx.bufnr) or {}
        for _, fmt_name in ipairs(candidates) do
          local formatter = conform.formatters[fmt_name]
          if formatter and formatter.format then
            local ok_fmt, result = pcall(formatter.format, formatter, ctx, lines)
            if ok_fmt and result and type(result) == "table" then
              return result
            end
          end
        end
        -- No candidate worked — return original lines unchanged
        return lines
      end,
    }
  end

  -- No spec.config — LazyVim's conform config handles setup(opts).
  -- See: https://www.lazyvim.org/plugins/formatting
  return {
    {
      "stevearc/conform.nvim",
      _source = "ltos:conform",
      opts = opts,
    },
  }
end

return M