-- lua/runtime/passes/collect_ext.lua
-- P3: Collects external capability modules and populates ir.ext_caps.

local M = {}

local ir_mod = require("core.compiler.ir")
local util = require("core.kernel.util")
local ports = require("core.compiler.ports")
-- removed modules.capability.schema — ext_schema covers all validation
local ext_schema = require("core.domain.ext_schema")
local cap_graph = require("modules.capability.graph")
local cap_registry = require("modules.capability.registry")

local _registered_modules = {}

function M.register(modules)
  assert(type(modules) == "table", "modules must be a table")
  _registered_modules = modules
  cap_registry._reset()
  for _, mod_path in ipairs(modules) do
    local ok, cap = pcall(require, mod_path)
    if ok and type(cap) == "table" and cap.cap_type then
      cap_registry.register(cap.cap_type, mod_path)
    end
  end
end

function M.registered()
  return _registered_modules
end

local function module_hash(mod_path)
  local path = ports.resolve_runtime_file(mod_path:gsub("%.", "/") .. ".lua")
  if not path then
    return "?"
  end
  return util.file_content_hash(path) or "?"
end

local function find_seeded_cap(ast_seed, mod_path)
  if not ast_seed or not ast_seed.ext_caps then
    return nil
  end
  for _, bucket in pairs(ast_seed.ext_caps) do
    if bucket[mod_path] then
      return bucket[mod_path]
    end
  end
  return nil
end

local function load_cap(mod_path, ast_seed, diagnostics, stage)
  if ast_seed and ast_seed.module_hashes and ast_seed.current_hashes then
    if ast_seed.module_hashes[mod_path] == ast_seed.current_hashes[mod_path] then
      local seeded = find_seeded_cap(ast_seed, mod_path)
      if seeded then
        return seeded
      end
    end
  end

  local ok, cap = pcall(require, mod_path)
  if not ok then
    diagnostics[#diagnostics + 1] = ir_mod.diag(
      stage,
      mod_path,
      ("Failed to load capability module '%s': %s"):format(mod_path, cap)
    )
    return nil
  end
  return cap
end

local function validate_cap(mod_path, cap, diagnostics, stage)
  if cap.cap_type == "lang" then
    diagnostics[#diagnostics + 1] = ir_mod.diag(
      stage,
      mod_path,
      "cap_type 'lang' is reserved for lang modules; use modules/lang/* instead"
    )
    return false
  end

  -- unified validation via ext_schema only.
  -- Previously called both modules.capability.schema (basic) and
  -- core.domain.ext_schema (per-type). The latter covers all checks
  -- the former did, so the duplicate is removed to avoid double diagnostics.
  local ext_res = ext_schema.validate(cap.cap_type, mod_path, cap)
  if not ext_res.ok then
    -- extract .message and .severity from Diagnostic objects.
    -- Previously passed entire table as message → tostring(table) in format_diagnostics.
    for _, d in ipairs(ext_res.diags) do
      diagnostics[#diagnostics + 1] = ir_mod.diag(stage, mod_path, d.message or "?", d.severity or "error")
    end
    return false
  end

  for _, d in ipairs(ext_res.diags) do
    diagnostics[#diagnostics + 1] = ir_mod.diag(stage, mod_path, d.message or "?", "warn")
  end

  return true
end

M.pass = {
  name = "collect_ext",
  input_state = "collecting",
  output_state = "collecting",

  run = function(ir)
    local next_ir = ir_mod.with(ir, { ext_caps = util.deep_copy(ir.ext_caps) })
    local module_hashes = util.deep_copy(ir.meta.module_hashes or {})
    local diagnostics = util.deep_copy(ir.diagnostics or {})
    local ast_seed = ir.meta and ir.meta.ast_seed
    local graph_input = {}

    for _, mod_path in ipairs(_registered_modules) do
      local cap = load_cap(mod_path, ast_seed, diagnostics, next_ir.stage)
      if cap and validate_cap(mod_path, cap, diagnostics, next_ir.stage) then
        graph_input[#graph_input + 1] = { mod_path = mod_path, cap = cap }
        module_hashes[mod_path] = module_hash(mod_path)
      end
    end

    local order, graph_diags = cap_graph.sort(graph_input)
    for _, d in ipairs(graph_diags) do
      diagnostics[#diagnostics + 1] = d
    end

    local by_path = {}
    for _, entry in ipairs(graph_input) do
      by_path[entry.mod_path] = entry.cap
    end

    for _, mod_path in ipairs(order) do
      local cap = by_path[mod_path]
      if cap then
        next_ir.ext_caps[cap.cap_type] = next_ir.ext_caps[cap.cap_type] or {}
        next_ir.ext_caps[cap.cap_type][mod_path] = cap
      end
    end

    return ir_mod.with(next_ir, {
      diagnostics = diagnostics,
      meta = util.merge(next_ir.meta, { module_hashes = module_hashes }),
    })
  end,
}

-- Moved require-time side effect into setup(). Unlike pipeline.lua (which
-- stays at require-time for orchestrator reasons), collect_ext.lua is a
-- pluggable pass module and should follow P6-C2 pattern.
-- NOTE: _setup_done flag was REMOVED because collect_ext.register() REPLACES
-- the module list (not appends), so setup() is naturally idempotent.
-- This also handles test scenarios where register() is called to override
-- defaults, then setup() needs to restore them.
local cap_defaults = require("runtime.defaults.caps")

--- Re-register default cap modules. Safe to call multiple times (register() replaces).
---@return boolean always true
function M.setup()
  M.register(cap_defaults.modules)
  return true
end

return M
