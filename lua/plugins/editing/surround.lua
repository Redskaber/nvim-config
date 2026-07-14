-- ~/.config/nvim/lua/plugins/editing/surround.lua
-- Surround operations: add / change / delete surrounding pairs.
--
-- Responsibility boundary (职责分离):
--   • LTOS adapter: build-time toolchain config (LSP/formatter/linter).
--   • This file: editing-layer text manipulation (surround pairs).
--
-- mini.surround: from the mini.nvim ecosystem (consistent with mini.ai +
-- mini.pairs already in this config). Provides:
--   • sa  — surround add       (saiw)  → surround inner word with )
--   • sd  — surround delete    (sd)    → delete surrounding )
--   • sr  — surround replace   (sr)]   → replace surrounding ) with ]
--   • sf  — surround find      (sf)    → find surrounding )
--   • sh  — surround highlight (sh)    → highlight surrounding )
--   • sn  — surround update n_lines
--
-- Lightweight (~150 LOC), no dependencies, integrates with which-key.
return {
  {
    "nvim-mini/mini.surround",
    event = "VeryLazy",
    opts = {
      mappings = {
        add = "sa",            -- surround add
        delete = "sd",         -- surround delete
        find = "sf",           -- surround find
        find_left = "sF",      -- surround find left
        highlight = "sh",      -- surround highlight
        replace = "sr",        -- surround replace
        update_n_lines = "sn", -- surround update n_lines
      },
      search_method = "cover_or_nearest",
      n_lines = 50,
      respect_selection_type = false,
    },
    config = function(_, opts)
      require("mini.surround").setup(opts)
    end,
  },
}