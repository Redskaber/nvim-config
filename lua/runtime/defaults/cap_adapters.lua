-- lua/runtime/defaults/cap_adapters.lua
-- Default cap_type → adapter routing (P3: data-driven registry bootstrap).

return {
  { cap_type = "image", path = "runtime.adapters.image" },
  { cap_type = "media", path = "runtime.adapters.media" },
  { cap_type = "ai", path = "runtime.adapters.ai_cap" },
  { cap_type = "keybind", path = "runtime.adapters.keybind" },
}