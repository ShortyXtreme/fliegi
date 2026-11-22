#!/usr/bin/env python3
"""M3.5: Extrahiert eingebettete Bilder aus .glb-Dateien so, wie Godot sie beim Editor-Import
ablegt (<glb-name>_<bild-name>.png neben der .glb). Damit greifen die versionierten
.png.import-Einstellungen (VRAM-komprimiert, size_limit) auch bei einem reinen Headless-Import.
Aufruf: python3 tools/extract_glb_images.py assets/ground/*.glb   (nur fehlende Dateien werden geschrieben)
"""
import json, os, struct, sys

def extract(path, force=False):
    with open(path, "rb") as f:
        data = f.read()
    magic, _ver, _len = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, path
    off, js, binchunk = 12, None, None
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A: js = json.loads(chunk)
        elif ctype == 0x004E4942: binchunk = chunk
        off += 8 + clen
    base = os.path.splitext(path)[0]
    n = 0
    for i, img in enumerate(js.get("images", [])):
        if "bufferView" not in img: continue
        bv = js["bufferViews"][img["bufferView"]]
        blob = binchunk[bv.get("byteOffset", 0): bv.get("byteOffset", 0) + bv["byteLength"]]
        name = img.get("name") or ("image_%d" % i)
        out = "%s_%s.png" % (base, name)
        if os.path.exists(out) and not force: continue
        with open(out, "wb") as f: f.write(blob)
        n += 1
    return n

if __name__ == "__main__":
    force = "--force" in sys.argv
    total = sum(extract(p, force) for p in sys.argv[1:] if p.endswith(".glb"))
    print("%d Bild(er) extrahiert." % total)
