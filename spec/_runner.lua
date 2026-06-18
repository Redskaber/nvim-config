-- spec/_runner.lua
-- LTOS Unified Test Runner v2
--
-- Design principles:
--   • Pipeline: collect → filter → execute → report
--   • State machine: IDLE → RUNNING → DONE/ERROR per suite
--   • Dependency inversion: reporter is injectable
--   • Data-driven: test catalogue is a pure value
--   • No circular require: package.path is fixed by ltos_tests.lua before
--     this file is required; package.loaded["spec._runner"] is set by Lua's
--     native loader before the module body runs, so spec files that call
--     require("spec._runner") get the cached table immediately.
--
-- DSL:
--   local R = require("spec._runner")
--   R.describe("suite label", function()
--     R.before_each(function() ... end)
--     R.after_each(function()  ... end)
--     R.it("test label", function() R.assert_eq(1, 1) end)
--     R.skip("pending test", function() end)
--   end)

local M = {}

-- ── Lua 5.1 / LuaJIT compat ──────────────────────────────────────────────────
-- table.unpack was introduced in Lua 5.2; LuaJIT (used by Neovim) exposes it
-- as the global unpack(). Provide a unified alias.
local _unpack = table.unpack or unpack -- luacheck: globals unpack

-- ── ANSI colour helpers ───────────────────────────────────────────────────────

local _tty = (vim and vim.fn and vim.fn.has("ttyin") == 1) or false
local function paint(code, s)
  if not _tty then
    return s
  end
  return "\27[" .. code .. "m" .. s .. "\27[0m"
end
local C = {
  green = function(s)
    return paint("32", s)
  end,
  red = function(s)
    return paint("31", s)
  end,
  yellow = function(s)
    return paint("33", s)
  end,
  dim = function(s)
    return paint("2", s)
  end,
  bold = function(s)
    return paint("1", s)
  end,
}
M.colour = C

-- ── Suite state ───────────────────────────────────────────────────────────────

---@class SuiteState
---@field name        string
---@field results     table[]
---@field passed      number
---@field failed      number
---@field skipped     number
---@field prefix      string[]
---@field before_each fun()[]
---@field after_each  fun()[]
---@field tag_filter  table<string,boolean>|nil

local function new_suite(name, tag_filter)
  return {
    name = name or "unnamed",
    results = {},
    passed = 0,
    failed = 0,
    skipped = 0,
    prefix = {},
    before_each = {},
    after_each = {},
    tag_filter = tag_filter,
  }
end

-- The active suite is stored as a module-level variable.
-- Lua's require() sets package.loaded["spec._runner"] = M before running this
-- body, so any spec file that calls require("spec._runner") during load_module()
-- gets the already-complete M table — no circular dependency.
local _active = nil

-- ── Internal recorder ─────────────────────────────────────────────────────────

local function record(s, label, status, err, tags, elapsed)
  if status == "pass" then
    s.passed = s.passed + 1
  elseif status == "fail" then
    s.failed = s.failed + 1
  elseif status == "skip" then
    s.skipped = s.skipped + 1
  end
  s.results[#s.results + 1] = {
    label = label,
    status = status,
    err = err,
    tags = tags or {},
    elapsed = elapsed or 0,
    suite = s.name,
  }
end

-- ── DSL: describe ─────────────────────────────────────────────────────────────

function M.describe(label, fn)
  local s = _active
  assert(s, "describe() called outside a test module context")
  s.prefix[#s.prefix + 1] = label
  -- Snapshot hooks so nested describe gets its own hook scope
  local saved_before = { _unpack(s.before_each) }
  local saved_after = { _unpack(s.after_each) }
  local ok, err = pcall(fn)
  s.before_each = saved_before
  s.after_each = saved_after
  s.prefix[#s.prefix] = nil
  if not ok then
    local full = table.concat(s.prefix, " › ") .. " › " .. label
    record(s, full, "fail", tostring(err), {})
  end
end

-- ── DSL: before_each / after_each ────────────────────────────────────────────

function M.before_each(fn)
  assert(_active, "before_each() called outside a test module context")
  _active.before_each[#_active.before_each + 1] = fn
end

function M.after_each(fn)
  assert(_active, "after_each() called outside a test module context")
  _active.after_each[#_active.after_each + 1] = fn
end

-- ── DSL: it ───────────────────────────────────────────────────────────────────

function M.it(label, fn, tags)
  local s = _active
  assert(s, "it() called outside a test module context")
  tags = tags or {}
  local full = #s.prefix > 0 and (table.concat(s.prefix, " › ") .. " › " .. label) or label

  -- Tag filter
  if s.tag_filter and next(s.tag_filter) then
    local match = false
    for _, t in ipairs(tags) do
      if s.tag_filter[t] then
        match = true
        break
      end
    end
    if not match then
      record(s, full, "skip", nil, tags)
      return
    end
  end

  -- before_each hooks
  for _, hook in ipairs(s.before_each) do
    local hok, herr = pcall(hook)
    if not hok then
      record(s, full, "fail", "[before_each] " .. tostring(herr), tags)
      return
    end
  end

  local t0 = os.clock()
  local ok, err = pcall(fn)
  local elapsed = os.clock() - t0

  -- after_each hooks (always run)
  for _, hook in ipairs(s.after_each) do
    pcall(hook)
  end

  record(s, full, ok and "pass" or "fail", ok and nil or tostring(err), tags, elapsed)
end

-- ── DSL: skip ─────────────────────────────────────────────────────────────────

function M.skip(label, _fn, tags)
  assert(_active, "skip() called outside a test module context")
  local full = #_active.prefix > 0 and (table.concat(_active.prefix, " › ") .. " › " .. label) or label
  record(_active, full, "skip", nil, tags or {})
end

-- Alias
M.test = M.it

-- ── Assertions ────────────────────────────────────────────────────────────────

function M.assert_eq(a, b, msg)
  if a ~= b then
    error((msg or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
  end
end

function M.assert_ne(a, b, msg)
  if a == b then
    error((msg or "assert_ne") .. ": expected values to differ, both = " .. tostring(a), 2)
  end
end

function M.assert_true(v, msg)
  if not v then
    error(msg or ("assert_true: expected truthy, got " .. tostring(v)), 2)
  end
end

function M.assert_false(v, msg)
  if v then
    error(msg or ("assert_false: expected falsy, got " .. tostring(v)), 2)
  end
end

function M.assert_nil(v, msg)
  if v ~= nil then
    error((msg or "assert_nil") .. ": expected nil, got " .. tostring(v), 2)
  end
end

function M.assert_not_nil(v, msg)
  if v == nil then
    error(msg or "assert_not_nil: value was nil", 2)
  end
end

function M.assert_type(v, t, msg)
  if type(v) ~= t then
    error((msg or "assert_type") .. ": expected " .. t .. ", got " .. type(v) .. " (" .. tostring(v) .. ")", 2)
  end
end

function M.assert_match(s, pattern, msg)
  if type(s) ~= "string" or not s:find(pattern, 1, false) then
    error((msg or "assert_match") .. ": pattern " .. tostring(pattern) .. " not found in: " .. tostring(s), 2)
  end
end

function M.assert_contains(tbl, val, msg)
  if type(tbl) ~= "table" then
    error((msg or "assert_contains") .. ": expected table, got " .. type(tbl), 2)
  end
  for _, v in ipairs(tbl) do
    if v == val then
      return
    end
  end
  error((msg or "assert_contains") .. ": " .. tostring(val) .. " not found in list", 2)
end

function M.assert_gt(a, b, msg)
  if not (a > b) then
    error((msg or "assert_gt") .. ": expected " .. tostring(a) .. " > " .. tostring(b), 2)
  end
end

function M.assert_gte(a, b, msg)
  if not (a >= b) then
    error((msg or "assert_gte") .. ": expected " .. tostring(a) .. " >= " .. tostring(b), 2)
  end
end

function M.assert_no_errors(ir, msg)
  local ir_mod = require("core.compiler.ir")
  local counts = ir_mod.diag_counts(ir)
  if counts.errors > 0 then
    local fmt = ir_mod.format_diagnostics(ir)
    error((msg or "assert_no_errors") .. ": " .. counts.errors .. " error(s):\n" .. fmt, 2)
  end
end

-- ── Default reporter ──────────────────────────────────────────────────────────

local _reporter = {
  on_suite_start = function(name)
    print(C.bold("── " .. name .. " ──"))
  end,
  on_result = function(r)
    if r.status == "pass" then
      print(C.green("  ✓ ") .. C.dim(r.label))
    elseif r.status == "skip" then
      print(C.yellow("  ⊘ ") .. C.dim(r.label))
    else
      print(C.red("  ✗ ") .. r.label)
      if r.err then
        for line in r.err:gmatch("[^\n]+") do
          print("      " .. C.dim(line))
        end
      end
    end
  end,
  on_suite_done = function(s)
    local line = string.format("    passed=%d failed=%d skipped=%d", s.passed, s.failed, s.skipped)
    print(s.failed > 0 and C.red(line) or C.dim(line))
  end,
}

--- Inject a custom reporter (dependency inversion).
function M.set_reporter(r)
  _reporter = r
end

-- ── Module loader ─────────────────────────────────────────────────────────────

local function load_module(mod_path, suite)
  -- Clear spec module from cache so it re-executes with the new active suite.
  -- IMPORTANT: do NOT clear "spec._runner" itself — that would cause a
  -- circular require the next time a spec file calls require("spec._runner").
  if mod_path ~= "spec._runner" then
    package.loaded[mod_path] = nil
  end

  local prev = _active
  _active = suite
  local ok, err = pcall(require, mod_path)
  _active = prev

  if not ok then
    record(suite, "[load:" .. mod_path .. "]", "fail", tostring(err), {})
  end
end

-- ── Public: run_suite ─────────────────────────────────────────────────────────

---@param mod_path   string
---@param tag_filter table<string,boolean>|nil
---@return SuiteState
function M.run_suite(mod_path, tag_filter)
  local suite = new_suite(mod_path, tag_filter)
  _reporter.on_suite_start(mod_path)
  load_module(mod_path, suite)
  for _, r in ipairs(suite.results) do
    _reporter.on_result(r)
  end
  _reporter.on_suite_done(suite)
  return suite
end

-- ── Public: run (batch) ───────────────────────────────────────────────────────

---@class RunOpts
---@field tags?      string[]
---@field verbose?   boolean
---@field fail_fast? boolean

---@param modules string[]
---@param opts?   RunOpts
---@return number passed, number failed, number skipped
function M.run(modules, opts)
  opts = opts or {}
  local tag_filter = nil
  if opts.tags and #opts.tags > 0 then
    tag_filter = {}
    for _, t in ipairs(opts.tags) do
      tag_filter[t] = true
    end
  end

  local tp, tf, ts = 0, 0, 0
  for _, mod_path in ipairs(modules) do
    local suite = M.run_suite(mod_path, tag_filter)
    tp = tp + suite.passed
    tf = tf + suite.failed
    ts = ts + suite.skipped
    if opts.fail_fast and suite.failed > 0 then
      print(C.red("FAIL_FAST"))
      break
    end
  end

  if opts.verbose ~= false then
    local summary = string.format("%d passed, %d failed, %d skipped", tp, tf, ts)
    print(tf > 0 and C.red("FAIL  " .. summary) or C.green("PASS  " .. summary))
  end
  return tp, tf, ts
end

return M
