#!/usr/bin/env bash
# scripts/check_layer_boundaries.sh
# LTOS v4 layer boundary violation detector.
#
# Checks that each layer only depends on layers below it.
# Exit code 0 = PASSED, non-zero = violations found.

set -euo pipefail

VIOLATIONS=0

check() {
  local label="$1"
  local pattern="$2"
  local dir="$3"

  if grep -r --include="*.lua" -l "$pattern" $dir 2>/dev/null | grep -q .; then
    echo "LAYER VIOLATION: $label"
    grep -r --include="*.lua" -n "$pattern" $dir 2>/dev/null | head -20
    VIOLATIONS=$((VIOLATIONS + 1))
  fi
}

# Layer 0 kernel must not import Layer 1+ modules
check \
  "kernel imports compiler/domain/toolchain/runtime" \
  'require.*"core\.compiler\|require.*"core\.domain\|require.*"toolchain\|require.*"runtime' \
  "lua/core/kernel/"

# Layer 1 compiler must not import Layer 2+ modules
check \
  "compiler imports domain/toolchain/runtime" \
  'require.*"core\.domain\|require.*"toolchain\|require.*"runtime' \
  "lua/core/compiler/"

# Layer 2 domain must not import Layer 3+ modules
check \
  "domain imports toolchain/runtime" \
  'require.*"toolchain\|require.*"runtime' \
  "lua/core/domain/"

# Layer 3 toolchain must not import Layer 4 adapters
check \
  "toolchain imports runtime.adapters" \
  'require.*"runtime\.adapters' \
  "lua/toolchain/"

# Layer 5 lang modules must not import runtime.pipeline
check \
  "lang modules import runtime.pipeline" \
  'require.*"runtime\.pipeline' \
  "lua/modules/"

# Layer 5 plugins must not import runtime.pipeline
check \
  "plugins import runtime.pipeline" \
  'require.*"runtime\.pipeline' \
  "lua/plugins/"

if [ "$VIOLATIONS" -eq 0 ]; then
  echo "Layer boundary check: PASSED"
  exit 0
else
  echo ""
  echo "Layer boundary check: FAILED ($VIOLATIONS violation(s) found)"
  exit 1
fi
