#!/usr/bin/env bash
set -u

GODOT_BIN="$1"
SCENE="$2"
FAIL_TOKEN="$3"
PASS_TOKEN="$4"
TIMEOUT_SECONDS="${GODOT_GATE_TIMEOUT_SECONDS:-180}"
LOG_FILE=$(mktemp)
trap 'rm -f "$LOG_FILE"' EXIT

set +e
set -o pipefail
timeout --signal=TERM --kill-after=10s "${TIMEOUT_SECONDS}s" \
  "$GODOT_BIN" --headless --path projeto_jornada "$SCENE" 2>&1 | tee "$LOG_FILE"
status=${PIPESTATUS[0]}
set +o pipefail
set -e

if grep -E "SCRIPT ERROR|Parse Error|${FAIL_TOKEN}" "$LOG_FILE"; then
  exit 1
fi

if [ "$status" -eq 124 ] || [ "$status" -eq 137 ]; then
  echo "Godot gate timed out after ${TIMEOUT_SECONDS}s before emitting its PASS token: ${SCENE}"
  exit 1
fi

if [ "$status" -ne 0 ]; then
  echo "Godot gate exited with status $status before emitting its PASS token: ${SCENE}"
  exit "$status"
fi

grep -Fq "$PASS_TOKEN" "$LOG_FILE"
