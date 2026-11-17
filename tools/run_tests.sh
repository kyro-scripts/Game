#!/usr/bin/env bash
# Validate every script/scene and run the gameplay test suite headlessly.
#
#   tools/run_tests.sh [path/to/godot]      (or set $GODOT)
#
# Exit code is non-zero if anything fails to load or any check fails.
set -euo pipefail
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."

echo "== import (refreshes class cache) =="
"$GODOT" --headless --path . --import

echo "== validate project =="
"$GODOT" --headless --path . --script res://tools/validate_project.gd

echo "== gameplay tests =="
"$GODOT" --headless --path . --fixed-fps 60 res://tests/test_runner.tscn

echo "== smoke: main scene for 10 simulated seconds =="
"$GODOT" --headless --path . --fixed-fps 60 --quit-after 600 res://scenes/main/main.tscn
