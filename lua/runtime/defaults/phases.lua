-- lua/runtime/defaults/phases.lua
-- Default phase registrations (P2: externalized from pipeline.lua)

return {
  phases = {
    { path = "runtime.passes.collect", priority = 10 },
    { path = "runtime.passes.collect_ext", priority = 15 },
    { path = "runtime.passes.normalize", priority = 20 },
    { path = "runtime.passes.canonicalize", priority = 30 },
    { path = "runtime.passes.resolve", priority = 40 },
    { path = "runtime.passes.optimize", priority = 50 },
    { path = "runtime.passes.cap_resolve", priority = 55 },
  },
  codegen = "runtime.passes.codegen",
}
