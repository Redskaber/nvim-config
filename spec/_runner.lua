-- spec/_runner.lua
-- LTOS Unified Test Runner
-- Supports: describe/it/before_each/after_each/tags/skip/only
-- Design: pure value state, no module-level mutable globals between suites

local M = {}

-- ── ANSI colours (disabled in CI / no-tty) ───────────────────────────────────

local _tty = (vim and vim.fn and vim.fn.has("ttyin") == 1) or false
local function c(code, s)
  if not _tty then
    return s
  end
  return "\27[" .. code .. "m" .. s .. "\27[0m"
end
local GREEN = function(s)
  return c("32", s)
end
local RED = function(s)
  return c("31", s)
end
local YELLOW = function(s)
  return c("33", s)
end
local DIM = function(s)
  return c("2", s)
end
local BOLD = function(s)
  return c("1", s)
end

-- ── Result value types ────────────────────────────────────────────────────────

---@class TestResult
---@field label   string
---@field status  "pass"|"fail"|"skip"
---@field err?    string
---@field tags    string[]
---@field elapsed number

-- ── Runner state (per run_suite call, not global) ─────────────────────────────

---@class Suite
---@field results    TestResult[]
---@field passed     number
---@field failed     number
---@field skipped    number
---@field depth      number            describe nesting depth
---@field prefix     string[]          label prefix stack
---@field before_each (fun())[]
---@field after_each  (fun())[]
---@field tag_filter  table<string,boolean>|nil  nil = run all

local function new_suite(tag_filter)
  return {
    results = {},
    passed = 0,
    failed = 0,
    skipped = 0,
    depth = 0,
    prefix = {},
    before_each = {},
    after_each = {},
    tag_filter = tag_filter,
  }
end

-- active suite for DSL functions (set during run_module)
local _active = nil

-- ── DSL: describe ─────────────────────────────────────────────────────────────

function M.describe(label, fn)
  local s = _active
  assert(s, "describe() called outside of a test module")
  s.depth = s.depth + 1
  s.prefix[#s.prefix + 1] = label
  -- snapshot hooks so nested describe gets its own scope
  local saved_before = { table.unpack(s.before_each) }
  local saved_after = { table.unpack(s.after_each) }
  local ok, err = pcall(fn)
  -- restore
  s.before_each = saved_before
  s.after_each = saved_after
  s.prefix[#s.prefix] = nil
  s.depth = s.depth - 1
  if not ok then
    -- surface describe-level errors as a failed test
    M._record(s, table.concat(s.prefix, " › ") .. " › " .. label, false, tostring(err), {})
  end
end

-- ── DSL: before_each / after_each ─────────────────────────────────────────────

function M.before_each(fn)
  local s = _active
  assert(s, "before_each() called outside of a test module")
  s.before_each[#s.before_each + 1] = fn
end

function M.after_each(fn)
  local s = _active
  assert(s, "after_each() called outside of a test module")
  s.after_each[#s.after_each + 1] = fn
end

-- ── DSL: it / test / skip / only ─────────────────────────────────────────────

---@param label string
---@param fn    fun()
---@param tags? string[]
function M.it(label, fn, tags)
  local s = _active
  assert(s, "it() called outside of a test module")
  tags = tags or {}
  local full_label = (#s.prefix > 0) and (table.concat(s.prefix, " › ") .. " › " .. label) or label

  -- tag filter
  if s.tag_filter and next(s.tag_filter) then
    local match = false
    for _, t in ipairs(tags) do
      if s.tag_filter[t] then
        match = true
        break
      end
    end
    if not match then
      M._record(s, full_label, "skip", nil, tags)
      return
    end
  end

  -- run before_each hooks
  for _, hook in ipairs(s.before_each) do
    local hok, herr = pcall(hook)
    if not hok then
      M._record(s, full_label, false, "[before_each] " .. tostring(herr), tags)
      return
    end
  end

  local t0 = os.clock()
  local ok, err = pcall(fn)
  local elapsed = os.clock() - t0

  -- run after_each hooks (even on failure)
  for _, hook in ipairs(s.after_each) do
    pcall(hook)
  end

  M._record(s, full_label, ok, ok and nil or tostring(err), tags, elapsed)
end

-- alias
M.test = M.it

function M.skip(label, _fn, tags)
  local s = _active
  assert(s, "skip() called outside of a test module")
  tags = tags or {}
  local full_label = (#s.prefix > 0) and (table.concat(s.prefix, " › ") .. " › " .. label) or label
  M._record(s, full_label, "skip", nil, tags)
end

-- ── Internal record ───────────────────────────────────────────────────────────

function M._record(s, label, status_or_ok, err, tags, elapsed)
  local status
  if status_or_ok == "skip" then
    status = "skip"
    s.skipped = s.skipped + 1
  elseif status_or_ok then
    status = "pass"
    s.passed = s.passed + 1
  else
    status = "fail"
    s.failed = s.failed + 1
  end
  s.results[#s.results + 1] = {
    label = label,
    status = status,
    err = err,
    tags = tags or {},
    elapsed = elapsed or 0,
  }
end

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
    error(msg or "assert_true failed", 2)
  end
end

function M.assert_false(v, msg)
  if v then
    error(msg or "assert_false failed", 2)
  end
end

function M.assert_nil(v, msg)
  if v ~= nil then
    error((msg or "assert_nil") .. ": expected nil, got " .. tostring(v), 2)
  end
end

function M.assert_not_nil(v, msg)
  if v == nil then
    error(msg or "assert_not_nil: expected non-nil", 2)
  end
end

function M.assert_type(v, t, msg)
  if type(v) ~= t then
    error((msg or "assert_type") .. ": expected " .. t .. ", got " .. type(v), 2)
  end
end

function M.assert_match(s, pattern, msg)
  if type(s) ~= "string" or not s:find(pattern, 1, false) then
    error((msg or "assert_match") .. ": pattern " .. pattern .. " not found in: " .. tostring(s), 2)
  end
end

function M.assert_contains(tbl, val, msg)
  if type(tbl) ~= "table" then
    error((msg or "assert_contains") .. ": expected table", 2)
  end
  for _, v in ipairs(tbl) do
    if v == val then
      return
    end
  end
  error((msg or "assert_contains") .. ": value " .. tostring(val) .. " not in list", 2)
end

function M.assert_no_errors(ir, msg)
  local counts = require("core.compiler.ir").diag_counts(ir)
  if counts.errors > 0 then
    local fmt = require("core.compiler.ir").format_diagnostics(ir)
    error((msg or "assert_no_errors") .. ": " .. counts.errors .. " error(s):\n" .. fmt, 2)
  end
end

-- ── Module runner ─────────────────────────────────────────────────────────────

---@param mod_path string   Lua module path (e.g. "spec.core.ir_spec")
---@param suite    Suite
local function run_module(mod_path, suite)
  -- load module; it calls describe/it via DSL
  local prev = _active
  _active = suite
  local ok, err = pcall(require, mod_path)
  _active = prev
  if not ok then
    M._record(suite, "[load] " .. mod_path, false, tostring(err), {})
  end
end

-- ── Report printer ────────────────────────────────────────────────────────────

local function print_report(suite, module_name)
  local header = BOLD("── " .. (module_name or "spec") .. " ──")
  print(header)
  for _, r in ipairs(suite.results) do
    if r.status == "pass" then
      print(GREEN("  ✓ ") .. DIM(r.label))
    elseif r.status == "skip" then
      print(YELLOW("  ⊘ ") .. DIM(r.label))
    else
      print(RED("  ✗ ") .. r.label)
      if r.err then
        for line in r.err:gmatch("[^\n]+") do
          print("      " .. DIM(line))
        end
      end
    end
  end
end

-- ── Public: run_modules ───────────────────────────────────────────────────────

---@param modules    string[]             list of spec module paths
---@param opts?      { tags?: string[], verbose?: boolean, fail_fast?: boolean }
---@return number passed, number failed, number skipped
function M.run_modules(modules, opts)
  opts = opts or {}
  local tag_filter = nil
  if opts.tags and #opts.tags > 0 then
    tag_filter = {}
    for _, t in ipairs(opts.tags) do
      tag_filter[t] = true
    end
  end

  local total_passed, total_failed, total_skipped = 0, 0, 0

  for _, mod_path in ipairs(modules) do
    local suite = new_suite(tag_filter)
    -- clear require cache so modules can be re-run cleanly
    package.loaded[mod_path] = nil
    run_module(mod_path, suite)

    if opts.verbose ~= false then
      print_report(suite, mod_path)
    end

    total_passed = total_passed + suite.passed
    total_failed = total_failed + suite.failed
    total_skipped = total_skipped + suite.skipped

    if opts.fail_fast and suite.failed > 0 then
      print(RED("FAIL_FAST: stopping after first failure"))
      break
    end
  end

  -- summary line
  local summary = ("%d passed, %d failed, %d skipped"):format(total_passed, total_failed, total_skipped)
  if total_failed > 0 then
    print(RED("FAIL") .. "  " .. summary)
  else
    print(GREEN("PASS") .. "  " .. summary)
  end

  return total_passed, total_failed, total_skipped
end

function M.run_modules_compat(modules, opts)
  opts = opts or {}
  local tag_filter = nil
  if opts.tags and #opts.tags > 0 then
    tag_filter = {}
    for _, t in ipairs(opts.tags) do
      tag_filter[t] = true
    end
  end

  local total_passed, total_failed, total_skipped = 0, 0, 0

  for _, mod_path in ipairs(modules) do
    local suite = new_suite(tag_filter)
    package.loaded[mod_path] = nil
    -- try DSL first, then flat
    local prev = _active
    _active = suite
    local ok, result = pcall(require, mod_path)
    _active = prev
    if not ok then
      M._record(suite, "[load] " .. mod_path, false, tostring(result), {})
    elseif type(result) == "table" and #suite.results == 0 then
      -- flat style fallback
      local names = {}
      for k in pairs(result) do
        if type(result[k]) == "function" and k:match("^test_") then
          names[#names + 1] = k
        end
      end
      table.sort(names)
      local saved_active = _active
      _active = suite
      for _, name in ipairs(names) do
        M.it(name, result[name])
      end
      _active = saved_active
    end

    if opts.verbose ~= false then
      print_report(suite, mod_path)
    end

    total_passed = total_passed + suite.passed
    total_failed = total_failed + suite.failed
    total_skipped = total_skipped + suite.skipped

    if opts.fail_fast and suite.failed > 0 then
      print(RED("FAIL_FAST: stopping after first failure"))
      break
    end
  end

  local summary = ("%d passed, %d failed, %d skipped"):format(total_passed, total_failed, total_skipped)
  if total_failed > 0 then
    print(RED("FAIL") .. "  " .. summary)
  else
    print(GREEN("PASS") .. "  " .. summary)
  end

  return total_passed, total_failed, total_skipped
end

return M
