#!/usr/bin/env python3
"""M3.13: Poly-Haven-Texturen und -Himmel (CC0) für Flugkern aufbereiten – wiederholbar.

Quelle (nicht im Repo): <quelle>/<name>_2k/textures/*  und  <quelle>/<hdri>_4k.hdr
Ziel:  game/assets/textures/polyhaven/  (versioniert, Godot importiert VRAM-komprimiert)

Kanal-Packung (2 Texturen je Material statt 4, Godot braucht wenig Speicher):
  *_col  RGB  Farbe (sRGB), Umgebungsverdeckung (AO) leicht eingerechnet  -> S3TC/BC1 (4 bit/px)
  *_nrm  RGBA R/G = Normale (OpenGL-Konvention wie Godot, Y nach oben), B = Rauheit,
              A = Höhe (Gelände, für Höhen-Überblendung) bzw. AO (Rinde, Bretter) -> BPTC/BC7 (8 bit/px)
Gelände: alle Ebenen als ein Texture2DArray (senkrechter Streifen, je Ebene quadratisch):
  gelaende_col_1k / gelaende_nrm_1k (Stufe Mittel), zusätzlich gelaende_col_2k (Stufe Hoch, nur die
  Nah-Ebenen TERRAIN_HI; die Normalen bleiben 1K, ein 2K-Normal-Array hätte ~39 MB > 30-MB-Paket).
Rinde/Bretter/Farbe: einzelne Texturen 1K.
Himmel: HDRI 4K -> 2K (2x2-Mittel), Sonne auf SUN_CLAMP begrenzt (das direkte Licht kommt von der
  DirectionalLight3D), als Radiance-.hdr (RGBE, RLE; ffmpegs EXR fehlt ein Header-Attribut, das Godot
  verlangt) -> Godot importiert als Panorama (BC6H).
Unbenutzt bleiben: .blend/.gltf/.bin, *_ao/_rough-Einzeldateien (stecken in *_arm), Metallizität.

Normalen-EXR liest ffmpeg (OpenEXR-Python ist hier nicht installierbar), Bilder Pillow + numpy.
Erzeugt außerdem polyhaven_meta.gd (Mittelfarben je Ebene, Sonnenlage des HDRI).

Aufruf (aus game/):  python3 tools/prep_polyhaven.py [<quelle>]
"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

SRC_DEFAULT = "/home/claude/flugzeug/asset_quellen/polyhaven"
GAME = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(GAME, "assets", "textures", "polyhaven")

# Gelände-Ebenen (Reihenfolge = Index im Texture2DArray, siehe terrain.gdshader L_*)
TERRAIN = [
    "aerial_grass_rock",       # 0 Wiese, Feldrand, Weide, gemähte Flächen
    "forest_ground_04",        # 1 Waldboden (Nadelstreu, Moos)
    "leaves_forest_ground",    # 2 Waldboden (Laub), Hecken
    "brown_mud_leaves_01",     # 3 Ufer, Schlamm, Böschung, Flussbett
    "rocks_ground_02",         # 4 Fels, Steilhang (triplanar)
    "coast_sand_rocks_02",     # 5 Sand/Kies am Ufer
    "dirt_floor",              # 6 offene Erde, Acker, Fahrwege, Abstellplätze, abgenutzte Grasbahnen
]
OBJECTS = {
    "bark_platanus": "rinde",                    # Baumstämme (tree.gdshader)
    "weathered_brown_planks": "bretter",         # Hallenwände/-tore, Schuppen, Zaun
    "wood_peeling_paint_weathered": "farbe",     # Flugleitung (gestrichenes Holzhaus)
}
# Stufe Hoch: 2K-Farben nur für die Ebenen, die man aus der Nähe sieht (Index im 1K-Array). Fels (triplanar,
# meist aus der Ferne) und Sand bleiben 1K – so bleibt das Kartenpaket mit Abstand unter 30 MB.
TERRAIN_HI = [0, 1, 2, 3, 6]
HDRIS = {"kloofendal_48d_partly_cloudy": "himmel_klar", "quarry_cloudy": "himmel_bedeckt"}
AO_IN_COLOR = 0.55     # Anteil der AO, der in die Farbe eingerechnet wird
SUN_CLAMP = 24.0       # max. Leuchtdichte im Himmel (HDRI-Sonne ~75.000)
LUMA = np.array([0.2126, 0.7152, 0.0722])


def find(d, name, keys):
    for k in keys:
        p = os.path.join(d, "%s_%s_2k.%s" % (name, k[0], k[1]))
        if os.path.exists(p):
            return p
    raise FileNotFoundError("%s: %s fehlt in %s" % (name, "/".join(k[0] for k in keys), d))


def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def load_rgb(p):
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.float32) / 255.0


def load_gray(p):
    im = Image.open(p)
    if im.mode in ("I;16", "I;16B", "I"):
        a = np.asarray(im, dtype=np.float32)
        return a / (65535.0 if a.max() > 255 else 255.0)
    return np.asarray(im.convert("L"), dtype=np.float32) / 255.0


def load_exr_rgb(p):
    """EXR -> float32 HxWx3 (über ffmpeg, Ebenen-Reihenfolge G, B, R)."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", p, "-f", "rawvideo", "-pix_fmt", "gbrpf32le", "-"],
                         capture_output=True, check=True).stdout
    a = np.frombuffer(raw, "<f4")
    h = int(round((a.size / 6) ** 0.5)) if p.endswith(".hdr") else int(round((a.size / 3) ** 0.5))
    w = a.size // 3 // h
    a = a.reshape(3, h, w)
    return np.stack([a[2], a[0], a[1]], -1)


def box_down(a, f):
    """Ganzzahlig verkleinern (Mittel über f×f) – erhält die Kachelbarkeit exakt."""
    if f == 1:
        return a
    h, w = a.shape[:2]
    return a.reshape(h // f, f, w // f, f, *a.shape[2:]).mean(axis=(1, 3))


def to_u8(a):
    return np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8)


def material(src, name, size, alpha="height"):
    """-> (col sRGB HxWx3, nrm HxWx4, Mittelfarbe linear) bei Kantenlänge size."""
    d = os.path.join(src, name + "_2k", "textures")
    col = load_rgb(find(d, name, [("diff", "jpg"), ("col", "jpg")]))
    arm = load_rgb(find(d, name, [("arm", "jpg")]))
    nor = load_exr_rgb(find(d, name, [("nor_gl", "exr")]))
    f = col.shape[0] // size
    ao, rough = arm[..., 0], arm[..., 1]
    if alpha == "height":
        h = load_gray(find(d, name, [("disp", "png"), ("height", "png")]))
        lo, hi = np.percentile(h, [1, 99])
        a = np.clip((h - lo) / max(hi - lo, 1e-4), 0, 1)
    else:
        a = ao
    # AO in die Farbe (linear multiplizieren), dann zurück nach sRGB
    lin = srgb_to_lin(col) * (1.0 - AO_IN_COLOR + AO_IN_COLOR * ao)[..., None]
    lin = box_down(lin, f)
    mean = lin.reshape(-1, 3).mean(0)
    col_s = np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(np.maximum(lin, 0), 1 / 2.4) - 0.055)
    n = box_down(nor[..., :2] * 2.0 - 1.0, f)
    n = np.clip(n * 0.5 + 0.5, 0, 1)
    nrm = np.concatenate([n, box_down(rough, f)[..., None], box_down(a, f)[..., None]], -1)
    return col_s, nrm, mean


def save_webp(a, path, lossless):
    im = Image.fromarray(to_u8(a), "RGBA" if a.shape[-1] == 4 else "RGB")
    if lossless:
        im.save(path, "WEBP", lossless=True, quality=80, method=4, exact=True)
    else:
        im.save(path, "WEBP", quality=92, method=6)
    return os.path.getsize(path)


IMPORT_TEX = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality={hq}
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=2
compress/channel_pack=0
mipmaps/generate={mip}
mipmaps/limit=-1
roughness/mode=0
process/fix_alpha_border=false
process/premult_alpha=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""

IMPORT_ARRAY = """[remap]

importer="2d_array_texture"
type="CompressedTexture2DArray"

[params]

compress/mode=2
compress/high_quality={hq}
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
slices/horizontal=1
slices/vertical={n}
"""


def write_import(path, text):
    # Nur anlegen, wenn neu: Godot ergänzt beim Import uid/Pfade, die bleiben dann erhalten.
    if not os.path.exists(path + ".import"):
        open(path + ".import", "w").write(text)


def sun_of(img):
    """Hellster Punkt des Panoramas -> Richtung in Godot (Panorama-u = atan2(x, -z)/2π, v = acos(y)/π)."""
    lum = img @ LUMA
    y, x = np.unravel_index(np.argmax(lum), lum.shape)
    h, w = lum.shape
    u, v = (x + 0.5) / w, (y + 0.5) / h
    phi, theta = u * 2 * np.pi, v * np.pi
    d = np.array([np.sin(phi) * np.sin(theta), np.cos(theta), -np.cos(phi) * np.sin(theta)])
    return d, 90.0 - v * 180.0, np.degrees(phi), float(lum.max())


def sky(src, name, out_name):
    img = load_exr_rgb(os.path.join(src, name + "_4k.hdr"))
    d, elev, az, peak = sun_of(img)
    img = box_down(img, 2)
    lum = img @ LUMA
    k = np.minimum(1.0, SUN_CLAMP / np.maximum(lum, 1e-6))
    img = img * k[..., None]
    h = img.shape[0]
    up = img[:h // 2].reshape(-1, 3)
    hz = img[int(h * 0.46):h // 2].reshape(-1, 3).mean(0)
    path = os.path.join(OUT, out_name + "_2k.hdr")
    g = np.ascontiguousarray(np.stack([img[..., 1], img[..., 2], img[..., 0]]).astype("<f4"))
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "gbrpf32le", "-s",
                    "%dx%d" % (img.shape[1], h), "-i", "-", "-c:v", "hdr", "-frames:v", "1", path], input=g.tobytes(), check=True)
    write_import(path, IMPORT_TEX.format(hq="true", mip="false"))
    print("  %-34s %8d Byte  Sonne Höhe %.1f° Azimut %.1f° (Spitze %.0f)" % (os.path.basename(path), os.path.getsize(path),
                                                                       elev, az, peak))
    return {"sun": d, "elev": elev, "az": az, "mean_up": up.mean(0), "horizon": hz}


def vec3(c):
    return "Vector3(%.5f, %.5f, %.5f)" % tuple(c)


def col3(c):
    return "Color(%.5f, %.5f, %.5f)" % tuple(c)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    src = args[0] if args else SRC_DEFAULT
    os.makedirs(OUT, exist_ok=True)
    means = []
    print("Gelände-Ebenen:")
    for size, tag in ((1024, "1k"), (2048, "2k")):
        cols, nrms = [], []
        for i, name in enumerate(TERRAIN):
            if size == 2048 and i not in TERRAIN_HI:
                continue
            c, n, m = material(src, name, size)
            cols.append(c)
            if size == 1024:
                nrms.append(n)
                means.append(m)
        p = os.path.join(OUT, "gelaende_col_%s.webp" % tag)
        s = save_webp(np.concatenate(cols, 0), p, False)
        write_import(p, IMPORT_ARRAY.format(hq="false", n=len(cols)))
        print("  %-34s %8d Byte" % (os.path.basename(p), s))
        if nrms:
            p = os.path.join(OUT, "gelaende_nrm_1k.webp")
            s = save_webp(np.concatenate(nrms, 0), p, True)
            write_import(p, IMPORT_ARRAY.format(hq="true", n=len(TERRAIN)))
            print("  %-34s %8d Byte" % (os.path.basename(p), s))
    obj_means = {}
    print("Rinde/Holz:")
    for name, short in OBJECTS.items():
        c, n, m = material(src, name, 1024, alpha="ao")
        obj_means[short] = m
        for kind, a, lossless, hq in (("col", c, False, "false"), ("nrm", n, True, "true")):
            p = os.path.join(OUT, "%s_%s_1k.webp" % (short, kind))
            s = save_webp(a, p, lossless)
            write_import(p, IMPORT_TEX.format(hq=hq, mip="true"))
            print("  %-34s %8d Byte" % (os.path.basename(p), s))
    print("Himmel:")
    skies = {short: sky(src, name, short) for name, short in HDRIS.items()}
    # Metadaten für die Shader/Skripte (generiert)
    L = ["# Erzeugt von tools/prep_polyhaven.py (M3.13) – nicht von Hand ändern.",
         "# Poly Haven, CC0 (docs/asset_lizenzen.md).", "extends RefCounted", "",
         "## Gelände-Ebenen (Index im Texture2DArray)",
         "const LAYERS := [%s]" % ", ".join('"%s"' % n for n in TERRAIN),
         "## Stufe Hoch: Index im 2K-Array je Ebene (-1 = nur 1K)",
         "const HI_INDEX := [%s]" % ", ".join(str(TERRAIN_HI.index(i) if i in TERRAIN_HI else -1) for i in range(len(TERRAIN))),
         "## Mittlere Farbe je Ebene (linear, nach AO) – der Shader nimmt Textur / Mittel als Detail",
         "const MEAN := [%s]" % ", ".join(col3(m) for m in means),
         "## Mittlere Farbe Rinde/Bretter/Farbe (linear)",
         "const OBJ_MEAN := {%s}" % ", ".join('"%s": %s' % (k, col3(v)) for k, v in obj_means.items())]
    for short, s in skies.items():
        L += ["## %s: Richtung zur Sonne (Godot-Panorama), Höhe/Azimut in Grad, Mittel oberer Halbraum, Horizont" % short,
              "const %s := {\"sun\": %s, \"elev\": %.2f, \"az\": %.2f, \"mean_up\": %s, \"horizon\": %s}" % (
                  short.upper(), vec3(s["sun"]), s["elev"], s["az"], col3(s["mean_up"]), col3(s["horizon"]))]
    open(os.path.join(OUT, "polyhaven_meta.gd"), "w").write("\n".join(L) + "\n")
    print("polyhaven_meta.gd geschrieben")


if __name__ == "__main__":
    main()
