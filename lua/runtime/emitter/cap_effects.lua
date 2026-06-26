-- lua/runtime/emitter/cap_effects.lua
-- Layer 4 emitter: side-effects for cap adapters that return no LazySpecs.

local preset_mod = require("modules.capability.keybind_presets")

local M = {}

local _applied = false

local function apply_binding(binding, source)
  if not binding.lhs or not binding.rhs then
    return
  end
  vim.keymap.set(binding.mode or "n", binding.lhs, binding.rhs, {
    desc = binding.desc or source,
    silent = true,
  })
end

--- Apply keybind capabilities from ir.ext_caps (once per session).
---@param ir IR
function M.apply_keybinds(ir)
  if _applied or not ir or not ir.ext_caps then
    return
  end

  local bucket = ir.ext_caps.keybind or {}
  for mod_path, cap in pairs(bucket) do
    if cap.preset then
      for _, binding in ipairs(preset_mod.resolve(cap.preset)) do
        apply_binding(binding, ("ltos:preset:%s"):format(cap.preset))
      end
    end
    if cap.bindings then
      for _, binding in ipairs(cap.bindings) do
        apply_binding(binding, ("ltos:%s"):format(mod_path))
      end
    end
  end

  _applied = true
end

---@param ir IR
function M.apply_all(ir) M.apply_keybinds(ir) end

function M._reset() _applied = false end

return M