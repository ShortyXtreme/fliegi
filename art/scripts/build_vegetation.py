# -*- coding: utf-8 -*-
"""
M3.7 Vegetation (Stil B, spaete 1930er): Laub- und Nadelbaeume, Busch – je drei Detailstufen.
Eigene Designs, rein prozedural (bmesh), keine Texturen: Farbe steckt in den Vertexfarben
(linear, Rinde/Laub, dunkler nach innen/unten als Ersatz-AO), Laub-Normalen zeigen von der
Kronenmitte weg (weiche, "flauschige" Beleuchtung).

Aufruf:  blender -b -P art/scripts/build_vegetation.py
Ergebnis: art/models/ground/vegetation.glb (+ Kopie game/assets/ground/vegetation.glb)

Objekte (Godot: Y oben, Ursprung = Stammfuss): <art>_<lod>, art in
  laub_a (Eiche/Linde, runde Krone, ~13 m), laub_b (Pappel, saeulenfoermig, ~19 m),
  nadel_a (Fichte, ~17 m), nadel_b (Kiefer, hoher Stamm, flache Krone, ~16 m), busch (~2,2 m)
lod 0 = nah (< ~120 m), 1 = mittel, 2 = fern (wenige Dreiecke).
"""
import bpy, bmesh, math, os, random, shutil
from mathutils import Vector, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "art", "models", "ground", "vegetation.glb")
GAME = os.path.join(ROOT, "game", "assets", "ground", "vegetation.glb")

BARK = (0.060, 0.050, 0.040)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


class Part:
    """Sammelt Geometrie (bmesh) mit Vertexfarben und eigenen Normalen."""

    def __init__(self):
        self.bm = bmesh.new()
        self.col = {}     # vert -> Farbe
        self.nrm = {}     # vert -> Normale

    def add_verts(self, verts, colors, normals=None):
        for i, v in enumerate(verts):
            self.col[v] = colors[i] if isinstance(colors, list) else colors
            if normals is not None:
                self.nrm[v] = normals[i]


def trunk(p, base, top, r0, r1, seg):
    bm = p.bm
    ring0, ring1 = [], []
    d = (top - base).normalized()
    side = d.orthogonal().normalized()
    side2 = d.cross(side)
    for k in range(seg):
        a = 2 * math.pi * k / seg
        o = side * math.cos(a) + side2 * math.sin(a)
        ring0.append(bm.verts.new(base + o * r0))
        ring1.append(bm.verts.new(top + o * r1))
    for k in range(seg):
        bm.faces.new((ring0[k], ring0[(k + 1) % seg], ring1[(k + 1) % seg], ring1[k]))
    tip = bm.verts.new(top + d * r1)
    for k in range(seg):
        bm.faces.new((ring1[k], ring1[(k + 1) % seg], tip))
    vs = ring0 + ring1 + [tip]
    cols = []
    for v in vs:
        f = 0.75 + 0.25 * random.random()
        cols.append((BARK[0] * f, BARK[1] * f, BARK[2] * f))
    nrm = [((v.co - base) - d * (v.co - base).dot(d)).normalized() if v is not tip else d for v in vs]
    p.add_verts(vs, cols, nrm)


def blob(p, center, radius, subdiv, color, crown_c, crown_lo, crown_hi, squash=1.0, rough=0.28, seed=0):
    bm = p.bm
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=subdiv + 1, radius=1.0)   # 1 = Ikosaeder (20)
    vmap = {}
    for v in tmp.verts:
        n = v.co.normalized()
        q = n * 1.7 + Vector((seed * 3.1, seed * 1.7, seed * 2.3))
        r = radius * (1.0 + rough * noise.noise(q) + rough * 0.5 * noise.noise(q * 2.3))
        co = center + Vector((n.x * r, n.y * r, n.z * r * squash))
        vmap[v] = bm.verts.new(co)
    for f in tmp.faces:
        bm.faces.new([vmap[v] for v in f.verts])
    tmp.free()
    vs = list(vmap.values())
    cols, nrm = [], []
    for v in vs:
        h = min(max((v.co.z - crown_lo) / max(crown_hi - crown_lo, 0.1), 0.0), 1.0)
        out = (v.co - crown_c)
        outward = min(out.length / max(radius * 2.2, 0.1), 1.0)
        ao = 0.45 + 0.35 * h + 0.25 * outward
        j = 0.9 + 0.2 * random.random()
        cols.append((color[0] * ao * j, color[1] * ao * j, color[2] * ao * j))
        geo = (v.co - center).normalized()
        nrm.append((geo * 0.35 + out.normalized() * 0.65).normalized())
    p.add_verts(vs, cols, nrm)


def cone(p, base, height, radius, seg, color, crown_c, jag=0.25, droop=0.25):
    """Fichten-Etage: gezackter Kegel mit hängendem Rand."""
    bm = p.bm
    ring = []
    for k in range(seg * 2):
        a = math.pi * k / seg + random.uniform(-0.08, 0.08)
        r = radius * (1.0 if k % 2 == 0 else 1.0 - jag) * random.uniform(0.9, 1.08)
        ring.append(bm.verts.new(base + Vector((math.cos(a) * r, math.sin(a) * r, -droop * (1.0 if k % 2 == 0 else 0.4)))))
    tip = bm.verts.new(base + Vector((random.uniform(-0.1, 0.1), random.uniform(-0.1, 0.1), height)))
    hub = bm.verts.new(base + Vector((0, 0, height * 0.12)))
    n = len(ring)
    for k in range(n):
        bm.faces.new((ring[k], ring[(k + 1) % n], tip))
        bm.faces.new((ring[(k + 1) % n], ring[k], hub))
    vs = ring + [tip, hub]
    cols, nrm = [], []
    for v in vs:
        tipish = 1.0 if v is tip else 0.0
        ao = 0.55 + 0.35 * tipish + 0.2 * random.random()
        if v is hub:
            ao = 0.3
        cols.append((color[0] * ao, color[1] * ao, color[2] * ao))
        out = v.co - crown_c
        out.z *= 0.5
        nrm.append((out.normalized() * 0.7 + Vector((0, 0, 0.5))).normalized())
    p.add_verts(vs, cols, nrm)


def finish(p, name):
    me = bpy.data.meshes.new(name)
    p.bm.verts.index_update()
    p.bm.to_mesh(me)
    order = list(p.bm.verts)
    ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'POINT')
    for i, v in enumerate(order):
        c = p.col.get(v, (0.1, 0.1, 0.1))
        ca.data[i].color = (c[0], c[1], c[2], 1.0)
    me.color_attributes.active_color = ca
    me.attributes.render_color_index = 0
    normals = [tuple(p.nrm.get(v, v.normal)) for v in order]
    me.normals_split_custom_set_from_vertices(normals)
    p.bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    tris = sum(len(poly.vertices) - 2 for poly in me.polygons)
    print("  %-10s %5d Dreiecke" % (name, tris))
    return ob


# --- Arten -----------------------------------------------------------------------------------

LEAF_A = (0.030, 0.062, 0.016)
LEAF_B = (0.040, 0.075, 0.020)
NEEDLE = (0.016, 0.040, 0.020)
PINE = (0.026, 0.052, 0.022)
BUSH = (0.034, 0.066, 0.018)


def laub_a(lod):
    random.seed(11)
    p = Part()
    h_trunk = 4.5
    trunk(p, Vector((0, 0, -0.3)), Vector((0.2, 0.1, h_trunk + 3.0)), 0.42, 0.18, [8, 6, 4][lod])
    if lod == 0:   # Hauptäste
        for a in (0.3, 2.4, 4.3):
            trunk(p, Vector((0.1, 0.05, h_trunk)), Vector((math.cos(a) * 2.6, math.sin(a) * 2.6, h_trunk + 3.2)), 0.16, 0.07, 5)
    cc = Vector((0.2, 0.1, h_trunk + 4.6))
    lo, hi = h_trunk + 1.2, h_trunk + 8.8
    if lod == 0:
        blobs = [((0, 0, 1.6), 2.9), ((2.0, 0.5, 0.0), 2.4), ((-1.8, 1.1, 0.2), 2.3), ((0.4, -2.0, 0.3), 2.3),
                 ((-0.8, -0.9, 2.9), 1.9), ((1.2, 1.6, 2.4), 1.8), ((-1.0, 2.2, -1.0), 1.6), ((1.6, -1.4, -1.0), 1.7)]
        for i, (o, r) in enumerate(blobs):
            blob(p, cc + Vector(o), r, 2, LEAF_A, cc, lo, hi, 0.85, seed=i)
    elif lod == 1:
        for i, (o, r) in enumerate([((0, 0, 1.2), 3.3), ((1.7, 0.6, -0.4), 2.6), ((-1.5, -0.8, -0.2), 2.6)]):
            blob(p, cc + Vector(o), r, 1, LEAF_A, cc, lo, hi, 0.85, rough=0.2, seed=i)
    else:
        blob(p, cc + Vector((0, 0, 0.4)), 4.1, 0, LEAF_A, cc, lo, hi, 0.8, rough=0.12)
    return p


def laub_b(lod):
    random.seed(12)
    p = Part()
    trunk(p, Vector((0, 0, -0.3)), Vector((0, 0, 15.0)), 0.36, 0.12, [7, 5, 4][lod])
    cc = Vector((0, 0, 10.5))
    lo, hi = 3.5, 19.0
    if lod == 0:
        for i in range(9):
            z = 4.8 + i * 1.6
            r = 1.75 * math.sin(math.pi * (0.12 + 0.82 * i / 8.0)) + 0.6
            o = Vector((random.uniform(-0.35, 0.35), random.uniform(-0.35, 0.35), z))
            blob(p, o, r, 2 if i % 2 == 0 else 1, LEAF_B, cc, lo, hi, 1.25, rough=0.3, seed=i + 20)
    elif lod == 1:
        for i in range(4):
            z = 6.0 + i * 3.4
            r = 1.9 * math.sin(math.pi * (0.15 + 0.75 * i / 3.0)) + 0.6
            blob(p, Vector((0, 0, z)), r, 1, LEAF_B, cc, lo, hi, 1.6, rough=0.2, seed=i + 20)
    else:
        blob(p, Vector((0, 0, 11.0)), 2.3, 0, LEAF_B, cc, lo, hi, 3.4, rough=0.1)
    return p


def nadel_a(lod):
    random.seed(13)
    p = Part()
    trunk(p, Vector((0, 0, -0.3)), Vector((0, 0, 16.5)), 0.34, 0.06, [6, 5, 3][lod])
    cc = Vector((0, 0, 8.0))
    n = [8, 4, 1][lod]
    if lod == 2:
        cone(p, Vector((0, 0, 1.6)), 15.5, 3.0, 4, NEEDLE, cc, jag=0.0, droop=0.0)
        return p
    for i in range(n):
        t = i / max(n - 1, 1)
        z = 1.6 + t * 12.0
        r = 3.2 * (1.0 - t) + 0.5
        cone(p, Vector((0, 0, z)), 4.8 - 2.0 * t if lod == 0 else 6.5 - 2.5 * t, r, [9, 6][lod], NEEDLE, cc,
             jag=0.3 if lod == 0 else 0.15, droop=0.5 * (1.0 - t))
    return p


def nadel_b(lod):
    random.seed(14)
    p = Part()
    trunk(p, Vector((0, 0, -0.3)), Vector((0.3, 0.0, 12.5)), 0.33, 0.14, [7, 5, 3][lod])
    cc = Vector((0.4, 0.0, 13.0))
    lo, hi = 10.0, 16.5
    bark2 = (0.095, 0.060, 0.040)   # rötliche Kiefernrinde oben
    if lod == 0:
        trunk(p, Vector((0.3, 0, 10.0)), Vector((2.0, 0.6, 12.6)), 0.12, 0.05, 4)
        trunk(p, Vector((0.3, 0, 10.8)), Vector((-1.4, -1.0, 13.0)), 0.11, 0.05, 4)
        for i, (o, r) in enumerate([((0, 0, 0.8), 2.4), ((1.9, 0.7, -0.2), 1.8), ((-1.6, -0.9, 0.0), 1.8),
                                    ((0.5, -1.6, -0.3), 1.6), ((-0.6, 1.5, 0.3), 1.6)]):
            blob(p, cc + Vector(o), r, 2 if i == 0 else 1, PINE, cc, lo, hi, 0.55, rough=0.35, seed=i + 40)
    elif lod == 1:
        for i, (o, r) in enumerate([((0, 0, 0.5), 2.8), ((1.6, 0.4, -0.2), 2.0), ((-1.5, -0.6, 0.0), 2.0)]):
            blob(p, cc + Vector(o), r, 1, PINE, cc, lo, hi, 0.55, rough=0.2, seed=i + 40)
    else:
        blob(p, cc + Vector((0, 0, 0.3)), 3.2, 0, PINE, cc, lo, hi, 0.5, rough=0.1)
    # obere Rinde etwas rötlicher
    for v, c in list(p.col.items()):
        if c[1] < c[0] and v.co.z > 6.0:   # nur Rinde (rot > gruen)
            p.col[v] = bark2
    return p


def busch(lod):
    random.seed(15)
    p = Part()
    cc = Vector((0, 0, 1.0))
    if lod == 0:
        for i, (o, r) in enumerate([((0, 0, 1.0), 1.2), ((0.9, 0.3, 0.7), 0.95), ((-0.8, 0.5, 0.75), 0.9),
                                    ((0.2, -0.9, 0.7), 0.9), ((-0.3, -0.2, 1.6), 0.8)]):
            blob(p, Vector(o), r, 1, BUSH, cc, 0.0, 2.3, 0.85, rough=0.3, seed=i + 60)
    elif lod == 1:
        blob(p, Vector((0, 0, 0.95)), 1.5, 1, BUSH, cc, 0.0, 2.3, 0.8, rough=0.25, seed=60)
    else:
        blob(p, Vector((0, 0, 0.9)), 1.5, 0, BUSH, cc, 0.0, 2.3, 0.75, rough=0.1, seed=60)
    return p


def main():
    reset()
    print("Vegetation:")
    for name, fn in [("laub_a", laub_a), ("laub_b", laub_b), ("nadel_a", nadel_a), ("nadel_b", nadel_b), ("busch", busch)]:
        for lod in range(3):
            finish(fn(lod), "%s_%d" % (name, lod))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_yup=True, export_apply=True,
                              export_vertex_color='ACTIVE', export_normals=True, export_materials='NONE')
    shutil.copyfile(OUT, GAME)
    print("geschrieben:", OUT, os.path.getsize(OUT), "Byte")


main()
