-- ~/.config/nvim/lua/runtime/commands.lua
-- User commands: :LtosDebug [stage], :LtosInfo (P2-3).
--
-- :LtosDebug dumps a foldable IR snapshot in a scratch buffer.
--   Uses ir_mod.format_errors() for structured error display (P2-2).
--   Supports stages: collect | normalize | resolve | optimize
--
-- :LtosInfo shows profile, pipeline state, registered modules,
--   tool count, and per-stage build timings.

local M = {}

local ir_mod = require("core.ir")

-- ── Scratch buffer helper ─────────────────────────────────────────────────────

local function open_scratch(lines, label, header)
  vim.cmd("new")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "lua"
  vim.api.nvim_buf_set_name(buf, label)

  local all = {}
  if header then
    all[#all + 1] = "-- " .. header
    all[#all + 1] = ""
  end
  vim.list_extend(all, lines)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, all)
  vim.bo[buf].modifiable = false

  -- Enable folds
  vim.wo.foldmethod = "indent"
  vim.wo.foldlevel = 1

  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true, desc = "Close" })
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

  -- Structured error section
  local err_lines = {}
  if ir.errors and #ir.errors > 0 then
    err_lines[#err_lines + 1] = "-- errors (" .. #ir.errors .. ")"
    for _, e in ipairs(ir.errors) do
      err_lines[#err_lines + 1] = string.format("--   [%s] %s: %s", e.stage or "?", e.node or "?", e.message or "?")
    end
    err_lines[#err_lines + 1] = ""
  end

  -- Timings
  local timings_str = "n/a"
  if ir._timings then
    local parts = {}
    for s, t in pairs(ir._timings) do
      parts[#parts + 1] = string.format("%s=%.3fms", s, t * 1000)
    end
    table.sort(parts)
    timings_str = table.concat(parts, "  ")
  end

  local label = "LtosDebug:" .. (stage or "optimize")
  local header = string.format(
    "LTOS IR snapshot  stage=%s  modules=%d  %s",
    stage or "optimize",
    #(runtime.LANG_MODULES or {}),
    timings_str
  )

  -- Remove _timings from dump (internal field)
  local dump_ir = vim.deepcopy(ir)
  dump_ir._timings = nil

  local ir_lines = vim.split(vim.inspect(dump_ir), "\n")

  open_scratch(vim.list_extend(err_lines, ir_lines), label, header)
end

-- ── :LtosInfo ────────────────────────────────────────────────────────────────

local function cmd_info()
  local caps = require("core.capability").snapshot()
  local pipeline = require("runtime.pipeline")

  local profile = vim.g.ltos_profile or "full"
  local state = pipeline.state()

  -- Collect unique tool names from all caps
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

  local lines = {
    "LTOS Info",
    "=========",
    "",
    "Profile  : " .. profile,
    "State    : " .. state,
    "Modules  : " .. #module_names,
    "Tools    : " .. vim.tbl_count(tools_seen),
    "Strategies: " .. table.concat(require("toolchain.strategies").list(), ", "),
    "",
    "Registered lang modules:",
  }
  for _, name in ipairs(module_names) do
    lines[#lines + 1] = "  • " .. name
  end

  -- Per-stage build timings from last pipeline run
  local timings = vim.g.ltos_last_build_timings
  if timings then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Last build timings:"
    for _, s in ipairs({ "collect", "normalize", "resolve", "optimize", "codegen" }) do
      if timings[s] then
        lines[#lines + 1] = string.format("  %-10s %.3f ms", s, timings[s] * 1000)
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
end

return M
