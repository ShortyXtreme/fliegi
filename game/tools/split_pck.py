#!/usr/bin/env python3
"""M3.3: Exportierte Gesamt-.pck in Ressourcen-Pakete aufteilen (je <= 30 000 000 Byte).
  Flugkern.pck         Code, Szenen, UI, Schriften, Daten (+ project.binary, Caches)
  Flugkern_modelle.pck Flugzeug-/Boden-Modelle und Texturen
  Flugkern_karte.pck   Geländedaten/-texturen (world/terrain, ohne Skripte)
  Flugkern_audio.pck   alle Klänge (assets/audio)
Die Einträge werden gelesen (Python, Verzeichnis der .pck), in einen Arbeitsordner entpackt und
mit Godots PCKPacker (tools/split_pck.gd) neu gepackt -> Format passt immer zur Engine.
Aufruf (aus game/): python3 tools/split_pck.py <gesamt.pck> <zielordner> <version> <godot>"""
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile

LIMIT = 30_000_000
PACKS = {"main": "Flugkern.pck", "modelle": "Flugkern_modelle.pck", "karte": "Flugkern_karte.pck",
         "audio": "Flugkern_audio.pck"}
SCRIPT_EXT = (".gd", ".gdc", ".remap", ".uid")


def read_pck(path):
    d = open(path, "rb").read()
    assert d[:4] == b"GDPC", "keine .pck"
    ver, = struct.unpack_from("<I", d, 4)
    flags, = struct.unpack_from("<I", d, 20)
    file_base, dir_off = struct.unpack_from("<QQ", d, 24)
    assert ver >= 3 and flags & 2 and not flags & 1, "unerwartetes .pck-Format v%d Flags %d" % (ver, flags)
    n, = struct.unpack_from("<I", d, dir_off)
    p = dir_off + 4
    out = []
    for _ in range(n):
        ln, = struct.unpack_from("<I", d, p)
        p += 4
        name = d[p:p + ln].rstrip(b"\0").decode()
        p += ln
        off, size = struct.unpack_from("<QQ", d, p)
        p += 32 + 4
        out.append((name[6:] if name.startswith("res://") else name, d[file_base + off:file_base + off + size]))
    return out


def classify(src):
    if src.endswith(SCRIPT_EXT):
        return "main"
    if src.startswith("assets/audio/"):
        return "audio"
    if src.startswith("world/terrain/"):
        return "karte"
    if src.startswith(("vehicles/aircraft/models/", "assets/ground/", "characters/crew/anim/")) \
            and not src.endswith((".tscn", ".tres")):
        return "modelle"
    return "main"


def main():
    full, out, version, godot = sys.argv[1:5]
    entries = read_pck(full)
    # importierte Datei -> Quelle (über die .import-Remaps)
    src_of = {}
    for name, data in entries:
        if name.endswith(".import"):
            for line in data.decode(errors="ignore").splitlines():
                if line.startswith("path") and ".godot/imported/" in line:
                    src_of[line.split('"')[1].replace("res://", "")] = name[:-7]
    work = tempfile.mkdtemp(prefix="flugkern_split_")
    manifest = {k: [] for k in PACKS}
    for name, data in entries:
        src = src_of.get(name, name[:-7] if name.endswith(".import") else name)
        kind = classify(src)
        dst = os.path.join(work, "files", name)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        open(dst, "wb").write(data)
        manifest[kind].append(["res://" + name, dst])
    for kind in ("modelle", "karte", "audio"):
        info = os.path.join(work, "files", "pack_info", kind + ".txt")
        os.makedirs(os.path.dirname(info), exist_ok=True)
        open(info, "w").write(version + "\n")
        manifest[kind].append(["res://pack_info/%s.txt" % kind, info])
    jobs = {os.path.join(os.path.abspath(out), PACKS[k]): v for k, v in manifest.items()}
    mf = os.path.join(work, "manifest.json")
    json.dump(jobs, open(mf, "w"))
    game = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    subprocess.run([godot, "--headless", "--path", game, "--script", "res://tools/split_pck.gd", "--", mf], check=True,
                   stdout=subprocess.DEVNULL)
    shutil.rmtree(work)
    ok = True
    for path, files in jobs.items():
        size = os.path.getsize(path)
        ok = ok and size <= LIMIT
        print("%-22s %3d Dateien %10d Byte %s" % (os.path.basename(path), len(files), size, "OK" if size <= LIMIT else "ZU GROSS"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
