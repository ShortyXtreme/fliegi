#!/usr/bin/env bash
# Startet alle Headless-Tests. Exit-Code 0 = alle grün.
# Optional: GODOT=/pfad/zu/godot ./tests/run_tests.sh [--only=takeoff]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Import (Klassen-Cache, Ressourcen) sicherstellen
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --fixed-fps 60 --script res://tests/test_runner.gd -- "$@"
