#!/usr/bin/env bash
# path: scripts/run_ltos_tests.sh
# LTOS unified test runner shell entry point.
#
# Usage:
#   bash scripts/run_ltos_tests.sh                       # all tests
#   bash scripts/run_ltos_tests.sh --suite core          # one group
#   bash scripts/run_ltos_tests.sh --suite runtime
#   bash scripts/run_ltos_tests.sh --suite modules
#   bash scripts/run_ltos_tests.sh --suite toolchain
#   bash scripts/run_ltos_tests.sh --suite integration
#   bash scripts/run_ltos_tests.sh --tags unit           # by tag
#   bash scripts/run_ltos_tests.sh --tags integration
#   bash scripts/run_ltos_tests.sh --fail-fast
#   bash scripts/run_ltos_tests.sh --quiet
#   bash scripts/run_ltos_tests.sh --list
#   bash scripts/run_ltos_tests.sh --skip-boundary
#
# Environment:
#   LTOS_SKIP_CHECK=1   skip check_layer_boundaries.sh

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

SKIP_BOUNDARY="${LTOS_SKIP_CHECK:-0}"
LUA_ARGS=()

for arg in "$@"; do
  case "$arg" in
  --skip-boundary) SKIP_BOUNDARY=1 ;;
  *) LUA_ARGS+=("$arg") ;;
  esac
done

# Layer boundary static check
if [ "$SKIP_BOUNDARY" = "0" ] && [ -f "$ROOT/scripts/check_layer_boundaries.sh" ]; then
  echo "==> Layer boundary check"
  bash "$ROOT/scripts/check_layer_boundaries.sh"
  echo ""
fi

echo "==> LTOS headless spec run"

# Pass CLI args to ltos_tests.lua via _G.arg table.
# We set _G.arg before luafile so parse_args() can read it.
if [ ${#LUA_ARGS[@]} -gt 0 ]; then
  # Build the Lua snippet that populates _G.arg
  LUA_ARG_SNIPPET="_G.arg={"
  for arg in "${LUA_ARGS[@]}"; do
    # Escape single quotes in arg value
    escaped="${arg//\'/\'}"
    LUA_ARG_SNIPPET+="'${escaped}',"
  done
  LUA_ARG_SNIPPET+="}"

  nvim --headless \
    -u NONE \
    --cmd "set rtp^=$ROOT" \
    "+lua $LUA_ARG_SNIPPET" \
    "+luafile $ROOT/scripts/ltos_tests.lua" \
    +qa
else
  nvim --headless \
    -u NONE \
    --cmd "set rtp^=$ROOT" \
    "+luafile $ROOT/scripts/ltos_tests.lua" \
    +qa
fi

echo ""
echo "==> All LTOS tests passed."