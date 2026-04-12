#!/usr/bin/env bash
# scripts/check_layer_boundaries.sh
# REFACTOR: added check for env.prefer_system removal

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

# Original boundary checks
check "$LUA/core/kernel" 'require.*core.compiler' "kernel→compiler"
check "$LUA/core/compiler" 'require.*core.domain' "compiler→domain"
check "$LUA/core/domain" 'require.*toolchain' "domain→toolchain"
check "$LUA/toolchain" 'require.*runtime.adapters' "strategy→adapters"
check "$LUA/modules" 'require.*runtime.pipeline' "app→pipeline"

# New: env.lua must not contain prefer_system
if grep -n "prefer_system" "$LUA/core/kernel/env.lua" 2>/dev/null | grep -v "^.*--.*prefer_system" | grep -q .; then
  echo "FAIL [env.lua must not contain prefer_system — move to rules.lua]"
  fail=1
fi

# New: adapters must not call vim.notify directly
for f in "$LUA/runtime/adapters/"*.lua; do
  if grep -n "vim\.notify" "$f" 2>/dev/null | grep -q .; then
    echo "FAIL [adapter side-effect]: $f contains vim.notify — use emitter layer"
    fail=1
  fi
done

# New: capability.lua must not have module-level _store
if grep -n "^local _store" "$LUA/core/domain/capability.lua" 2>/dev/null | grep -q .; then
  echo "FAIL [capability.lua]: module-level _store found — must be eliminated"
  fail=1
fi

if [ $fail -eq 0 ]; then
  echo "Layer boundary check: PASSED"
else
  exit 1
fi
