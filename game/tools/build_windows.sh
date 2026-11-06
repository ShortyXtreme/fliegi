#!/usr/bin/env bash
# M2.2: Windows-Build (nur .pck, Flugkern.exe = unverändertes Godot-4.7.2-Template) mit
# Pflicht-Regressionstest: die exportierte .pck muss im Selbsttest Treffer in beide Richtungen
# erzeugen. Aufruf (aus game/): GODOT=/pfad/godot tools/build_windows.sh <zielordner>
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:?Zielordner fehlt}"
mkdir -p "$OUT"
# M3.2: Die Boden-Texturen (assets/ground/*.png, gitignoriert) entstehen nur beim Import im Editor
# aus den .glb. Fehlen sie, bettet der Headless-Import sie unkomprimiert ein (pck > 40 MB).
n_png=$(ls assets/ground/*.png 2>/dev/null | wc -l); n_imp=$(ls assets/ground/*.png.import | wc -l)
if [ "$n_png" -lt "$n_imp" ]; then
	echo "FEHLER: assets/ground/*.png fehlen ($n_png von $n_imp) – Projekt einmal im Editor öffnen" \
		"oder aus einem Checkout mit Editor-Import kopieren." >&2
	exit 1
fi
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-pack "Windows Desktop" "$OUT/Flugkern.pck"
FLUGKERN_PCK="$(realpath "$OUT/Flugkern.pck")" "$GODOT" --headless --path . \
	--script res://tests/test_runner.gd -- --suite=export
cp ../docs/build_readme.md "$OUT/README.md"
# M3.2: Startoption Tutorial (Doppelklick startet das geführte Tutorial)
printf '@echo off\r\nstart "" "%%~dp0Flugkern.exe" -- --tutorial\r\n' > "$OUT/Tutorial starten.bat"
ls -la "$OUT"
