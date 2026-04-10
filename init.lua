-- ~/.config/nvim/init.lua
-- nvim-config v2 · redskaber
-- entry: bootstrap core, then hand off to lazy

require("core.bootstrap") -- earliest-possible inits (netrw, etc.)
require("config.lazy")
