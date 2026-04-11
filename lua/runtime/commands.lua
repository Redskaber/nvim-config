-- ~/.config/nvim/lua/runtime/commands.lua
-- App layer: user commands (TODO-12.1, TODO-12.2).
--
-- Commands:
--   :LtosInfo             — profile, state, modules, tools, strategies, timings
--   :LtosDebug [stage]    — foldable IR snapshot at a given stage
--   :LtosIR               — full LIR dump (post-optimize) in scratch buffer
--   :LtosTrace            — per-phase execution timeline
--   :LtosGraph            — dependency graph (module → caps used)

local M = {}

local ir_mod = require("core.ir")

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

local VALID_DEBUG_STAGES = { collect = true, normalize = true, resolve = true, optimize = true }

local function cmd_debug(opts)
  local stage = (opts.args ~= "") and opts.args or nil

  if stage and not VALID_DEBUG_STAGES[stage] then
    vim.notify(
      ("[LtosDebug] unknown stage %q; valid: collect, normalize, resolve, optimize"):format(stage),
      vim.log.levels.ERROR
    )
    return
  end

  local runtime = require("runtime")
  local pipeline = require("runtime.pipeline")
  local ir = pipeline.debug_run(runtime.LANG_MODULES, stage)

  -- Diagnostic section
  local diag_lines = {}
  local counts = ir_mod.diag_counts(ir)
  if counts.errors + counts.warns > 0 then
    diag_lines[#diag_lines + 1] = ("-- diagnostics  errors=%d  warns=%d"):format(counts.errors, counts.warns)
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
    #(runtime.LANG_MODULES or {}),
    format_timings(ir._timings)
  )

  local dump_ir = vim.deepcopy(ir)
  dump_ir._timings = nil

  open_scratch(vim.list_extend(diag_lines, vim.split(vim.inspect(dump_ir), "\n")), label, header)
end

-- ── :LtosIR ──────────────────────────────────────────────────────────────────

local function cmd_ir()
  local runtime = require("runtime")
  local pipeline = require("runtime.pipeline")
  -- Run to optimize (LIR) — full IR before codegen
  local ir = pipeline.debug_run(runtime.LANG_MODULES, "optimize")

  local header = ("LTOS LIR (post-optimize)  modules=%d  %s"):format(
    #(runtime.LANG_MODULES or {}),
    format_timings(ir._timings)
  )

  local dump = vim.deepcopy(ir)
  dump._timings = nil

  open_scratch(vim.split(vim.inspect(dump), "\n"), "LtosIR", header)
end

-- ── :LtosTrace ───────────────────────────────────────────────────────────────

local function cmd_trace()
  local timings = vim.g.ltos_last_build_timings
  if not timings then
    vim.notify("[LtosTrace] no build timings available — run :LtosDebug first", vim.log.levels.WARN)
    return
  end

  local PHASE_ORDER = { "collect", "normalize", "resolve", "optimize", "codegen" }
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

local function cmd_graph()
  local runtime = require("runtime")
  local pipeline = require("runtime.pipeline")
  local ir = pipeline.debug_run(runtime.LANG_MODULES, "collect")

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

    -- LSP servers
    local lsp_names = vim.tbl_keys(cap.lsp or {})
    table.sort(lsp_names)
    if #lsp_names > 0 then
      lines[#lines + 1] = "  lsp         → " .. table.concat(lsp_names, ", ")
    end

    -- Treesitter parsers
    if cap.treesitter and #cap.treesitter > 0 then
      lines[#lines + 1] = "  treesitter  → " .. table.concat(cap.treesitter, ", ")
    end

    -- Formatters
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

    -- Linters
    local ft_lints = {}
    for ft, lints in pairs(cap.linters or {}) do
      ft_lints[#ft_lints + 1] = ft .. ": " .. table.concat(lints, "|")
    end
    if #ft_lints > 0 then
      table.sort(ft_lints)
      lines[#lines + 1] = "  linters     → " .. table.concat(ft_lints, "  ")
    end

    -- Mason explicit
    if cap.mason and #cap.mason > 0 then
      lines[#lines + 1] = "  mason       → " .. table.concat(cap.mason, ", ")
    end

    lines[#lines + 1] = ""
  end

  open_scratch(lines, "LtosGraph", nil)
end

-- ── :LtosInfo ────────────────────────────────────────────────────────────────

local function cmd_info()
  local caps = require("core.capability").snapshot()
  local pipeline = require("runtime.pipeline")

  local profile = vim.g.ltos_profile or "full"
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

  local strategies = require("toolchain.strategies")
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
  local timings = vim.g.ltos_last_build_timings
  if timings then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Last build timings:"
    for _, s in ipairs({ "collect", "normalize", "resolve", "optimize", "codegen" }) do
      if timings[s] then
        lines[#lines + 1] = ("  %-10s  %.3f ms"):format(s, timings[s] * 1000)
      end
    end
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- ── Setup ─────────────────────────────────────────────────────────────────────

function M.setup()
  vim.api.nvim_create_user_command("LtosDebug", cmd_debug, {
    nargs = "?",
    desc = "Dump LTOS pipeline IR at a given stage (collect|normalize|resolve|optimize)",
    complete = function()
      return { "collect", "normalize", "resolve", "optimize" }
    end,
  })

  vim.api.nvim_create_user_command("LtosInfo", cmd_info, {
    nargs = 0,
    desc = "Show LTOS profile, state, modules, tools, strategies and build timings",
  })

  vim.api.nvim_create_user_command("LtosIR", cmd_ir, {
    nargs = 0,
    desc = "Dump full LTOS LIR (post-optimize IR) in a scratch buffer",
  })

  vim.api.nvim_create_user_command("LtosTrace", cmd_trace, {
    nargs = 0,
    desc = "Show per-phase execution timeline for the last pipeline run",
  })

  vim.api.nvim_create_user_command("LtosGraph", cmd_graph, {
    nargs = 0,
    desc = "Show module capability dependency graph",
  })
end

return M
