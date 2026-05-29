# LTOS Architecture Invariants

> These invariants are **non-negotiable**. Any code that violates them is an architecture bug, not a feature.
> Enforced by convention; CI script: `scripts/check_layer_boundaries.sh`

---

## Invariant 1 — IR is an Immutable Value Object

Every Phase receives an IR and **must return a NEW IR**. The input IR is never mutated.

```lua
-- CORRECT: copy-on-write
return ir_mod.with(ir, { stage = "HIR", caps = next_caps })

-- WRONG: mutation
ir.caps = next_caps   -- ← architecture violation
return ir
```

**Enforcement:** `_G._ltos_debug_freeze = true` in `debug_run()` activates `util.freeze()` on every Phase input. Any write attempt raises immediately.

---

## Invariant 2 — Phase is a Pure Function

A Phase's `run(ir) -> IR` must have **no observable side-effects** on shared state.

- No writes to module-level variables
- No calls to `vim.notify` (use IR diagnostics instead)
- No mutation of the input IR (see Invariant 1)
- `validate(ir) -> Diagnostic[]` is also pure

**Exception:** `collect` pass calls `cap_mod.new()` to create a local accumulator — this is a local value, not shared state.

---

## Invariant 3 — Adapter is the Sole Side-Effect Boundary

`runtime/adapters/*.lua` are the **only** files that produce `LazySpec[]` tables.  
`runtime/emitter/init.lua` is the **only** file that calls `vim.notify` during codegen.

Adapters must:

- Only **read** the IR — never write it
- Return pure Lua tables (`LazySpec[]`)
- Read runtime config from `ir.meta.build_request` — not `vim.g` directly
- Avoid `vim.*` where possible; config flows through BuildRequest (P0)

---

## Invariant 4 — Strategy is Stateless and Replaceable

A Strategy is a named resolver: `resolve(bufnr) -> string[]`.

- No module-level mutable state
- Registered once at bootstrap; registry is locked after
- Replaceable via `BuildRequest.overrides` (injected at orchestrator)

---

## Invariant 5 — Layer Dependency Direction (Strict Downward Only)

```
Layer 5 (app/config/modules)
    ↓ only
Layer 4 (runtime/passes, runtime/adapters)
    ↓ only
Layer 3 (toolchain/strategy, toolchain/rules)
    ↓ only
Layer 2 (core/domain)
    ↓ only
Layer 1 (core/compiler)
    ↓ only
Layer 0 (core/kernel)
```

No upward imports. No circular dependencies. Verified by `scripts/check_layer_boundaries.sh`.

---

## Invariant 6 — IR Stage Transitions are Forward-Only

```
AST → HIR → MIR → LIR → SPEC
```

A Phase may only advance the IR stage, never regress it. Use `ir.transition(ir)` or `ir_mod.with(ir, { stage = "HIR" })`.

---

## Invariant 7 — Cache Keys are Content-Based

Cache keys are derived from **file content hashes** (FNV-1a), not mtimes. This guarantees determinism across clock skew, `cp --preserve`, and git operations.

---

---

## Invariant 8 — DSL Modules are Pure Declarations

`modules/lang/*.lua` files must:

- Return a plain Lua table
- Contain no `require()` calls
- Contain no `vim.*` calls
- Contain no side-effects of any kind
- Declare `version = 1` (or current schema version)

---

## Invariant 9 — BuildRequest is the Sole vim.g Entry for Compilation

`runtime/build_request.lua` is the **only** module that reads `vim.g.ltos_*` build knobs.  
Passes read `ir.meta.build_request`; adapters read the same field from IR.  
Layer 3 (`toolchain/*`) receives overrides and context as function parameters only.
