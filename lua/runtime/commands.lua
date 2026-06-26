-- ~/.config/nvim/lua/runtime/commands.lua
-- App layer: user commands (TODO-12.1, TODO-12.2).
--
-- Commands:
--   :LtosInfo             — profile, state, modules, tools, strategies, timings
--   :LtosDebug [stage]    — foldable IR snapshot at a given stage
--   :LtosIR               — full LIR dump (post-optimize) in scratch buffer
--   :LtosTrace            — per-phase execution timeline
--   :LtosGraph            — dependency graph (module → caps used)
--
-- FIX-POLISH-1 (2026-06-26): Debug stage lists are now derived from
-- pipeline.PHASE_ORDER instead of hardcoded. This eliminates the DRY
-- violation where VALID_DEBUG_STAGES and 4 complete= functions each
-- maintained their own copy of {collect, normalize, canonicalize,
-- resolve, optimize}. Now a single helper `debug_stages()` computes
-- the list from the live phase registry, filtering out:
--   • codegen (terminal — debug_run stops BEFORE it)
--   • side phases (input_state == output_state — collect_ext, cap_resolve
--     are not useful debug stop points since they don't advance the IR
--     sub-layer meaningfully for inspection)
-- This means adding/renaming a phase automatically updates tab-completion
-- and validation without touching commands.lua.

local M = {}

local ir_mod = require("core.compiler.ir")
local phase_registry = require("runtime.phase_registry")
local pipeline = require("runtime.pipeline")

-- ── Debug stage derivation (FIX-POLISH-1) ───────────────────────────────────

--- Compute the list of valid debug stages from the live phase registry.
--- Excludes codegen (terminal) and side phases (input_state == output_state).
--- Side phases (collect_ext, cap_resolve) don't produce a distinct IR
--- sub-layer worth inspecting in isolation — users debug the surrounding
--- main phases instead.
---@return string[]
local function debug_stages()
  local stages = {}
  for _, phase in ipairs(phase_registry.list()) do
    -- Skip side phases: input_state == output_state means the phase
    -- doesn't advance the SM/IR sub-layer (collect_ext, cap_resolve).
    if phase.input_state ~= phase.output_state then
      stages[#stages + 1] = phase.name
    end
  end
  return stages
end

--- Set-style lookup for O(1) validation.
---@return table<string, boolean>
local function debug_stages_set()
  local set = {}
  for _, stage in ipairs(debug_stages()) do
    set[stage] = true
  end
  return set
end

-- Cache the set at module load time. Phase registry is populated during
-- pipeline.lua require-time init (register_default_phases), which runs
-- before commands.lua is ever required. If phases change at runtime,
-- M.refresh_debug_stages() can be called to rebuild the cache.
local _debug_stages_set = debug_stages_set()
local _debug_stages_list = debug_stages()

--- Refresh the cached debug stage list/set. Call after dynamically
--- registering/deregistering phases if you want :LtosDebug completion
--- to reflect the new phase set within the same session.
function M.refresh_debug_stages()
  _debug_stages_set = debug_stages_set()
  _debug_stages_list = debug_stages()
end

-- ── Scratch buffer helper ─────────────────────────────────────────────────────
-- Idempotent: reuses an existing buffer with the same label rather than
-- creating a new one each invocation (avoids E95 on repeated calls).

---@param lines  string[]
---@param label  string
---@param header? string
local function open_scratch(lines, label, header)
  -- Reuse existing buffer by name, or create a fresh one
  local buf = vim.fn.bufnr(label)
  local is_new = buf == -1

  if is_new then
    buf = vim.api.nvim_create_buf(false, true) -- listed=false, scratch=true
    vim.api.nvim_buf_set_name(buf, label)
  end

  -- Configure buffer options (idempotent)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "lua"

  -- Build content
  local all = {}
  if header then
    all[#all + 1] = "-- " .. header
    all[#all + 1] = ""
  end
  vim.list_extend(all, lines)

  -- Write content (must be modifiable momentarily)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, all)
  vim.bo[buf].modifiable = false

  -- Focus: reuse existing window if already visible, else open a split
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    vim.api.nvim_set_current_win(win)
  else
    vim.cmd("split")
    vim.api.nvim_win_set_buf(0, buf)
  end
  vim.wo.foldmethod = "indent"
  vim.wo.foldlevel = 1

  if is_new then
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true, desc = "Close" })
  end
end

-- ── Timing formatter ──────────────────────────────────────────────────────────

local function format_timings(timings)
  if not timings then
    return "n/a"
  end
  local parts = {}
  for stage, t in pairs(timings) do
    parts[#parts + 1] = ("%s=%.2fms"):format(stage, t * 1000)
  end
  table.sort(parts)
  return table.concat(parts, "  ")
end

-- ── :LtosDebug ───────────────────────────────────────────────────────────────

-- FIX-POLISH-1: VALID_DEBUG_STAGES is now a live view over the cached
-- debug stages set. Using a metatable proxy ensures that
-- M.refresh_debug_stages() (called after dynamic phase registration)
-- is immediately visible to all validation checks without re-reading
-- any module-level local.
local VALID_DEBUG_STAGES = setmetatable({}, {
  __index = function(_, key) return _debug_stages_set[key] end,
  __pairs = function(_) return pairs(_debug_stages_set) end,
})

local function cmd_debug(opts)
  local stage = (opts.args ~= "") and opts.args or nil

  if stage and not VALID_DEBUG_STAGES[stage] then
    vim.notify(
      ("[LtosDebug] unknown stage %q; valid: %s"):format(
        stage,
        table.concat(_debug_stages_list, ", ")
      ),
      vim.log.levels.ERROR
    )
    return
  end

  local runtime = require("runtime")
  local modules = runtime.lang_modules()
  local ir = pipeline.debug_run(modules, stage)

  -- Diagnostic section
  local diag_lines = {}
  local counts = ir_mod.diag_counts(ir)
  if counts.errors + counts.warns > 0 then
    diag_lines[#diag_lines + 1] = ("-- diagnostics  errors=%d  warns=%d"):format(
      counts.errors,
      counts.warns
    )
    for _, d in ipairs(ir.diagnostics or {}) do
      diag_lines[#diag_lines + 1] = ("--   [%s][%s] %s: %s"):format(
        d.severity or "?",
        d.stage or "?",
        d.node or "?",
        d.message or "?"
      )
    end
    diag_lines[#diag_lines + 1] = ""
  end

  local label = "LtosDebug:" .. (stage or "optimize")
  local header = ("LTOS IR snapshot  stage=%s  sub-layer=%s  modules=%d  %s"):format(
    stage or "optimize",
    ir.stage or "?",
    #modules,
    format_timings(ir._timings)
  )

  local dump_ir = vim.deepcopy(ir)
  dump_ir._timings = nil

  open_scratch(vim.list_extend(diag_lines, vim.split(vim.inspect(dump_ir), "\n")), label, header)
end

-- ── :LtosIR ──────────────────────────────────────────────────────────────────

local function cmd_ir(opts)
  local stage = (opts.args ~= "") and opts.args or "optimize"

  if not VALID_DEBUG_STAGES[stage] and stage ~= "optimize" then
    vim.notify(
      ("[LtosIR] unknown stage %q; valid: %s"):format(stage, table.concat(_debug_stages_list, ", ")),
      vim.log.levels.ERROR
    )
    return
  end
  local runtime = require("runtime")
  local modules = runtime.lang_modules()
  local ir = pipeline.debug_run(modules, stage)

  local header = ("LTOS IR  stage=%s  sub-layer=%s  modules=%d  %s"):format(
    stage,
    ir.stage or "?",
    #modules,
    format_timings(ir._timings)
  )

  local dump = vim.deepcopy(ir)
  dump._timings = nil

  open_scratch(vim.split(vim.inspect(dump), "\n"), "LtosIR:" .. stage, header)
end

-- ── :LtosTrace ───────────────────────────────────────────────────────────────

local function cmd_trace()
  local timings = require("runtime.pipeline").timings() -- OPT-H: use API instead of vim.g
  if not timings then
    vim.notify(
      "[LtosTrace] no build timings available — run :LtosDebug first",
      vim.log.levels.WARN
    )
    return
  end

  local PHASE_ORDER = pipeline.PHASE_ORDER
  local lines = {
    "LTOS Phase Execution Trace",
    "==========================",
    "",
    ("%-12s  %10s  %s"):format("Phase", "Time (ms)", "Bar"),
    string.rep("─", 50),
  }

  local max_ms = 0
  for _, p in ipairs(PHASE_ORDER) do
    if timings[p] then
      max_ms = math.max(max_ms, timings[p] * 1000)
    end
  end

  for _, phase in ipairs(PHASE_ORDER) do
    local ms = timings[phase]
    if ms then
      local bar_len = math.floor((ms * 1000 / math.max(max_ms, 0.001)) * 30)
      local bar = string.rep("█", bar_len)
      lines[#lines + 1] = ("%-12s  %10.3f  %s"):format(phase, ms * 1000, bar)
    end
  end

  local total = 0
  for _, t in pairs(timings) do
    total = total + t
  end
  lines[#lines + 1] = string.rep("─", 50)
  lines[#lines + 1] = ("%-12s  %10.3f"):format("TOTAL", total * 1000)

  open_scratch(lines, "LtosTrace", nil)
end

-- ── :LtosGraph ───────────────────────────────────────────────────────────────

local function cmd_graph(opts)
  local mode = (opts.args ~= "") and opts.args or "caps"
  local runtime = require("runtime")
  local modules = runtime.lang_modules()
  if mode == "dag" then
    local lines = {
      "LTOS Pipeline DAG",
      "=================",
      "",
      "  [modules/lang/*]  ──►  collect  ──►  normalize  ──►  canonicalize  ──►  resolve  ──►  optimize  ──►  codegen  ──►  LazySpec[]",
      "",
      "State machine transitions:",
      "  idle → collecting → normalizing → canonicalizing → resolving → optimizing → codegen → done",
      "                                                                                        ↘ error",
      "",
      "IR sub-layers:",
      "  AST  (collect output)       — raw validated capability snapshot",
      "  HIR  (normalize output)     — FormatterNode.fn resolved",
      "  HIR+ (canonicalize output)  — ir.symbols: canonical lsp/tool→mason pkg table",
      "  MIR  (resolve output)       — mason/system decisions baked from ir.symbols",
      "  LIR  (optimize output)      — deduped parsers, merged LSP",
      "  SPEC (codegen input)        — all fields present, drives adapters",
      "",
      "Adapters (codegen → LazySpec[]):",
      "  LIR.merged_lsp   → lsp.lua    → nvim-lspconfig + mason-lspconfig",
      "  LIR.symbols      → mason.lua  → mason.nvim  (canonical pkg names)",
      "  LIR.all_parsers  → treesitter.lua → nvim-treesitter",
      "  LIR.caps.fmt     → conform.lua → conform.nvim",
      "  LIR.caps.lint    → lint.lua   → nvim-lint",
    }
    open_scratch(lines, "LtosGraph:dag", nil)
    return
  end

  -- Default: module capability graph
  local ir = pipeline.debug_run(modules, "collect")

  local lines = {
    "LTOS Module Capability Graph",
    "============================",
    "",
  }

  local module_names = vim.tbl_keys(ir.caps or {})
  table.sort(module_names)

  for _, name in ipairs(module_names) do
    local cap = ir.caps[name]
    lines[#lines + 1] = ("[ %s ]"):format(name)

    local lsp_names = vim.tbl_keys(cap.lsp or {})
    table.sort(lsp_names)
    if #lsp_names > 0 then
      lines[#lines + 1] = "  lsp         → " .. table.concat(lsp_names, ", ")
    end

    if cap.treesitter and #cap.treesitter > 0 then
      lines[#lines + 1] = "  treesitter  → " .. table.concat(cap.treesitter, ", ")
    end

    local ft_fmts = {}
    for ft, fmts in pairs(cap.formatters or {}) do
      local names = {}
      for _, v in ipairs(fmts) do
        if type(v) == "string" then
          names[#names + 1] = v
        elseif type(v) == "table" then
          names[#names + 1] = v.strategy or v.name or "?"
        end
      end
      ft_fmts[#ft_fmts + 1] = ft .. ": " .. table.concat(names, "|")
    end
    if #ft_fmts > 0 then
      table.sort(ft_fmts)
      lines[#lines + 1] = "  formatters  → " .. table.concat(ft_fmts, "  ")
    end

    local ft_lints = {}
    for ft, lints in pairs(cap.linters or {}) do
      ft_lints[#ft_lints + 1] = ft .. ": " .. table.concat(lints, "|")
    end
    if #ft_lints > 0 then
      table.sort(ft_lints)
      lines[#lines + 1] = "  linters     → " .. table.concat(ft_lints, "  ")
    end

    if cap.mason and #cap.mason > 0 then
      lines[#lines + 1] = "  mason       → " .. table.concat(cap.mason, ", ")
    end

    lines[#lines + 1] = ""
  end

  open_scratch(lines, "LtosGraph:caps", nil)
end

-- ── :LtosDiff ────────────────────────────────────────────────────────────────

local function cmd_diff(opts)
  local args = vim.split(opts.args or "", "%s+")
  local stage_a = args[1] ~= "" and args[1] or "collect"
  local stage_b = args[2] ~= "" and args[2] or "optimize"

  if not VALID_DEBUG_STAGES[stage_a] then
    vim.notify(("[LtosDiff] unknown stage_a %q"):format(stage_a), vim.log.levels.ERROR)
    return
  end
  if not VALID_DEBUG_STAGES[stage_b] then
    vim.notify(("[LtosDiff] unknown stage_b %q"):format(stage_b), vim.log.levels.ERROR)
    return
  end

  local runtime = require("runtime")
  local modules = runtime.lang_modules()
  local ir_a = pipeline.debug_run(modules, stage_a)
  local ir_b = pipeline.debug_run(modules, stage_b)

  local changes = ir_mod.diff(ir_a, ir_b)
  -- Filter out timing noise
  local filtered = {}
  for _, c in ipairs(changes) do
    if not c.path:find("started_at") and not c.path:find("_timings") then
      filtered[#filtered + 1] = c
    end
  end

  local lines = {
    ("LTOS IR Diff  %s → %s  (%d changes)"):format(stage_a, stage_b, #filtered),
    string.rep("─", 60),
    "",
  }
  if #filtered == 0 then
    lines[#lines + 1] = "(no structural changes)"
  else
    for _, c in ipairs(filtered) do
      lines[#lines + 1] = ("  %s"):format(c.path)
      lines[#lines + 1] = ("    - %s"):format(tostring(c.old):sub(1, 80))
      lines[#lines + 1] = ("    + %s"):format(tostring(c.new):sub(1, 80))
      lines[#lines + 1] = ""
    end
  end

  open_scratch(lines, ("LtosDiff:%s:%s"):format(stage_a, stage_b), nil)
end

local function cmd_info()
  local runtime = require("runtime")
  local modules = runtime.lang_modules()
  local ir = pipeline.debug_run(modules, "collect")
  local caps = ir.caps or {}

  local profile = vim.g.ltos_profile or "full" -- UI display, not compilation knob
  local state = pipeline.state()

  -- Collect unique tool names
  local tools_seen = {}
  for _, cap in pairs(caps) do
    for _, list in pairs(cap.formatters or {}) do
      if type(list) == "table" then
        for _, item in ipairs(list) do
          if type(item) == "string" then
            tools_seen[item] = true
          end
        end
      end
    end
    for _, list in pairs(cap.linters or {}) do
      for _, item in ipairs(list) do
        if type(item) == "string" then
          tools_seen[item] = true
        end
      end
    end
    for _, t in ipairs(cap.mason or {}) do
      tools_seen[t] = true
    end
    for server in pairs(cap.lsp or {}) do
      tools_seen[server] = true
    end
  end

  local module_names = vim.tbl_keys(caps)
  table.sort(module_names)

  local strategies = require("toolchain.strategy.registry")
  strategies.bootstrap()

  local lines = {
    "LTOS Info",
    "=========",
    "",
    "Profile    : " .. profile,
    "State      : " .. state,
    "Modules    : " .. #module_names,
    "Tools      : " .. vim.tbl_count(tools_seen),
    "Strategies : " .. table.concat(strategies.list(), ", "),
    "",
    "Registered lang modules:",
  }
  for _, name in ipairs(module_names) do
    lines[#lines + 1] = "  • " .. name
  end

  -- Per-stage timings
  local timings = require("runtime.pipeline").timings() -- OPT-H: use API instead of vim.g
  if timings then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Last build timings:"
    for _, s in ipairs(pipeline.PHASE_ORDER) do
      if timings[s] then
        lines[#lines + 1] = ("  %-10s  %.3f ms"):format(s, timings[s] * 1000)
      end
    end
  end

  -- Cache hit/miss stats
  local cache_stats = require("core.compiler.cache").stats()
  if next(cache_stats) then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Cache stats:"
    for tier, s in pairs(cache_stats) do
      local total = (s.hits or 0) + (s.misses or 0)
      local ratio = total > 0 and math.floor(100 * (s.hits or 0) / total) or 0
      lines[#lines + 1] = ("  %-6s  hits=%d  misses=%d  ratio=%d%%"):format(
        tier,
        s.hits or 0,
        s.misses or 0,
        ratio
      )
    end
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- ── Setup ─────────────────────────────────────────────────────────────────────

-- Return a fresh copy of the cached debug stages list for nvim command
-- completion. nvim's complete= function must return a new table each
-- call (it may mutate the result internally).
local function complete_debug_stages()
  local out = {}
  for i, stage in ipairs(_debug_stages_list) do
    out[i] = stage
  end
  return out
end

function M.setup()
  vim.api.nvim_create_user_command("LtosDebug", cmd_debug, {
    nargs = "?",
    desc = "Dump LTOS pipeline IR at a given stage (collect|normalize|canonicalize|resolve|optimize)",
    complete = complete_debug_stages,
  })

  vim.api.nvim_create_user_command("LtosInfo", cmd_info, {
    nargs = 0,
    desc = "Show LTOS profile, state, modules, tools, strategies and build timings",
  })

  vim.api.nvim_create_user_command("LtosIR", cmd_ir, {
    nargs = "?",
    desc = "Dump LTOS IR at a given stage (collect|normalize|canonicalize|resolve|optimize, default: optimize)",
    complete = complete_debug_stages,
  })

  vim.api.nvim_create_user_command("LtosTrace", cmd_trace, {
    nargs = 0,
    desc = "Show per-phase execution timeline for the last pipeline run",
  })

  vim.api.nvim_create_user_command("LtosGraph", cmd_graph, {
    nargs = "?",
    desc = "Show module capability graph (caps) or pipeline DAG (dag)",
    complete = function() return { "caps", "dag" } end,
  })
  vim.api.nvim_create_user_command("LtosDiff", cmd_diff, {
    nargs = "*",
    desc = "Diff IR between two pipeline stages: LtosDiff [stage_a] [stage_b] (default: collect optimize)",
    complete = complete_debug_stages,
  })
end

return M

