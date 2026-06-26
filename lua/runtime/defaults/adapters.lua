-- lua/runtime/defaults/adapters.lua
-- Default adapter registrations (P2: externalized from registry.lua)

return {
  { path = "runtime.adapters.lsp", priority = 10 },
  { path = "runtime.adapters.mason", priority = 20 },
  { path = "runtime.adapters.treesitter", priority = 30 },
  { path = "runtime.adapters.conform", priority = 40 },
  { path = "runtime.adapters.lint", priority = 50 },
}

