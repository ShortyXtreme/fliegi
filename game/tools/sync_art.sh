#!/usr/bin/env bash
# Kopiert fertige Modelle aus dem Grafik-Ordner ins Spielprojekt (nur lesend auf art/).
# Danach einmal importieren, damit Godot die .glb als Szene kennt.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${ART_DIR:-../art/models}"
DST="vehicles/aircraft/models"
mkdir -p "$DST"
shopt -s nullglob
n=0
for f in "$SRC"/*.glb; do
  cp -v "$f" "$DST/"
  n=$((n+1))
done
echo "$n Modell(e) übernommen."
if [ "$n" -gt 0 ]; then "${GODOT:-godot}" --headless --path . --import >/dev/null 2>&1 || true; fi
