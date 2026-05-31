-- lua/runtime/defaults/caps.lua
-- Default external capability module list (P3: data-driven, no hardcode in passes).

return {
  modules = {
    "modules.cap.image",
    "modules.cap.media",
    "modules.cap.ai",
    "modules.cap.keybind",
    "modules.editor.image",
    "modules.ai.copilot",
    "modules.keybind.default",
  },
}
