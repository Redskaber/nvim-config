#!/usr/bin/env bash
# path: scripts/check_layer_boundaries.sh
# Layer boundary static check for LTOS architecture.
# Verifies: layer dependency direction, phase purity, adapter isolation,
#           INV-11/13/15, reverse layer violations, require-time side effects,
#           ports.notify argument order.
#
# FIX-AUDIT-P1-7 (2026-06-23): Added rules 7a-7c for systemic problem patterns.
# (7d: toolchain vim.* purity beyond vim.g; 7e: ports.notify argument order —
#  documented in AUDIT_CORRIGENDUM but not yet implemented.)

set -uo pipefail
LUA=lua/
fail=0

# check() — grep for forbidden pattern, exclude comment lines, report violations.
# Uses || true everywhere to avoid set -e issues with grep no-match exit 1.
check() {
  local src="$1" forbidden="$2" label="$3"
  local matches
  matches=$(grep -rn --include="*.lua" "$forbidden" "$src" 2>/dev/null |
    grep -v "^Binary" |
    awk -F: '
        {
          rest = ""
          for (i = 3; i <= NF; i++) rest = rest (i > 3 ? ":" : "") $i
          if (rest ~ /^[ \t]*--/) next
          print
        }
      ' || true)
  if [ -n "$matches" ]; then
    echo "FAIL [$label]:"
    echo "$matches" | head -5
    fail=1
  fi
}

# ── Layer dependency direction (forward: high → low only) ────────────────────
check "$LUA/core/kernel" 'require.*core\.compiler' "kernel→compiler"
check "$LUA/core/compiler" 'require.*core\.domain' "compiler→domain"
check "$LUA/core/domain" 'require.*toolchain' "domain→toolchain"
check "$LUA/toolchain" 'require.*runtime\.adapters' "strategy→adapters"
check "$LUA/modules" 'require.*runtime\.pipeline' "app→pipeline"
check "$LUA/modules" 'require.*runtime\.adapters' "app→adapters"
check "$LUA/config" 'require.*runtime\.adapters' "config→adapters"
check "$LUA/config" 'require.*runtime\.pipeline' "config→pipeline"
check "$LUA/plugins" 'require.*runtime\.adapters' "plugins→adapters"
check "$LUA/plugins" 'require.*runtime\.pipeline' "plugins→pipeline"

# ── FIX-AUDIT-P1-7a: Reverse layer violations ────────────────────────────────
check "$LUA/toolchain" 'require.*core\.compiler' "toolchain→compiler (reverse)"
check "$LUA/modules/capability" 'require.*core\.compiler' "modules/capability→compiler (reverse)"
check "$LUA/core/domain" 'require.*core\.compiler' "domain→compiler (reverse)"

# ── env.lua must not contain prefer_system ────────────────────────────────────
if grep -n "prefer_system" "$LUA/core/kernel/env.lua" 2>/dev/null |
  grep -v "^.*--.*prefer_system" | grep -q .; then
  echo "FAIL [env.lua]: prefer_system must not exist — move to rules.lua"
  fail=1
fi

# ── Adapters must not call vim.notify (emitter layer owns side-effects) ───────
for f in "$LUA/runtime/adapters/"*.lua; do
  [ -f "$f" ] || continue
  if grep -n "vim\.notify" "$f" 2>/dev/null | grep -q .; then
    echo "FAIL [adapter side-effect]: $f contains vim.notify — use emitter layer"
    fail=1
  fi
done

# ── capability.lua must not have module-level _store ─────────────────────────
if grep -n "^local _store" "$LUA/core/domain/capability.lua" 2>/dev/null | grep -q .; then
  echo "FAIL [capability.lua]: module-level _store found — must be eliminated"
  fail=1
fi

# ── Phase.run must not call vim.notify (Invariant 2: pure function) ──────────
for f in "$LUA/runtime/passes/"*.lua; do
  [ -f "$f" ] || continue
  if grep -n "vim\.notify" "$f" 2>/dev/null | grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [phase purity]: $f calls vim.notify in Phase.run — use IR diagnostics"
    fail=1
  fi
done

# ── FIX-AUDIT-P1-7b: Phase.run must not call vim.api (INV-2 was incomplete) ──
for f in "$LUA/runtime/passes/"*.lua; do
  [ -f "$f" ] || continue
  if grep -n "vim\.api" "$f" 2>/dev/null | grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [phase vim.api]: $f uses vim.api — use ports.* abstraction"
    grep -n "vim\.api" "$f" | grep -v "^[0-9]*:[ \t]*--" | head -3 || true
    fail=1
  fi
done

# ── Phase.run must not call vim.tbl_extend / vim.deepcopy (use util.*) ───────
for f in "$LUA/runtime/passes/"*.lua; do
  [ -f "$f" ] || continue
  if grep -nE "vim\.tbl_extend|vim\.deepcopy|vim\.tbl_deep_extend|vim\.list_extend" "$f" 2>/dev/null |
    grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [phase purity]: $f uses vim table API — use util.merge/deep_merge/deep_copy"
    fail=1
  fi
done

# ── passes must not read vim.g (use ir.meta.build_request) ───────────────────
for f in "$LUA/runtime/passes/"*.lua; do
  [ -f "$f" ] || continue
  if grep -n "vim\.g" "$f" 2>/dev/null | grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [phase vim.g]: $f reads vim.g — inject via BuildRequest"
    fail=1
  fi
done

# ── FIX-AUDIT-P1-7c: require-time side effects in passes/ ───────────────────
# pipeline.lua is EXCLUDED (orchestrator; test suite needs require-time init).
for f in "$LUA/runtime/passes/"*.lua; do
  [ -f "$f" ] || continue
  if grep -nE '^[A-Za-z_].*\.register\(|^[A-Za-z_].*register_default' "$f" 2>/dev/null |
    grep -v "^[0-9]*:[ \t]*--" | grep -v "function" | grep -q .; then
    echo "FAIL [require-time side effect]: $f calls register() at module scope"
    echo "  → wrap in M.setup() function, call from runtime/init.lua"
    fail=1
  fi
done

# ── compiler must not call vim API directly (use ports.lua) ──────────────────
for f in $(find "$LUA/core/compiler" -name '*.lua' ! -name 'ports.lua' 2>/dev/null); do
  if grep -n "vim\." "$f" 2>/dev/null | grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [compiler vim]: $f uses vim API — inject via ports"
    fail=1
  fi
done

# ── toolchain must not call vim.g (Layer 3 boundary) ─────────────────────────
if grep -rn --include="*.lua" 'vim\.g' "$LUA/toolchain" 2>/dev/null |
  grep -v "^.*--.*vim\.g" | grep -q .; then
  echo "FAIL [toolchain vim.g]: toolchain/* must not read vim.g"
  fail=1
fi

# ── INV-11: only collect_ext may assign ext_caps ─────────────────────────────
for f in "$LUA/runtime/passes/"*.lua; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  [ "$base" = "collect_ext.lua" ] && continue
  if grep -nE '(^|[^a-z_])ext_caps[[:space:]]*=' "$f" 2>/dev/null |
    grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [INV-11]: $f assigns ext_caps — only collect_ext may write ext_caps"
    fail=1
  fi
done

# ── INV-13: cap adapters must not call vim API ────────────────────────────────
for f in "$LUA/runtime/adapters/image.lua" "$LUA/runtime/adapters/media.lua" \
  "$LUA/runtime/adapters/ai.lua" "$LUA/runtime/adapters/ai_cap.lua" \
  "$LUA/runtime/adapters/keybind.lua"; do
  [ -f "$f" ] || continue
  if grep -n "vim\." "$f" 2>/dev/null | grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [INV-13]: $f uses vim API — cap adapters must be pure"
    fail=1
  fi
done

# ── INV-15: conflict.lua must not mutate strategy registry ───────────────────
if grep -nE 'StrategyRegistry|strategy\.registry|registry\.register' "$LUA/toolchain/strategy/conflict.lua" 2>/dev/null |
  grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
  echo "FAIL [INV-15]: conflict.lua must not write strategy registry"
  fail=1
fi

# ── FIX-ROBUST-V2 (2026-06-23): Orphan file + convention detection ────────
# Warn if:
# 1. .lua files in runtime/adapters/ or runtime/passes/ not registered
# 2. .lua files in plugins/ that violate convention (helper without _ prefix)
# 3. .lua files in modules/cap|editor|ai|keybind without cap_type+version
echo "─── Orphan + convention detection (FIX-ROBUST-V2) ───"

# Check adapters: every runtime/adapters/*.lua (except registry/cap_registry)
# should be referenced in defaults/adapters.lua or defaults/cap_adapters.lua
for f in "$LUA/runtime/adapters/"*.lua; do
  [ -f "$f" ] || continue
  base="$(basename "$f" .lua)"
  # Skip registry files (not adapters themselves)
  [ "$base" = "registry" ] && continue
  [ "$base" = "cap_registry" ] && continue
  # Check if referenced in defaults
  if ! grep -q "adapters\.$base" "$LUA/runtime/defaults/adapters.lua" "$LUA/runtime/defaults/cap_adapters.lua" 2>/dev/null; then
    echo "WARN [orphan adapter]: $f not registered in defaults/adapters.lua or defaults/cap_adapters.lua"
  fi
done

# Check passes: every runtime/passes/*.lua should be in defaults/phases.lua
for f in "$LUA/runtime/passes/"*.lua; do
  [ -f "$f" ] || continue
  base="$(basename "$f" .lua)"
  if ! grep -q "passes\.$base" "$LUA/runtime/defaults/phases.lua" 2>/dev/null; then
    echo "WARN [orphan pass]: $f not registered in defaults/phases.lua"
  fi
done

# Check plugins convention: helper modules should have _ prefix
# Files that don't return a table with [1] as string/table are helpers.
# We can't easily check return type in bash, so we check for _ prefix convention.
for f in $(find "$LUA/plugins" -name '*.lua' ! -name 'init.lua' 2>/dev/null); do
  base="$(basename "$f" .lua)"
  # Files starting with _ are private (by convention) — OK
  if [ "${base:0:1}" != "_" ]; then
    # Check if file returns a table (has "return {" pattern)
    if ! grep -q 'return {' "$f" 2>/dev/null; then
      echo "WARN [convention]: $f does not return a table — if it's a helper, rename to _${base}.lua"
    fi
  fi
done

# Check cap modules convention: files in modules/cap|editor|ai|keybind should
# have cap_type and version fields (valid DSL).
for dir in cap editor ai keybind; do
  for f in "$LUA/modules/$dir/"*.lua; do
    [ -f "$f" ] || continue
    base="$(basename "$f" .lua)"
    # Skip _ prefix files
    [ "${base:0:1}" = "_" ] && continue
    # Check for cap_type field
    if ! grep -q 'cap_type' "$f" 2>/dev/null; then
      echo "WARN [convention]: $f missing cap_type — if it's a helper, rename to _${base}.lua"
    fi
  done
done

if [ $fail -eq 0 ]; then
  echo "Layer boundary check: PASSED"
else
  exit 1
fi