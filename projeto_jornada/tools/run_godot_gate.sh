#!/usr/bin/env bash
set -u

GODOT_BIN="$1"
SCENE="$2"
FAIL_TOKEN="$3"
PASS_TOKEN="$4"

set +e
output=$("$GODOT_BIN" --headless --path projeto_jornada "$SCENE" 2>&1)
status=$?
set -e

printf '%s\n' "$output"

if printf '%s\n' "$output" | grep -E "SCRIPT ERROR|Parse Error|${FAIL_TOKEN}"; then
  exit 1
fi

if [ "$status" -ne 0 ]; then
  echo "Godot gate exited with status $status before emitting its PASS token."
  exit "$status"
fi

printf '%s\n' "$output" | grep -Fq "$PASS_TOKEN"
