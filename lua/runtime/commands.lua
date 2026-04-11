-- ~/.config/nvim/lua/runtime/commands.lua
-- User commands for LTOS diagnostics and inspection.
--   :LtosDebug [stage]  — dump IR snapshot at the given pipeline stage
--   :LtosInfo           — show registered modules, tool count, profile, state

local M = {}

--- Open a scratch buffer and display the given lines in a vertical split.
---@param lines string[]
---@param title string
local function open_scratch(lines, title)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "lua"
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.cmd("vsplit")
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_buf_set_name(buf, title)
end

--- :LtosDebug [stage]
--- Calls pipeline.debug_run() and shows the IR snapshot in a scratch buffer.
local function cmd_debug(opts)
  local stage = (opts.args ~= "") and opts.args or nil
  local runtime = require("runtime")
  local pipeline = require("runtime.pipeline")
  local ir = pipeline.debug_run(runtime.LANG_MODULES, stage)
  local label = stage and ("LtosDebug:" .. stage) or "LtosDebug:optimize"
  open_scratch(vim.split(vim.inspect(ir), "\n"), label)
end

--- :LtosInfo
--- Shows registered lang modules, tool count, current profile, pipeline state.
local function cmd_info()
  local caps = require("core.capability").all()
  local pipeline = require("runtime.pipeline")

  local profile = vim.g.ltos_profile or "full"
  local state = pipeline.state()

  -- Count unique tools across all capabilities
  local tools_seen = {}
  for _, cap in pairs(caps) do
    local function count_tools(tbl)
      if not tbl then
        return
      end
      for _, list in pairs(tbl) do
        if type(list) == "table" then
          for _, item in ipairs(list) do
            if type(item) == "string" then
              tools_seen[item] = true
            end
          end
        end
      end
    end
    count_tools(cap.formatters)
    count_tools(cap.linters)
    if cap.mason then
      for _, t in ipairs(cap.mason) do
        tools_seen[t] = true
      end
    end
    if cap.lsp then
      for server in pairs(cap.lsp) do
        tools_seen[server] = true
      end
    end
  end

  local module_names = vim.tbl_keys(caps)
  table.sort(module_names)

  local lines = {
    "LTOS Info",
    "=========",
    "",
    "Profile : " .. profile,
    "State   : " .. state,
    "Modules : " .. #module_names,
    "Tools   : " .. vim.tbl_count(tools_seen),
    "",
    "Registered lang modules:",
  }
  for _, name in ipairs(module_names) do
    lines[#lines + 1] = "  • " .. name
  end

  -- Show per-stage build timings if available (Requirement 18.3)
  local timings = vim.g.ltos_last_build_timings
  if timings then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Last build timings:"
    local stage_order = { "collect", "normalize", "resolve", "optimize", "codegen" }
    for _, stage in ipairs(stage_order) do
      if timings[stage] then
        lines[#lines + 1] = string.format("  %-10s %.3f ms", stage, timings[stage] * 1000)
      end
    end
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

--- Register :LtosDebug and :LtosInfo user commands.
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
    desc = "Show LTOS registered modules, tool count, profile and pipeline state",
  })
end

return M
