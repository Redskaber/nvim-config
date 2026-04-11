-- ~/.config/nvim/lua/runtime/commands.lua
-- User commands for LTOS diagnostics and inspection.
--   :LtosDebug [stage]  — dump IR snapshot at the given pipeline stage
--   :LtosInfo           — show registered modules, tool count, profile, state
--
-- LtosDebug scratch buffer now sets foldmethod=indent and prepends
-- a header line so large IR dumps are easier to navigate.
-- TODO:
-- IR tree viewer
-- stage diff（collect vs optimize）
-- tool graph
-- profiling flame view

local M = {}

--- Open a scratch buffer with foldable Lua inspect output in a vertical split.
---@param lines  string[]
---@param title  string
---@param header string   one-line summary shown at the top
local function open_scratch(lines, title, header)
  local buf = vim.api.nvim_create_buf(false, true)

  -- Prepend header + blank separator
  -- nvim_buf_set_lines rejects any string containing a newline character,
  -- so flatten the header and re-split every line to be safe.
  local raw = { "-- " .. header, "" }
  vim.list_extend(raw, lines)
  local content = {}
  for _, line in ipairs(raw) do
    -- split on \n or \r\n and add each sub-line individually
    for _, subline in ipairs(vim.split(line, "\r?\n", { plain = false })) do
      content[#content + 1] = subline
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].filetype = "lua"
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  vim.cmd("vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_buf_set_name(buf, title)

  -- fold by indent so nested tables collapse cleanly
  vim.wo[win].foldmethod = "indent"
  vim.wo[win].foldlevel = 1 -- top-level keys open; nested folded
  vim.wo[win].number = true
  vim.wo[win].wrap = false

  -- Close with <q>
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
end

--- :LtosDebug [stage]
local function cmd_debug(opts)
  local stage = (opts.args ~= "") and opts.args or nil
  local runtime = require("runtime")
  local pipeline = require("runtime.pipeline")
  local ir = pipeline.debug_run(runtime.LANG_MODULES, stage)

  local label = stage and ("LtosDebug:" .. stage) or "LtosDebug:optimize"
  -- FIXME: string-based serialization pipeline（不稳定 + 高成本）
  -- runtime.inspect.to_lines(ir)
  local timings_str = ir._timings and vim.inspect(ir._timings):gsub("%s*\n%s*", " ") or "n/a"
  local header = string.format(
    "LTOS IR snapshot  stage=%s  modules=%d  timings=%s",
    stage or "optimize",
    #(runtime.LANG_MODULES or {}),
    timings_str
  )

  open_scratch(vim.split(vim.inspect(ir), "\n"), label, header)
end

--- :LtosInfo
local function cmd_info()
  local caps = require("core.capability").all()
  local pipeline = require("runtime.pipeline")

  local profile = vim.g.ltos_profile or "full"
  local state = pipeline.state()

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

  -- Per-stage build timings
  local timings = vim.g.ltos_last_build_timings
  if timings then
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Last build timings:"
    for _, stage in ipairs({ "collect", "normalize", "resolve", "optimize", "codegen" }) do
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
