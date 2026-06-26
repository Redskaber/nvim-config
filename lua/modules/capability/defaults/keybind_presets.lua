-- lua/modules/capability/defaults/keybind_presets.lua
-- Pure preset binding tables (data-driven, no vim API).
--
-- FIX-P2-6 (2026-06-26): Now references core.domain.keybind_presets_data
-- for preset name constants, so the "single source of truth" invariant
-- (AUDIT CORRIGENDUM §1.5) is honored. Previously this file hardcoded
-- the strings "vim"/"helix"/"emacs" as table keys, duplicating the data
-- module and risking drift if a new preset was added.
--
-- The binding data itself (lhs/rhs/desc triples) is still defined here,
-- not in the data module — the data module only owns the preset *names*.

local presets_data = require("core.domain.keybind_presets_data")

return {
  -- Use the canonical constant from the data module as the key, so
  -- renaming a preset (e.g. "vim" → "vim_legacy") only needs one edit
  -- in keybind_presets_data.lua.
  [presets_data.VIM] = {
    { lhs = "<C-h>", rhs = "<C-w>h", mode = "n", desc = "Window left" },
    { lhs = "<C-j>", rhs = "<C-w>j", mode = "n", desc = "Window down" },
    { lhs = "<C-k>", rhs = "<C-w>k", mode = "n", desc = "Window up" },
    { lhs = "<C-l>", rhs = "<C-w>l", mode = "n", desc = "Window right" },
  },
  [presets_data.HELIX] = {
    { lhs = "<C-w>h", rhs = "<C-w>h", mode = "n", desc = "Window left" },
    { lhs = "<C-w>j", rhs = "<C-w>j", mode = "n", desc = "Window down" },
    { lhs = "<C-w>k", rhs = "<C-w>k", mode = "n", desc = "Window up" },
    { lhs = "<C-w>l", rhs = "<C-w>l", mode = "n", desc = "Window right" },
    { lhs = "gd", rhs = "gd", mode = "n", desc = "Go to definition" },
  },
  [presets_data.EMACS] = {
    { lhs = "<C-x>o", rhs = "<C-w>w", mode = "n", desc = "Other window" },
    { lhs = "<C-x>0", rhs = "<C-w>c", mode = "n", desc = "Close window" },
    { lhs = "<C-x>1", rhs = "<C-w>o", mode = "n", desc = "Close other windows" },
  },
}
