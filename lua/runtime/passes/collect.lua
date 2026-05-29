-- lua/runtime/passes/collect.lua
-- Compiler kernel: Phase 1 — collect.
--
-- REFACTOR (TODO-3.1): CapabilitySet 是纯值对象，无全局状态。
-- TODO-7.1: per-module AST 增量缓存。
--   • 每个 module 独立计算 content hash
--   • 命中 AST tier → 直接复用已验证的 cap entry，跳过 schema 验证
--   • 任意 module 变化 → 该 module 重新验证，其他 module 复用缓存
--
-- State contract: IDLE → COLLECTING
-- IR input:  { meta, profile }
-- IR output: { meta, profile, caps }   (AST sub-layer)

local ir_mod = require("core.compiler.ir")
local cap_mod = require("core.domain.capability")
local util = require("core.kernel.util")

---@type Phase
local collect_pass = {
  name = "collect",
  input_state = "idle",
  output_state = "collecting",

  ---@param ir IR
  ---@return IR
  run = function(ir)
    local lang_modules = ir.meta.lang_modules or {}
    local ast_seed = ir.meta and ir.meta.ast_seed

    local cap_set = cap_mod.new()
    local diags = {}
    local module_hashes = {}

    -- Pre-seed from partial AST cache
    if ast_seed and ast_seed.caps and ast_seed.module_hashes and ast_seed.current_hashes then
      for _, mod in ipairs(lang_modules) do
        local name = mod:match("([^.]+)$") or mod
        local current_hash = ast_seed.current_hashes[mod]
        module_hashes[mod] = current_hash
        if ast_seed.module_hashes[mod] == current_hash and ast_seed.caps[name] then
          local new_set, add_result = cap_mod.add(cap_set, name, ast_seed.caps[name])
          cap_set = new_set
          for _, schema_d in ipairs(add_result.diags or {}) do
            diags[#diags + 1] = ir_mod.diag(
              "collect",
              mod,
              ("[schema:%s] %s — %s"):format(schema_d.code or "?", schema_d.path, schema_d.message),
              schema_d.severity or "error"
            )
          end
        end
      end
    end

    for _, mod in ipairs(lang_modules) do
      -- Skip modules already seeded from partial cache
      if ast_seed and ast_seed.module_hashes and ast_seed.current_hashes then
        if
          ast_seed.module_hashes[mod] == ast_seed.current_hashes[mod] and ast_seed.caps[mod:match("([^.]+)$") or mod]
        then
          goto continue
        end
      end

      local ok, result = pcall(require, mod)
      if not ok then
        diags[#diags + 1] = ir_mod.diag("collect", mod, "failed to load: " .. tostring(result), "error")
      elseif type(result) ~= "table" then
        diags[#diags + 1] = ir_mod.diag("collect", mod, "module did not return a table; skipping", "warn")
      else
        local name = mod:match("([^.]+)$") or mod
        -- Compute per-module content hash for incremental tracking
        local path = vim.api.nvim_get_runtime_file(mod:gsub("%.", "/") .. ".lua", false)[1]
        if path then
          module_hashes[mod] = util.file_content_hash(path) or "?"
        end
        -- cap_mod.add is pure: returns NEW set, never mutates cap_set
        local new_set, add_result = cap_mod.add(cap_set, name, result)
        cap_set = new_set

        -- Fold schema diagnostics into IR diagnostics
        for _, schema_d in ipairs(add_result.diags or {}) do
          diags[#diags + 1] = ir_mod.diag(
            "collect",
            mod,
            ("[schema:%s] %s — %s"):format(schema_d.code or "?", schema_d.path, schema_d.message),
            schema_d.severity or "error"
          )
        end
      end
      ::continue::
    end

    -- Embed snapshot into new IR
    local next_ir = ir_mod.with(ir, {
      stage = "AST",
      meta = util.merge(ir.meta or {}, { module_hashes = module_hashes }),
      caps = cap_mod.snapshot(cap_set),
      diagnostics = ir.diagnostics or {},
    })
    -- Accumulate all diagnostics
    for _, d in ipairs(diags) do
      next_ir = ir_mod.append_diag(next_ir, d)
    end
    return next_ir
  end,
}

return collect_pass
