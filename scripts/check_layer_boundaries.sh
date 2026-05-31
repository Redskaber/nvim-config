#!/usr/bin/env bash
# scripts/check_layer_boundaries.sh
# Checks: layer dependency direction, env.prefer_system removal,
#         adapter side-effect isolation, capability.lua purity,
#         Phase.run vim API usage (Invariant 2).

set -euo pipefail
LUA=lua/

fail=0

check() {
  local src="$1" forbidden="$2" label="$3"
  if grep -rn --include="*.lua" "$forbidden" "$src" 2>/dev/null | grep -v "^Binary" | grep -q .; then
    echo "FAIL [$label]: $(grep -rn --include='*.lua' "$forbidden" "$src" | head -5)"
    fail=1
  fi
}

# ── Layer dependency direction ────────────────────────────────────────────────
check "$LUA/core/kernel" 'require.*core\.compiler' "kernel→compiler"
check "$LUA/core/compiler" 'require.*core\.domain' "compiler→domain"
check "$LUA/core/domain" 'require.*toolchain' "domain→toolchain"
check "$LUA/toolchain" 'require.*runtime\.adapters' "strategy→adapters"
check "$LUA/modules" 'require.*runtime\.pipeline' "app→pipeline"
check "$LUA/modules" 'require.*runtime\.adapters' "app→adapters"
check "$LUA/config" 'require.*runtime\.adapters' "config→adapters"
check "$LUA/config" 'require.*runtime\.pipeline' "config→pipeline"
# TODO-8.2: modules/* and config/* must not require runtime/adapters (belt-and-suspenders)
check "$LUA/plugins" 'require.*runtime\.adapters' "plugins→adapters"
check "$LUA/plugins" 'require.*runtime\.pipeline' "plugins→pipeline"

# ── env.lua must not contain prefer_system ────────────────────────────────────
if grep -n "prefer_system" "$LUA/core/kernel/env.lua" 2>/dev/null |
  grep -v "^.*--.*prefer_system" | grep -q .; then
  echo "FAIL [env.lua]: prefer_system must not exist — move to rules.lua"
  fail=1
fi

# ── Adapters must not call vim.notify (emitter layer owns side-effects) ───────
for f in "$LUA/runtime/adapters/"*.lua; do
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
# Exclude comment lines (lines where the first non-space chars are --)
for f in "$LUA/runtime/passes/"*.lua; do
  if grep -n "vim\.notify" "$f" 2>/dev/null | grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [phase purity]: $f calls vim.notify in Phase.run — use IR diagnostics"
    fail=1
  fi
done

# ── Phase.run must not call vim.tbl_extend / vim.deepcopy (use util.*) ───────
for f in "$LUA/runtime/passes/"*.lua; do
  if grep -n "vim\.tbl_extend\|vim\.deepcopy\|vim\.tbl_deep_extend\|vim\.list_extend" "$f" 2>/dev/null |
    grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [phase purity]: $f uses vim table API — use util.merge/deep_merge/deep_copy"
    fail=1
  fi
done

# ── passes must not read vim.g (use ir.meta.build_request) ───────────────────
for f in "$LUA/runtime/passes/"*.lua; do
  if grep -n "vim\.g" "$f" 2>/dev/null | grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [phase vim.g]: $f reads vim.g — inject via BuildRequest"
    fail=1
  fi
done

# ── compiler must not call vim API directly (use core/compiler/ports.lua) ─────
for f in $(find "$LUA/core/compiler" -name '*.lua' ! -name 'ports.lua'); do
  if grep -n "vim\." "$f" 2>/dev/null | grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [compiler vim]: $f uses vim API — inject via ports"
    grep -n "vim\." "$f" | grep -v "^[0-9]*:[ \t]*--" | head -3
    fail=1
  fi
done

# ── toolchain must not call vim.g (Layer 3 boundary) ─────────────────────────
if grep -rn --include="*.lua" 'vim\.g' "$LUA/toolchain" 2>/dev/null |
  grep -v "^.*--.*vim\.g" | grep -q .; then
  echo "FAIL [toolchain vim.g]: toolchain/* must not read vim.g — inject via Layer 4/5"
  grep -rn --include="*.lua" 'vim\.g' "$LUA/toolchain" | grep -v "^.*--" | head -5
  fail=1
fi

# ── INV-11: only collect_ext may assign ext_caps ─────────────────────────────
for f in "$LUA/runtime/passes/"*.lua; do
  base="$(basename "$f")"
  if [ "$base" = "collect_ext.lua" ]; then
    continue
  fi
  if grep -nE '(^|[^a-z_])ext_caps[[:space:]]*=' "$f" 2>/dev/null | grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
    echo "FAIL [INV-11]: $f assigns ext_caps — only collect_ext may write ext_caps"
    fail=1
  fi
done

# ── INV-13: cap adapters must not call vim API ────────────────────────────────
for f in "$LUA/runtime/adapters/image.lua" "$LUA/runtime/adapters/media.lua" \
  "$LUA/runtime/adapters/ai.lua" "$LUA/runtime/adapters/ai_cap.lua" \
  "$LUA/runtime/adapters/keybind.lua"; do
  if [ -f "$f" ] && grep -n "vim\." "$f" 2>/dev/null | grep -v "^[0-9]*:[ \t]*--" | grep -q .; then
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

if [ $fail -eq 0 ]; then
  echo "Layer boundary check: PASSED"
else
  exit 1
fi
