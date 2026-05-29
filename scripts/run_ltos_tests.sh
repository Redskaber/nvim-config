#!/usr/bin/env bash
# scripts/run_ltos_tests.sh — targeted LTOS architecture tests (headless nvim)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "==> Layer boundary check"
bash "$ROOT/scripts/check_layer_boundaries.sh"

echo "==> Headless LTOS integration tests"
nvim --headless \
  -u NONE \
  --cmd "set rtp^=$ROOT" \
  "+luafile $ROOT/scripts/ltos_tests.lua" \
  +qa

echo "All LTOS tests passed."
