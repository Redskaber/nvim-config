-- lua/runtime/defaults/phases.lua
-- Default phase registrations (P2: externalized from pipeline.lua)
-- P6-D1: Uses declarative after/before ordering instead of raw priority numbers.
--        Priority is retained as tie-breaker within the same dependency group.

return {
  phases = {
    -- Phase 1: collect — no dependencies, runs first
    {
      path = "runtime.passes.collect",
      priority = 10,
    },

    -- Phase 1.5: collect_ext — runs after collect (needs IR.caps populated)
    {
      path = "runtime.passes.collect_ext",
      priority = 15,
      after = { "collect" },
    },

    -- Phase 2: normalize — after both collect phases
    {
      path = "runtime.passes.normalize",
      priority = 20,
      after = { "collect_ext" },
    },

    -- Phase 2.5: canonicalize — after normalize (needs HIR with fn closures)
    {
      path = "runtime.passes.canonicalize",
      priority = 30,
      after = { "normalize" },
    },

    -- Phase 3: resolve — after canonicalize (reads ir.symbols)
    {
      path = "runtime.passes.resolve",
      priority = 40,
      after = { "canonicalize" },
    },

    -- Phase 4: optimize — after resolve (reads ir.resolved)
    {
      path = "runtime.passes.optimize",
      priority = 50,
      after = { "resolve" },
    },

    -- Phase 4.5: cap_resolve — after optimize (reads LIR; produces cap_specs)
    {
      path = "runtime.passes.cap_resolve",
      priority = 55,
      after = { "optimize" },
    },
  },
  -- Codegen is always last — handled separately by PhaseRegistry.register_codegen()
  codegen = "runtime.passes.codegen",
}