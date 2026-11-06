#!/usr/bin/env bash
# M2.2: Windows-Build (nur .pck, Flugkern.exe = unverändertes Godot-4.7.2-Template) mit
# Pflicht-Regressionstest: die exportierte .pck muss im Selbsttest Treffer in beide Richtungen
# erzeugen. Aufruf (aus game/): GODOT=/pfad/godot tools/build_windows.sh <zielordner>
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:?Zielordner fehlt}"
mkdir -p "$OUT"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-pack "Windows Desktop" "$OUT/Flugkern.pck"
FLUGKERN_PCK="$(realpath "$OUT/Flugkern.pck")" "$GODOT" --headless --path . \
	--script res://tests/test_runner.gd -- --suite=export
cp ../docs/build_readme.md "$OUT/README.md"
# M3.2: Startoption Tutorial (Doppelklick startet das geführte Tutorial)
printf '@echo off\r\nstart "" "%%~dp0Flugkern.exe" -- --tutorial\r\n' > "$OUT/Tutorial starten.bat"
ls -la "$OUT"
