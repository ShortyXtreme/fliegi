#!/usr/bin/env bash
# Startet alle Headless-Tests. Exit-Code 0 = alle grün.
# Optional: GODOT=/pfad/zu/godot ./tests/run_tests.sh [--only=takeoff]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# M3.5: Boden-Texturen aus den .glb extrahieren (siehe tools/build_windows.sh)
python3 tools/extract_glb_images.py assets/ground/*.glb >/dev/null || true
# Import (Klassen-Cache, Ressourcen) sicherstellen
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --fixed-fps 60 --script res://tests/test_runner.gd -- "$@"
