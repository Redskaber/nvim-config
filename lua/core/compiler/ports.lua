-- lua/core/compiler/ports.lua
-- Layer 1 compiler: injectable IO / host ports (no vim API in this file).
-- Configured once from runtime/ports_bootstrap.lua before cache use.
--
-- FIX-P1-10 (2026-06-26): ensure_cache_dir default no longer shells out.
-- Previously: os.execute('mkdir -p "' .. dir:gsub('"','\\"') .. '"')
-- Risk: shell injection if `dir` ever flows from user input (e.g. custom
-- cache path). Now uses libuv (vim.loop) recursive mkdir — no shell, no
-- injection. Falls back to no-op if vim.loop unavailable (pure LuaJIT
-- without nvim — in which case ports_bootstrap.setup() must be called
-- before any cache write, which is the documented contract).

local M = {}

--- Recursive mkdir via libuv (no shell, no injection).
--- Walks path components, creating each level. Idempotent.
---@param dir string
local function fs_mkdir_p(dir)
  if not dir or dir == "" then
    return
  end
  -- Only vim.loop is available in nvim headless; the fallback no-op is
  -- safe because ports_bootstrap.setup() always overrides this default
  -- before any cache write occurs.
  if not vim or not vim.loop then
    return
  end
  local uv = vim.loop

  -- Normalise: strip trailing slash, expand "~" is caller's responsibility.
  local path = dir:gsub("/+$", "")

  -- Build the list of ancestor paths to create.
  -- e.g. "/a/b/c" → {"/a", "/a/b", "/a/b/c"}
  --      "a/b/c"  → {"a", "a/b", "a/b/c"}
  --      "a"      → {"a"}
  local parts = {}
  local first = path:sub(1, 1)
  local prefix = ""
  if first == "/" then
    prefix = "/"
    path = path:sub(2)
  end
  for segment in path:gmatch("[^/]+") do
    parts[#parts + 1] = segment
  end

  local cur = prefix
  for _, segment in ipairs(parts) do
    cur = cur .. segment
    local stat = uv.fs_stat(cur)
    if stat then
      if stat.type ~= "directory" then
        -- Exists but not a directory — bail out (do not overwrite).
        return
      end
    else
      -- FIX-P2 (2026-07-15): named constant instead of magic number.
      -- 0x1ED = 493 = 0o755 (rwxr-xr-x) in Lua's numeric format.
      local DIR_MODE_755 = 493
      local ok = uv.fs_mkdir(cur, DIR_MODE_755)
      if not ok then
        -- Race condition: another process may have created it.
        -- Verify it's now a directory; if not, bail out.
        local after = uv.fs_stat(cur)
        if not after or after.type ~= "directory" then
          return
        end
      end
    end
    cur = cur .. "/"
  end
end

local _ports = {
  cache_dir = function() return ".cache/ltos" end,
  json_encode = function(t) error("compiler ports: json_encode not configured") end,
  json_decode = function(_s) error("compiler ports: json_decode not configured") end,
  read_file = function(_path) return nil end,
  resolve_runtime_file = function(_rel) return nil end,
  debug_cache = function() return false end,
  notify = function(_level, _msg)
    -- no-op until runtime configures
  end,
  ensure_cache_dir = fs_mkdir_p,
}

-- FIX-P3 (2026-07-22): Memoize resolve_runtime_file. The module→path
-- mapping is constant within a session, but the function is called ~88
-- times per cold startup (once per module, across cache.key/collect/
-- collect_ext). The cache key is the `rel` argument; we store both nil
-- and string results so we don't repeatedly ask nvim for the same file.
local _path_cache = {}

---@class CompilerPorts
---@field cache_dir fun(): string
---@field json_encode fun(table): string
---@field json_decode fun(string): table
---@field resolve_runtime_file fun(string): string|nil
---@field debug_cache fun(): boolean
---@field notify fun(level: integer, msg: string)

--- Inject host implementations (call from Layer 4 bootstrap only).
---@param opts CompilerPorts
function M.configure(opts)
  for k, v in pairs(opts) do
    if type(v) == "function" then
      _ports[k] = v
    end
  end
  -- Defensive: if anything called resolve_runtime_file before configure()
  -- (which would have hit the default nil-returning impl), drop those stale
  -- entries so the freshly-injected impl is consulted on next call.
  _path_cache = {}
end

function M.cache_dir() return _ports.cache_dir() end

function M.json_encode(t) return _ports.json_encode(t) end

function M.json_decode(s) return _ports.json_decode(s) end

--- Read file contents (pure text). Returns string or nil.
---@param path string
---@return string|nil
function M.read_file(path) return _ports.read_file(path) end

function M.resolve_runtime_file(rel)
  if _path_cache[rel] ~= nil then
    -- Translate the `false` sentinel (cached nil result) back to nil so
    -- callers always see the documented `string|nil` return type.
    local cached = _path_cache[rel]
    return cached or nil
  end
  local result = _ports.resolve_runtime_file(rel)
  -- Cache the resolved path (string) or `false` sentinel for nil results,
  -- so negative lookups are also memoized.
  _path_cache[rel] = result or false
  return result
end

--- Clear the resolve_runtime_file memoization cache.
--- Intended for tests that swap `_ports.resolve_runtime_file` and need
--- the new implementation to take effect for already-seen `rel` values.
function M._clear_path_cache() _path_cache = {} end

function M.debug_cache() return _ports.debug_cache() end

function M.notify(level, msg) _ports.notify(level, msg) end

function M.ensure_cache_dir(dir) _ports.ensure_cache_dir(dir) end

return M

