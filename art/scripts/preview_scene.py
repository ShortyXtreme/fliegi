# -*- coding: utf-8 -*-
"""
Vorschau-Szene fuer den Grafikstil (Blender 4.2+/5.x, headless, Cycles CPU).

Aufruf:
  blender -b -P preview_scene.py -- --shot A --samples 64 --out /pfad/bild.png
  blender -b -P preview_scene.py -- --export-glb /pfad/fighter_t1.glb

Shots:
  A  stil_A_sauber    : saubere, gesaettigte Farbflaechen + Freestyle-Kanten
  B  stil_B_ziel      : PBR, Abnutzung/Schmutz, Abendlicht
  C  stil_C_luftkampf : Flug ueber Landschaft/Wolken (Stil B)
  D  stil_D_boden     : Bodenbetrieb vor Hangar (Stil B)

Konventionen Flugzeug: Meter, Blender Z-up, Nase zeigt nach -Y
(=> glTF/Godot: +Z ist "Model Front"), Spannweite entlang X.
Generisches Eigendesign, keine realen Hoheitszeichen.
"""
import bpy, bmesh, math, sys, time, random
import numpy as np
from mathutils import Vector, Matrix, Euler

# ----------------------------------------------------------------------------
# Argumente
# ----------------------------------------------------------------------------
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ARGS = {"shot": "B", "samples": 64, "out": None, "export_glb": None, "res": 100}
i = 0
while i < len(argv):
    a = argv[i]
    if a == "--shot": ARGS["shot"] = argv[i + 1].upper(); i += 2
    elif a == "--samples": ARGS["samples"] = int(argv[i + 1]); i += 2
    elif a == "--out": ARGS["out"] = argv[i + 1]; i += 2
    elif a == "--export-glb": ARGS["export_glb"] = argv[i + 1]; i += 2
    elif a == "--res": ARGS["res"] = int(argv[i + 1]); i += 2
    else: i += 1
SHOT = ARGS["shot"]
STYLE = "A" if SHOT == "A" else "B"
random.seed(7)
np.random.seed(7)

# ----------------------------------------------------------------------------
# Szene leeren
# ----------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
COL = scene.collection


# ----------------------------------------------------------------------------
# Mesh-Helfer
# ----------------------------------------------------------------------------
def mesh_obj(name, verts, faces, mat=None, smooth=True, parent=None, subsurf=0,
             recalc=True, link=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.validate()
    if recalc:
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
    me.update()
    if smooth:
        me.shade_smooth()
    ob = bpy.data.objects.new(name, me)
    if link:
        COL.objects.link(ob)
    if mat is not None:
        me.materials.append(mat)
    if parent is not None:
        ob.parent = parent
    if subsurf:
        m = ob.modifiers.new("Subsurf", "SUBSURF")
        m.levels = subsurf
        m.render_levels = subsurf
    return ob


def loft(rings, closed=True, cap_start=False, cap_end=False):
    """rings: Liste gleich langer Punktlisten -> (verts, faces)"""
    M = len(rings[0])
    verts = [p for r in rings for p in r]
    faces = []
    n = len(rings)
    jr = M if closed else M - 1
    for i in range(n - 1):
        for j in range(jr):
            j2 = (j + 1) % M
            faces.append((i * M + j, i * M + j2, (i + 1) * M + j2, (i + 1) * M + j))
    if cap_start:
        c = np.mean(np.array(rings[0]), axis=0)
        verts.append(tuple(c)); ci = len(verts) - 1
        for j in range(jr):
            faces.append((ci, (j + 1) % M, j))
    if cap_end:
        c = np.mean(np.array(rings[-1]), axis=0)
        verts.append(tuple(c)); ci = len(verts) - 1
        b = (n - 1) * M
        for j in range(jr):
            faces.append((ci, b + j, b + (j + 1) % M))
    return verts, faces


def catmull(points, per_seg=12):
    """Catmull-Rom ueber Zeilen einer (n,k)-Tabelle -> dichter abgetastet"""
    P = np.array(points, dtype=float)
    P = np.vstack([P[0] * 2 - P[1], P, P[-1] * 2 - P[-2]])
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for t in np.linspace(0, 1, per_seg, endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(P[-2])
    return np.array(out)


def naca4(m, p, t, n=36):
    """NACA 4-digit, liefert geschlossene Schleife (x,z) TE-oben -> LE -> TE-unten"""
    beta = np.linspace(0, math.pi, n)
    x = 0.5 * (1 - np.cos(beta))
    yt = 5 * t * (0.2969 * np.sqrt(x) - 0.1260 * x - 0.3516 * x ** 2 + 0.2843 * x ** 3 - 0.1036 * x ** 4)
    if m > 0:
        yc = np.where(x < p, m / p ** 2 * (2 * p * x - x ** 2), m / (1 - p) ** 2 * ((1 - 2 * p) + 2 * p * x - x ** 2))
    else:
        yc = np.zeros_like(x)
    up = np.stack([x, yc + yt], 1)[::-1]
    lo = np.stack([x, yc - yt], 1)[1:]
    return np.vstack([up, lo])


def cylinder(name, p0, p1, r, mat, parent=None, seg=16, r1=None, caps=True):
    p0, p1 = Vector(p0), Vector(p1)
    r1 = r if r1 is None else r1
    d = (p1 - p0)
    q = d.to_track_quat('Z', 'Y')
    rings = []
    for k, (pp, rr) in enumerate(((p0, r), (p1, r1))):
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            v = q @ Vector((rr * math.cos(a), rr * math.sin(a), 0)) + pp
            ring.append(tuple(v))
        rings.append(ring)
    v, f = loft(rings, closed=True, cap_start=caps, cap_end=caps)
    return mesh_obj(name, v, f, mat, smooth=True, parent=parent)


def box(name, center, size, mat, parent=None, bevel=0.0, seg=3, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    COL.objects.link(ob)
    ob.location = center
    ob.rotation_euler = rot
    if mat: me.materials.append(mat)
    if parent: ob.parent = parent
    if bevel > 0:
        m = ob.modifiers.new("Bevel", "BEVEL")
        m.width = bevel; m.segments = seg; m.limit_method = 'NONE'
        me.shade_smooth()
        try:
            ob.modifiers.new("WN", "WEIGHTED_NORMAL")
        except Exception:
            pass
    return ob


def revolve(name, profile, axis='Y', seg=48, mat=None, parent=None, center=(0, 0, 0), subsurf=0):
    """profile: Liste (r, h) -> Rotationskoerper um Achse"""
    rings = []
    for (r, h) in profile:
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            c, s = r * math.cos(a), r * math.sin(a)
            if axis == 'Y':
                ring.append((center[0] + c, center[1] + h, center[2] + s))
            elif axis == 'X':
                ring.append((center[0] + h, center[1] + c, center[2] + s))
            else:
                ring.append((center[0] + c, center[1] + s, center[2] + h))
        rings.append(ring)
    v, f = loft(rings, closed=True)
    return mesh_obj(name, v, f, mat, parent=parent, subsurf=subsurf)


def tire(name, center, r_major, r_minor, width, mat, axis='X', parent=None, seg=40):
    prof = []
    for k in range(17):
        a = 2 * math.pi * k / 16
        prof.append((r_major + r_minor * math.cos(a), width * math.sin(a)))
    prof = prof[:-1]
    rings = []
    for j in range(seg):
        a = 2 * math.pi * j / seg
        ring = []
        for (r, h) in prof:
            if axis == 'X':
                ring.append((center[0] + h, center[1] + r * math.cos(a), center[2] + r * math.sin(a)))
            else:
                ring.append((center[0] + r * math.cos(a), center[1] + h, center[2] + r * math.sin(a)))
        rings.append(ring)
    rings.append(rings[0])
    v, f = loft(rings, closed=True)
    ob = mesh_obj(name, v, f, mat, parent=parent)
    bpy.ops.object.select_all(action='DESELECT')
    return ob


def curve_obj(name, pts, radius, mat, parent=None, closed=False):
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = radius
    cu.bevel_resolution = 2
    sp = cu.splines.new('POLY')
    sp.points.add(len(pts) - 1)
    for k, p in enumerate(pts):
        sp.points[k].co = (p[0], p[1], p[2], 1)
    sp.use_cyclic_u = closed
    ob = bpy.data.objects.new(name, cu)
    COL.objects.link(ob)
    if mat: cu.materials.append(mat)
    if parent: ob.parent = parent
    return ob


# ----------------------------------------------------------------------------
# Node-Helfer
# ----------------------------------------------------------------------------
class NB:
    def __init__(self, mat):
        self.nt = mat.node_tree
        self.nodes = self.nt.nodes
        self.links = self.nt.links

    def n(self, t, **kw):
        node = self.nodes.new(t)
        for k, v in kw.items():
            if k == "inputs":
                for ik, iv in v.items():
                    node.inputs[ik].default_value = iv
            else:
                setattr(node, k, v)
        return node

    def l(self, a, b):
        self.links.new(a, b)

    def math(self, op, a, b=None, clamp=False):
        m = self.n("ShaderNodeMath", operation=op, use_clamp=clamp)
        self._in(m.inputs[0], a)
        if b is not None:
            self._in(m.inputs[1], b)
        return m.outputs[0]

    def _in(self, sock, v):
        if isinstance(v, (int, float)):
            sock.default_value = v
        else:
            self.l(v, sock)

    def maprange(self, v, fmin, fmax, tmin=0.0, tmax=1.0, smooth=False):
        m = self.n("ShaderNodeMapRange", clamp=True)
        if smooth:
            m.interpolation_type = 'SMOOTHSTEP'
        self._in(m.inputs['Value'], v)
        m.inputs['From Min'].default_value = fmin
        m.inputs['From Max'].default_value = fmax
        m.inputs['To Min'].default_value = tmin
        m.inputs['To Max'].default_value = tmax
        return m.outputs[0]

    def mix(self, fac, a, b, blend='MIX'):
        m = self.n("ShaderNodeMix", data_type='RGBA', blend_type=blend, clamp_result=True)
        self._in(m.inputs[0], fac)
        for idx, v in ((6, a), (7, b)):
            if isinstance(v, (tuple, list)):
                m.inputs[idx].default_value = (v[0], v[1], v[2], 1.0)
            else:
                self.l(v, m.inputs[idx])
        return m.outputs[2]

    def mixf(self, fac, a, b):
        m = self.n("ShaderNodeMix", data_type='FLOAT', clamp_factor=True)
        self._in(m.inputs[0], fac)
        self._in(m.inputs[2], a)
        self._in(m.inputs[3], b)
        return m.outputs[0]

    def noise(self, vec, scale, detail=4.0, rough=0.5, dist=0.0):
        nz = self.n("ShaderNodeTexNoise")
        if vec is not None:
            self.l(vec, nz.inputs['Vector'])
        nz.inputs['Scale'].default_value = scale
        nz.inputs['Detail'].default_value = detail
        nz.inputs['Roughness'].default_value = rough
        nz.inputs['Distortion'].default_value = dist
        return nz

    def sep(self, vec):
        s = self.n("ShaderNodeSeparateXYZ")
        self.l(vec, s.inputs[0])
        return s.outputs

    def coords(self):
        tc = self.n("ShaderNodeTexCoord")
        return tc

    def scalevec(self, vec, sx, sy, sz):
        m = self.n("ShaderNodeMapping")
        self.l(vec, m.inputs['Vector'])
        m.inputs['Scale'].default_value = (sx, sy, sz)
        return m.outputs[0]

    def principled(self):
        return self.nodes.get("Principled BSDF") or self.n("ShaderNodeBsdfPrincipled")


def new_mat(name):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    return m


def simple_mat(name, color, rough=0.5, metal=0.0, coat=0.0, emission=None, transmission=0.0, ior=1.45, alpha=1.0):
    m = new_mat(name)
    b = NB(m)
    p = b.principled()
    p.inputs['Base Color'].default_value = (*color, 1.0)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    p.inputs['Coat Weight'].default_value = coat
    p.inputs['Transmission Weight'].default_value = transmission
    p.inputs['IOR'].default_value = ior
    if emission:
        p.inputs['Emission Color'].default_value = (*emission[0], 1)
        p.inputs['Emission Strength'].default_value = emission[1]
    m.diffuse_color = (*color, 1.0)
    m.roughness = rough
    m.metallic = metal
    return m


# ----------------------------------------------------------------------------
# Farbpalette je Stil
# ----------------------------------------------------------------------------
if STYLE == "A":
    PAL = dict(top=(0.035, 0.15, 0.025), top2=(0.035, 0.15, 0.025), bottom=(0.12, 0.35, 0.75),
               nose=(1.0, 0.42, 0.0), navy=(0.01, 0.03, 0.25), white=(0.92, 0.92, 0.90),
               yellow=(1.0, 0.75, 0.0), rough=0.35, coat=0.35)
else:
    PAL = dict(top=(0.085, 0.13, 0.045), top2=(0.17, 0.12, 0.055), bottom=(0.33, 0.42, 0.46),
               nose=(0.72, 0.45, 0.04), navy=(0.03, 0.05, 0.16), white=(0.70, 0.70, 0.64),
               yellow=(0.75, 0.52, 0.03), rough=0.58, coat=0.0)


def paint_material(part):
    """part: 'fus' | 'wing' | 'tail' -- prozeduraler Lack mit Panel-Linien,
    Markierungen und (Stil B) Abnutzung."""
    m = new_mat("Paint_" + part)
    b = NB(m)
    p = b.principled()
    tc = b.coords()
    P = tc.outputs['Object']
    Nn = tc.outputs['Normal']
    px, py, pz = b.sep(P)
    nx, ny, nz = b.sep(Nn)
    ax = b.math('ABSOLUTE', px)

    # --- Tarn-Maske (1 = Oberseitenfarbe) --------------------------------
    if part == 'fus':
        wav = b.noise(P, 1.6, 3.0).outputs['Fac']
        off = b.math('MULTIPLY', b.math('SUBTRACT', wav, 0.5), 0.35 if STYLE == "B" else 0.0)
        f = b.math('ADD', b.math('SUBTRACT', pz, -0.22), off)
        topmask = b.maprange(f, -0.01, 0.01) if STYLE == "B" else b.maprange(f, -0.003, 0.003)
    elif part == 'wing':
        topmask = b.maprange(nz, -0.05, 0.05)
    else:
        topmask = b.maprange(nz, -2.0, -1.9)  # Leitwerk: komplett Oberseitenfarbe
        # Hoehenleitwerk-Unterseite hell
        hstab = b.maprange(ax, 0.45, 0.5)
        under = b.math('MULTIPLY', hstab, b.maprange(nz, -0.2, -0.1, 1.0, 0.0))
        topmask = b.math('SUBTRACT', topmask, under, clamp=True)

    top = PAL['top']
    if STYLE == "B":
        # zweifarbige "weiche" Splittertarnung oben
        dz = b.noise(b.scalevec(P, 1, 1, 0.3), 0.55, 2.0, 0.4).outputs['Fac']
        dmask = b.maprange(dz, 0.49, 0.53)
        topc = b.mix(dmask, PAL['top'], PAL['top2'])
    else:
        topc = b.mix(0.0, top, top)
    col = b.mix(topmask, PAL['bottom'], topc)

    # --- Nasenring / Leitwerksspitze --------------------------------------
    if part == 'fus':
        nose = b.maprange(py, -3.62, -3.60, 1.0, 0.0)
        col = b.mix(nose, col, PAL['nose'])
        # Rumpfband hinten
        band = b.math('MULTIPLY', b.maprange(py, 3.0, 3.02), b.maprange(py, 3.32, 3.34, 1.0, 0.0))
        col = b.mix(band, col, PAL['yellow'])
        # Cockpit-Innenraum (unter der Haube) dunkel
        ck = b.math('MULTIPLY', b.maprange(py, -1.0, -0.95), b.maprange(py, 0.62, 0.68, 1.0, 0.0))
        ck = b.math('MULTIPLY', ck, b.maprange(pz, 0.40, 0.44))
        ck = b.math('MULTIPLY', ck, b.maprange(ax, 0.27, 0.30, 1.0, 0.0))
        col = b.mix(ck, col, (0.04, 0.045, 0.04))
    if part == 'tail':
        tip = b.maprange(pz, 1.18, 1.20)
        col = b.mix(tip, col, PAL['nose'])

    # --- Hoheitszeichen (fiktiv): Kreis navy / weiss / Raute navy / Punkt gelb
    def insignia(col, u, v, cu, cv, R, mask):
        du = b.math('SUBTRACT', u, cu)
        dv = b.math('SUBTRACT', v, cv)
        r = b.math('SQRT', b.math('ADD', b.math('MULTIPLY', du, du), b.math('MULTIPLY', dv, dv)))
        man = b.math('ADD', b.math('ABSOLUTE', du), b.math('ABSOLUTE', dv))
        e = 0.004
        c1 = b.math('MULTIPLY', b.maprange(r, R - e, R + e, 1, 0), mask)
        c2 = b.math('MULTIPLY', b.maprange(r, R * 0.84 - e, R * 0.84 + e, 1, 0), mask)
        c3 = b.math('MULTIPLY', b.maprange(man, R * 0.66 - e, R * 0.66 + e, 1, 0), mask)
        c4 = b.math('MULTIPLY', b.maprange(r, R * 0.2 - e, R * 0.2 + e, 1, 0), mask)
        col = b.mix(c1, col, PAL['navy'])
        col = b.mix(c2, col, PAL['white'])
        col = b.mix(c3, col, PAL['navy'])
        col = b.mix(c4, col, PAL['yellow'])
        return col

    if part == 'fus':
        side = b.maprange(ax, 0.12, 0.16)
        col = insignia(col, py, pz, 2.05, 0.02, 0.27, side)
    if part == 'wing':
        col = insignia(col, ax, py, 3.75, -1.25, 0.42, b.maprange(ax, 1.0, 1.1))

    # --- Panel-Linien -----------------------------------------------------
    def lines(c, spacing, width, offset=0.0):
        v = b.math('DIVIDE', b.math('ADD', c, offset), spacing)
        fr = b.math('FRACT', v)
        d = b.math('MULTIPLY', b.math('SUBTRACT', 0.5, b.math('ABSOLUTE', b.math('SUBTRACT', fr, 0.5))), spacing)
        return b.maprange(d, 0.0, width, 1.0, 0.0, smooth=True)

    w = 0.006
    L = lines(py, 0.82, w, 0.21)
    if part == 'wing':
        L = b.math('MAXIMUM', L, lines(px, 1.15, w, 0.3))
        # Querruder-/Klappentrennung als Linie konstanter Y
        L = b.math('MAXIMUM', L, b.math('MULTIPLY', lines(py, 50.0, w, 49.15 - 0.0), b.maprange(ax, 2.6, 2.65)))
    if part == 'fus':
        L = b.math('MAXIMUM', L, b.maprange(b.math('ABSOLUTE', b.math('SUBTRACT', pz, 0.17)), 0, w, 1, 0, smooth=True))
        L = b.math('MAXIMUM', L, b.maprange(b.math('ABSOLUTE', b.math('SUBTRACT', pz, -0.33)), 0, w, 1, 0, smooth=True))
    if part == 'tail':
        L = b.math('MAXIMUM', L, lines(pz, 0.55, w, 0.1))

    linestrength = 0.55 if STYLE == "B" else 0.35
    col = b.mix(b.math('MULTIPLY', L, linestrength), col, (0.01, 0.01, 0.01))
    rough = PAL['rough']
    metal = 0.0
    roughsock = None
    metalsock = None

    if STYLE == "B":
        # Grossflaechiger Schmutz / Ausbleichen
        g = b.noise(P, 2.2, 6.0, 0.6).outputs['Fac']
        grime = b.maprange(g, 0.35, 0.75, 0.0, 0.35)
        col = b.mix(grime, col, (0.07, 0.06, 0.045), 'MULTIPLY')
        fade = b.noise(P, 0.7, 2.0).outputs['Fac']
        col = b.mix(b.maprange(fade, 0.4, 0.7, 0.0, 0.12), col, (0.6, 0.6, 0.55), 'SCREEN')
        # Abgasfahne am Rumpf
        if part == 'fus':
            st = b.noise(b.scalevec(P, 4.0, 0.25, 4.0), 3.0, 4.0).outputs['Fac']
            reg = b.math('MULTIPLY', b.maprange(py, -3.4, -3.0), b.maprange(py, -3.0, 0.6, 1.0, 0.0))
            reg = b.math('MULTIPLY', reg, b.maprange(b.math('ABSOLUTE', b.math('SUBTRACT', pz, 0.06)), 0.04, 0.28, 1.0, 0.0))
            reg = b.math('MULTIPLY', reg, b.maprange(ax, 0.15, 0.3))
            ex = b.math('MULTIPLY', reg, b.maprange(st, 0.3, 0.7, 0.35, 0.95))
            col = b.mix(ex, col, (0.012, 0.010, 0.009))
        # Lack-Abplatzer -> Aluminium
        chip_n = b.noise(P, 14.0, 10.0, 0.7).outputs['Fac']
        hot = 0.70
        if part == 'wing':
            # Flugelwurzel (Laufflaeche) und Vorderkante staerker
            walk = b.math('MULTIPLY', b.maprange(ax, 0.5, 0.6), b.maprange(ax, 1.25, 1.45, 1.0, 0.0))
            thr = b.math('SUBTRACT', hot, b.math('MULTIPLY', walk, 0.06))
        else:
            thr = hot
        chips = b.maprange(b.math('SUBTRACT', chip_n, thr), 0.0, 0.01)
        col = b.mix(chips, col, (0.62, 0.62, 0.60))
        rn = b.noise(P, 6.0, 4.0).outputs['Fac']
        roughsock = b.mixf(chips, b.maprange(rn, 0.3, 0.7, 0.48, 0.72), 0.28)
        metalsock = chips
    p.inputs['Coat Weight'].default_value = PAL['coat']
    p.inputs['Coat Roughness'].default_value = 0.08
    b.l(col, p.inputs['Base Color'])
    if roughsock is not None:
        b.l(roughsock, p.inputs['Roughness'])
        b.l(metalsock, p.inputs['Metallic'])
    else:
        p.inputs['Roughness'].default_value = rough
        p.inputs['Metallic'].default_value = metal
    # Bump fuer Panel-Linien (+ leichte Beulen in B)
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 0.35 if STYLE == "B" else 0.2
    bump.inputs['Distance'].default_value = 0.002
    h = b.math('MULTIPLY', L, -1.0)
    if STYLE == "B":
        dent = b.noise(P, 3.5, 2.0).outputs['Fac']
        h = b.math('ADD', h, b.math('MULTIPLY', dent, 0.4))
    b.l(h, bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    m.diffuse_color = (*PAL['top'], 1)
    return m


def worn_metal(name, base, rough=0.35, metal=1.0, dirt=0.4, scale=8.0):
    m = new_mat(name)
    b = NB(m)
    p = b.principled()
    P = b.coords().outputs['Object']
    if STYLE == "B":
        nz = b.noise(P, scale, 6.0, 0.6).outputs['Fac']
        col = b.mix(b.maprange(nz, 0.4, 0.8, 0, dirt), base, (0.05, 0.04, 0.03))
        b.l(col, p.inputs['Base Color'])
        b.l(b.maprange(nz, 0.3, 0.8, rough, min(1.0, rough + 0.35)), p.inputs['Roughness'])
    else:
        p.inputs['Base Color'].default_value = (*base, 1)
        p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    m.diffuse_color = (*base, 1)
    return m


# ----------------------------------------------------------------------------
# Flugzeug "T1" (generischer Jaeger, spaete 1930er)
# ----------------------------------------------------------------------------
def build_fighter(pilot=False, gear=True):
    root = bpy.data.objects.new("Fighter_T1", None)
    COL.objects.link(root)

    M_fus = paint_material('fus')
    M_wing = paint_material('wing')
    M_tail = paint_material('tail')
    M_glass = simple_mat("Glass", (0.85, 0.92, 0.95), rough=0.03, transmission=1.0, ior=1.5)
    M_frame = simple_mat("Frame", PAL['top'], rough=0.5)
    M_rubber = simple_mat("Rubber", (0.025, 0.025, 0.025), rough=0.85)
    M_strut = worn_metal("Strut", (0.55, 0.56, 0.57), rough=0.3, metal=1.0, dirt=0.5)
    M_chrome = simple_mat("Oleo", (0.85, 0.85, 0.85), rough=0.12, metal=1.0)
    M_exh = worn_metal("Exhaust", (0.16, 0.08, 0.05), rough=0.7, metal=0.6, dirt=0.8, scale=20)
    M_prop = worn_metal("PropBlade", (0.03, 0.03, 0.03), rough=0.5, metal=0.0, dirt=0.3, scale=12)
    M_spinner = simple_mat("Spinner", PAL['nose'], rough=0.3 if STYLE == "A" else 0.45, coat=PAL['coat'])
    M_tip = simple_mat("PropTip", PAL['yellow'], rough=0.4)
    M_dark = simple_mat("DarkInterior", (0.02, 0.02, 0.02), rough=0.8)
    M_gun = simple_mat("Gunmetal", (0.05, 0.05, 0.055), rough=0.35, metal=1.0)
    M_hub = simple_mat("Hub", PAL['bottom'], rough=0.5)

    # ---- Rumpf ------------------------------------------------------------
    #        y      halbe Breite  z_oben  z_unten
    tab = [(-4.10, 0.29, 0.20, -0.33),
           (-3.95, 0.37, 0.29, -0.43),
           (-3.50, 0.45, 0.38, -0.55),
           (-2.70, 0.50, 0.44, -0.63),
           (-1.70, 0.53, 0.48, -0.68),
           (-0.80, 0.54, 0.50, -0.70),
           (0.00, 0.52, 0.52, -0.67),
           (0.90, 0.45, 0.50, -0.57),
           (1.90, 0.36, 0.44, -0.44),
           (2.90, 0.27, 0.37, -0.30),
           (3.80, 0.17, 0.31, -0.16),
           (4.45, 0.075, 0.26, -0.02),
           (4.72, 0.012, 0.22, 0.07)]
    S = catmull(tab, 10)
    nseg = 56
    rings = []
    ex = 2.4
    for (y, w, zt, zb) in S:
        zc, h = (zt + zb) / 2, (zt - zb) / 2
        ring = []
        for j in range(nseg):
            a = 2 * math.pi * j / nseg
            c, s = math.cos(a), math.sin(a)
            x = w * math.copysign(abs(c) ** (2 / ex), c)
            z = zc + h * math.copysign(abs(s) ** (2 / ex), s)
            ring.append((x, y, z))
        rings.append(ring)
    v, f = loft(rings, closed=True, cap_start=True, cap_end=True)
    fus = mesh_obj("Fuselage", v, f, M_fus, parent=root, subsurf=1)

    def fus_at(y):
        k = np.argmin(np.abs(S[:, 0] - y))
        return S[k]

    # ---- Fluegel (Tiefdecker) -------------------------------------------
    half_span = 5.35
    croot, ctip = 2.25, 0.95
    yqc = -1.45
    dih = math.radians(6.0)
    zroot = -0.43
    stations = list(np.linspace(0.0, 0.88, 14)) + list(0.88 + 0.12 * np.sin(np.linspace(0.12, 1.0, 8) * math.pi / 2))
    def wing_rings(sign):
        rings = []
        for t in stations:
            c = croot + (ctip - croot) * t
            if t > 0.88:
                e = (t - 0.88) / 0.12
                c *= math.sqrt(max(0.0, 1 - e ** 2)) * 0.85 + 0.15 * (1 - e)
            thick = 0.15 + (0.09 - 0.15) * min(t, 1)
            if t > 0.88:
                thick *= max(0.08, math.sqrt(max(0.0, 1 - ((t - 0.88) / 0.12) ** 2)))
            af = naca4(0.02, 0.4, thick, 34)
            x = t * half_span
            le = yqc - 0.25 * c
            z0 = zroot + x * math.tan(dih)
            twist = math.radians(-1.5 * t)
            ring = []
            for (ax_, az_) in af:
                yy = (ax_ - 0.25) * c
                zz = az_ * c
                yr = yy * math.cos(twist) - zz * math.sin(twist)
                zr = yy * math.sin(twist) + zz * math.cos(twist)
                ring.append((sign * x, yqc + yr, z0 + zr))
            rings.append(ring)
        return rings
    wv, wf = [], []
    for sgn in (1, -1):
        v, f = loft(wing_rings(sgn), closed=False, cap_end=True)
        o = len(wv)
        wv += v
        wf += [tuple(i + o for i in ff) for ff in f]
    wing = mesh_obj("Wing", wv, wf, M_wing, parent=root)

    def wing_surface_z(x, y, upper=False):
        t = abs(x) / half_span
        c = croot + (ctip - croot) * t
        z0 = zroot + abs(x) * math.tan(dih)
        thick = 0.15 + (0.09 - 0.15) * t
        return z0 + (1 if upper else -1) * thick * c * 0.45

    # ---- Leitwerk ----------------------------------------------------------
    def surface(name, stations, sign_axis, mat):
        """stations: (spanpos, le_y, chord, thickness, base) -> Rings"""
        pass

    # Hoehenleitwerk
    hs_rings = {1: [], -1: []}
    hs_st = list(np.linspace(0, 0.85, 8)) + list(0.85 + 0.15 * np.sin(np.linspace(0.15, 1.0, 6) * math.pi / 2))
    for sgn in (1, -1):
        for t in hs_st:
            c = 1.05 + (0.62 - 1.05) * t
            if t > 0.85:
                e = (t - 0.85) / 0.15
                c *= math.sqrt(max(0.0, 1 - e ** 2)) * 0.85 + 0.15 * (1 - e)
            th = 0.10 if t <= 0.85 else 0.10 * max(0.1, math.sqrt(max(0, 1 - ((t - 0.85) / 0.15) ** 2)))
            af = naca4(0, 0.4, th, 26)
            x = t * 1.85
            yqc_h = 3.82
            ring = [(sgn * x, yqc_h + (a_ - 0.25) * c, 0.13 + x * 0.02 + b_ * c) for (a_, b_) in af]
            hs_rings[sgn].append(ring)
    hv, hf = [], []
    for sgn in (1, -1):
        v, f = loft(hs_rings[sgn], closed=False, cap_end=True)
        o = len(hv); hv += v; hf += [tuple(i + o for i in ff) for ff in f]
    mesh_obj("HStab", hv, hf, M_tail, parent=root)

    # Seitenleitwerk
    vs_rings = []
    vs_st = list(np.linspace(0, 0.82, 8)) + list(0.82 + 0.18 * np.sin(np.linspace(0.15, 1.0, 7) * math.pi / 2))
    for t in vs_st:
        z = 0.10 + t * 1.42
        c = 1.50 + (0.62 - 1.50) * t
        te = 4.86 - 0.05 * t
        if t > 0.82:
            e = (t - 0.82) / 0.18
            c *= math.sqrt(max(0.0, 1 - e ** 2)) * 0.85 + 0.15 * (1 - e)
        th = 0.11 if t <= 0.82 else 0.11 * max(0.1, math.sqrt(max(0, 1 - ((t - 0.82) / 0.18) ** 2)))
        af = naca4(0, 0.4, th, 26)
        le = te - c
        vs_rings.append([(b_ * c, le + a_ * c, z) for (a_, b_) in af])
    v, f = loft(vs_rings, closed=False, cap_end=True)
    mesh_obj("VFin", v, f, M_tail, parent=root)

    # ---- Cockpithaube -----------------------------------------------------
    ctab = [(-1.20, 0.22, 0.40),
            (-1.00, 0.27, 0.62),
            (-0.70, 0.30, 0.86),
            (-0.30, 0.31, 0.93),
            (0.20, 0.30, 0.92),
            (0.65, 0.25, 0.82),
            (1.10, 0.17, 0.66),
            (1.55, 0.09, 0.50)]
    CS = catmull(ctab, 8)
    zb = 0.36
    cr = []
    narc = 28
    for (y, w, zt) in CS:
        ring = []
        for j in range(narc + 1):
            ph = math.pi * j / narc
            c, s = math.cos(ph), math.sin(ph)
            x = w * math.copysign(abs(c) ** (2 / 2.6), c)
            z = zb + (zt - zb) * (abs(s) ** (2 / 2.6))
            ring.append((x, y, z))
        cr.append(ring)
    v, f = loft(cr, closed=False)
    canopy = mesh_obj("Canopy", v, f, M_glass, parent=root)

    # Rahmen: Spanten der Haube
    def canopy_ring_at(y, scale=1.012):
        k = np.argmin(np.abs(CS[:, 0] - y))
        yy, w, zt = CS[k]
        pts = []
        for j in range(narc + 1):
            ph = math.pi * j / narc
            c, s = math.cos(ph), math.sin(ph)
            x = w * scale * math.copysign(abs(c) ** (2 / 2.6), c)
            z = zb + (zt - zb) * scale * (abs(s) ** (2 / 2.6))
            if z > 0.40:
                pts.append((x, yy, z))
        return pts
    for yy in (-1.0, -0.72, -0.22, 0.30, 0.78):
        curve_obj("CanopyFrame", canopy_ring_at(yy), 0.014, M_frame, parent=root)
    # Laengsstreben (Dachmitte, Seiten)
    for frac in (0.5, 0.17, 0.83):
        pts = []
        for (y, w, zt) in CS:
            if y < -1.02 or y > 1.25:
                continue
            ph = math.pi * frac
            c, s = math.cos(ph), math.sin(ph)
            x = w * 1.012 * math.copysign(abs(c) ** (2 / 2.6), c)
            z = zb + (zt - zb) * 1.012 * (abs(s) ** (2 / 2.6))
            pts.append((x, y, z))
        curve_obj("CanopyRail", pts, 0.012, M_frame, parent=root)
    # Kopfstuetze / Panzerplatte und Reflexvisier
    box("Headrest", (0, 0.42, 0.66), (0.24, 0.05, 0.30), M_dark, parent=root, bevel=0.02)
    box("Gunsight", (0, -0.78, 0.60), (0.06, 0.08, 0.10), M_dark, parent=root, bevel=0.01)
    if pilot:
        M_leather = simple_mat("Leather", (0.12, 0.06, 0.03), rough=0.6)
        M_suit = simple_mat("Suit", (0.12, 0.11, 0.08), rough=0.8)
        bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=0.11)
        me = bpy.data.meshes.new("PilotHead"); bm.to_mesh(me); bm.free(); me.shade_smooth()
        hd = bpy.data.objects.new("PilotHead", me); COL.objects.link(hd); hd.parent = root
        hd.location = (0, 0.12, 0.76); me.materials.append(M_leather)
        bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=0.2)
        me = bpy.data.meshes.new("PilotBody"); bm.to_mesh(me); bm.free(); me.shade_smooth()
        bd = bpy.data.objects.new("PilotBody", me); COL.objects.link(bd); bd.parent = root
        bd.location = (0, 0.20, 0.52); bd.scale = (1.15, 0.7, 0.8); me.materials.append(M_suit)

    # Antenne
    cylinder("AntennaMast", (0, 1.05, 0.55), (0, 1.12, 0.98), 0.012, M_frame, parent=root, r1=0.006)
    curve_obj("AntennaWire", [(0, 1.12, 0.98), (0, 4.45, 1.45)], 0.0025, M_rubber, parent=root)

    # ---- Spinner & Propeller ----------------------------------------------
    prof = []
    for k in range(25):
        t = k / 24
        r = 0.305 * (max(0.0, 1 - t ** 2.0)) ** 0.5
        prof.append((max(r, 0.0005), -4.08 - 0.72 * t))
    prof.insert(0, (0.25, -4.02))
    spinner = revolve("Spinner", prof, 'Y', 48, M_spinner, parent=root, subsurf=1)

    prop = bpy.data.objects.new("Propeller", None)
    COL.objects.link(prop)
    prop.parent = root
    prop.location = (0, -4.36, -0.065)
    pv, pf = [], []
    tipv, tipf = [], []
    radii = np.concatenate([np.linspace(0.16, 1.40, 16), 1.40 + 0.13 * np.sin(np.linspace(0.15, 1, 7) * math.pi / 2)])
    for bl in range(3):
        rot = 2 * math.pi * bl / 3 + 0.3
        rings = []
        for r in radii:
            c = 0.17 + 0.09 * math.sin(min(1, (r - 0.16) / 0.9) * math.pi * 0.6)
            if r > 1.40:
                e = (r - 1.40) / 0.13
                c *= math.sqrt(max(0, 1 - e ** 2)) * 0.9 + 0.1 * (1 - e)
            th = 0.16 - 0.10 * (r - 0.16) / 1.4
            if r < 0.3:
                th = 0.35
            af = naca4(0.03, 0.35, th, 22)
            beta = math.atan(2.6 / (2 * math.pi * max(r, 0.25)))
            ring = []
            for (a_, b_) in af:
                u = (a_ - 0.35) * c
                vv = b_ * c
                # Profil in Ebene (Sehne u, Dicke v), um beta gedreht; Radial = Z
                lx = u * math.cos(beta) - vv * math.sin(beta)
                ly = u * math.sin(beta) + vv * math.cos(beta)
                lz = r
                # Blatt um Y-Achse (Drehachse) rotieren
                X = lx * math.cos(rot) + lz * math.sin(rot)
                Z = -lx * math.sin(rot) + lz * math.cos(rot)
                ring.append((X, ly, Z))
            rings.append(ring)
        v, f = loft(rings, closed=False, cap_end=True)
        o = len(pv); pv += v; pf += [tuple(i + o for i in ff) for ff in f]
    blades = mesh_obj("PropBlades", pv, pf, M_prop, parent=prop)
    # gelbe Blattspitzen per Materialzuweisung
    blades.data.materials.append(M_tip)
    for poly in blades.data.polygons:
        c = poly.center
        if math.hypot(c.x, c.z) > 1.30:
            poly.material_index = 1

    # ---- Fahrwerk ----------------------------------------------------------
    gear_parts = []
    for sgn in (1, -1):
        top = (sgn * 1.62, -1.78, -0.40)
        axle = (sgn * 1.70, -1.90, -1.58)
        cylinder("GearLeg", top, (sgn * 1.68, -1.86, -1.15), 0.055, M_strut, parent=root)
        cylinder("Oleo", (sgn * 1.68, -1.86, -1.15), (sgn * 1.70, -1.90, -1.50), 0.04, M_chrome, parent=root)
        cylinder("Axle", (sgn * 1.70, -1.90, -1.58), (sgn * 1.56, -1.90, -1.58), 0.03, M_strut, parent=root)
        cylinder("Fork", (sgn * 1.70, -1.90, -1.47), (sgn * 1.70, -1.90, -1.60), 0.035, M_strut, parent=root)
        wc = (sgn * 1.55, -1.90, -1.58)
        tire("MainTire", wc, 0.255, 0.085, 0.075, M_rubber, axis='X', parent=root)
        cylinder("Hub", (wc[0] - 0.06, wc[1], wc[2]), (wc[0] + 0.06, wc[1], wc[2]), 0.18, M_hub, parent=root, seg=24)
        # Fahrwerksklappe (aussen am Bein)
        door = box("GearDoor", (sgn * 1.75, -1.82, -0.92), (0.02, 0.30, 0.78), M_wing, parent=root,
                   bevel=0.01, rot=(math.radians(-5), math.radians(sgn * -4), 0))
        # Waffen: Laeufe in der Vorderkante
        gx = sgn * 2.35
        t = gx / half_span
        c = croot + (ctip - croot) * abs(t)
        le_y = yqc - 0.25 * c
        gz = zroot + abs(gx) * math.tan(dih) + 0.01
        cylinder("GunBarrel", (gx, le_y + 0.25, gz), (gx, le_y - 0.42, gz), 0.018, M_gun, parent=root)
        cylinder("GunFairing", (gx, le_y + 0.15, gz), (gx, le_y - 0.05, gz), 0.042, M_gun, parent=root, r1=0.03)
    # Staurohr
    cylinder("Pitot", (-4.3, -1.6, wing_surface_z(-4.3, 0) - 0.02), (-4.3, -2.25, wing_surface_z(-4.3, 0) - 0.08), 0.008, M_strut, parent=root)
    # Spornrad
    cylinder("TailStrut", (0, 4.20, 0.02), (0, 4.34, -0.40), 0.035, M_strut, parent=root)
    tire("TailTire", (0, 4.34, -0.43), 0.075, 0.04, 0.035, M_rubber, axis='X', parent=root, seg=24)
    cylinder("TailHub", (-0.04, 4.34, -0.43), (0.04, 4.34, -0.43), 0.05, M_strut, parent=root, seg=16)

    # ---- Auspuffstutzen ----------------------------------------------------
    for sgn in (1, -1):
        for k in range(6):
            y = -3.55 + k * 0.17
            row = fus_at(y)
            w = row[1]
            x0 = sgn * (w * 0.93)
            cylinder("Exhaust", (x0, y, 0.10), (x0 + sgn * 0.085, y + 0.06, 0.08), 0.033, M_exh, parent=root, seg=10)

    # ---- Kuehler unter dem Rumpf ------------------------------------------
    rad = box("Radiator", (0, -0.25, -0.70), (0.60, 1.5, 0.34), M_fus, parent=root, bevel=0.1, seg=5)
    box("RadiatorIntake", (0, -1.0, -0.76), (0.48, 0.02, 0.18), M_dark, parent=root, bevel=0.02)

    # Ladeluftschlitz / Lufteinlauf links
    box("AirIntake", (0.42, -3.1, -0.25), (0.10, 0.45, 0.14), M_fus, parent=root, bevel=0.04, seg=3)

    if not gear:
        for ob in list(root.children):
            if ob.name.split('.')[0] in ("GearLeg", "Oleo", "Axle", "Fork", "MainTire", "Hub", "GearDoor",
                                          "TailStrut", "TailTire", "TailHub"):
                bpy.data.objects.remove(ob)
    return root, prop


def outline_mat():
    m = new_mat("Outline")
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL':
            nt.nodes.remove(n)
    out = [n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'][0]
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs['Color'].default_value = (0.01, 0.012, 0.01, 1)
    em.inputs['Strength'].default_value = 1.0
    mx = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs['Backfacing'], mx.inputs[0])
    nt.links.new(em.outputs[0], mx.inputs[1])
    nt.links.new(tr.outputs[0], mx.inputs[2])
    # keine Schatten / indirekte Beitraege der Kontur
    lp = nt.nodes.new("ShaderNodeLightPath")
    mx2 = nt.nodes.new("ShaderNodeMixShader")
    tr2 = nt.nodes.new("ShaderNodeBsdfTransparent")
    nt.links.new(lp.outputs['Is Camera Ray'], mx2.inputs[0])
    nt.links.new(tr2.outputs[0], mx2.inputs[1])
    nt.links.new(mx.outputs[0], mx2.inputs[2])
    mx = mx2
    nt.links.new(mx.outputs[0], out.inputs['Surface'])
    return m


def add_outlines(root, thickness=0.018, skip=("Canopy",)):
    """Inverted-Hull-Kontur (wie im Spiel per Shader machbar)."""
    om = outline_mat()
    for ob in root.children_recursive:
        if ob.type != 'MESH' or ob.name.startswith(skip):
            continue
        ob.data.materials.append(om)
        sol = ob.modifiers.new("Outline", 'SOLIDIFY')
        sol.thickness = thickness
        sol.offset = 1.0
        sol.use_flip_normals = True
        sol.use_rim = False
        sol.material_offset = len(ob.data.materials) - 1
        try:
            ob.visible_shadow = False if False else True
        except Exception:
            pass


def ground_attitude(root):
    """Kippt das Flugzeug so, dass Haupt- und Spornrad den Boden beruehren."""
    yM, zM, RM = -1.90, -1.58, 0.34
    yT, zT, RT = 4.34, -0.43, 0.115
    a = math.atan2((zT - zM) - 0.0, (yM - yT))
    # Loesen numerisch
    def zprime(y, z, ang):
        return y * math.sin(ang) + z * math.cos(ang)
    best = None
    for k in range(4001):
        ang = math.radians(-25 + k * 0.01)
        d = (zprime(yM, zM, ang) - RM) - (zprime(yT, zT, ang) - RT)
        if best is None or abs(d) < abs(best[1]):
            best = (ang, d)
    ang = best[0]
    root.rotation_euler = (ang, 0, 0)
    z0 = -(zprime(yM, zM, ang) - RM) - 0.03  # leichte Reifeneinfederung
    return ang, z0


# ----------------------------------------------------------------------------
# Umgebung: Flugfeld
# ----------------------------------------------------------------------------
def grass_material():
    m = new_mat("Grass")
    b = NB(m)
    p = b.principled()
    P = b.coords().outputs['Object']
    px, py, pz = b.sep(P)
    n1 = b.noise(P, 0.04, 4.0, 0.6).outputs['Fac']
    n2 = b.noise(P, 0.9, 6.0, 0.7).outputs['Fac']
    n3 = b.noise(P, 18.0, 3.0, 0.6).outputs['Fac']
    if STYLE == "A":
        g1, g2, dry = (0.10, 0.30, 0.03), (0.16, 0.40, 0.05), (0.35, 0.40, 0.10)
    else:
        g1, g2, dry = (0.030, 0.060, 0.012), (0.075, 0.11, 0.025), (0.20, 0.16, 0.06)
    col = b.mix(b.maprange(n1, 0.35, 0.65), g1, g2)
    col = b.mix(b.maprange(n2, 0.55, 0.75, 0.0, 0.6), col, dry)
    col = b.mix(b.maprange(n3, 0.3, 0.7, 0.0, 0.25), col, (0.02, 0.03, 0.01), 'MULTIPLY')
    n4 = b.noise(P, 0.35, 6.0, 0.65).outputs['Fac']
    col = b.mix(b.maprange(n4, 0.4, 0.7, 0.0, 0.35), col, (0.20, 0.20, 0.07) if STYLE == "B" else (0.30, 0.45, 0.08))
    n5 = b.noise(P, 3.0, 8.0, 0.75).outputs['Fac']
    col = b.mix(b.maprange(n5, 0.3, 0.75, 0.0, 0.5), col, (0.01, 0.015, 0.005), 'MULTIPLY')
    # Gemaehte Piste mit Streifen (entlang Y, x in [30,70])
    strip = b.math('MULTIPLY', b.maprange(px, 28, 30), b.maprange(px, 70, 72, 1, 0))
    stripes = b.math('GREATER_THAN', b.math('FRACT', b.math('DIVIDE', px, 10.0)), 0.5)
    lighten = b.math('MULTIPLY', strip, b.mixf(stripes, 0.10, 0.22))
    col = b.mix(lighten, col, (0.55, 0.65, 0.25), 'SCREEN')
    # Fahrspuren / ausgefahrener Boden
    tracks = b.math('MULTIPLY', strip, b.maprange(b.math('ABSOLUTE', b.math('SUBTRACT', px, 50.0)), 1.0, 2.5, 1.0, 0.0))
    tn = b.noise(P, 1.5, 4.0).outputs['Fac']
    col = b.mix(b.math('MULTIPLY', tracks, b.maprange(tn, 0.3, 0.7, 0.2, 0.7)), col, (0.18, 0.14, 0.09))
    b.l(col, p.inputs['Base Color'])
    b.l(b.maprange(n2, 0.0, 1.0, 0.75, 0.95), p.inputs['Roughness'])
    p.inputs['Specular IOR Level'].default_value = 0.3
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 1.0
    bump.inputs['Distance'].default_value = 0.05
    hb = b.noise(P, 25.0, 8.0, 0.75).outputs['Fac']
    b.l(hb, bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    return m


def grass_hair(ground_obj, count=60000, area_mat=None):
    """Echte Grashalme (Partikel-Haar) nur auf einem Patch um das Flugzeug."""
    ps_mod = ground_obj.modifiers.new("Grass", 'PARTICLE_SYSTEM')
    ps = ps_mod.particle_system
    st = ps.settings
    st.type = 'HAIR'
    st.count = count
    st.hair_length = 0.09
    st.use_advanced_hair = True
    st.use_rotations = True
    st.rotation_mode = 'NOR'
    st.phase_factor_random = 2.0
    st.brownian_factor = 0.0
    st.factor_random = 0.04
    st.normal_factor = 1.0
    st.child_type = 'INTERPOLATED'
    st.child_percent = 6
    st.rendered_child_count = 6
    st.child_radius = 0.06
    st.roughness_1 = 0.03
    st.roughness_endpoint = 0.02
    st.root_radius = 0.003 * 1.0
    st.tip_radius = 0.0
    st.radius_scale = 1.0
    st.display_step = 2
    st.render_step = 2
    if hasattr(st, "hair_step"):
        st.hair_step = 3
    st.material_slot = ground_obj.data.materials[-1].name if area_mat else ground_obj.data.materials[0].name
    return ps


def tree_material():
    m = new_mat("Trees")
    b = NB(m)
    p = b.principled()
    P = b.coords().outputs['Generated']
    n = b.noise(b.coords().outputs['Object'], 2.0, 5.0, 0.7).outputs['Fac']
    if STYLE == "A":
        col = b.mix(b.maprange(n, 0.3, 0.7), (0.03, 0.15, 0.02), (0.08, 0.28, 0.04))
    else:
        col = b.mix(b.maprange(n, 0.3, 0.7), (0.012, 0.035, 0.010), (0.04, 0.075, 0.02))
    b.l(col, p.inputs['Base Color'])
    p.inputs['Roughness'].default_value = 0.9
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 0.8
    b.l(b.noise(b.coords().outputs['Object'], 6.0, 3.0).outputs['Fac'], bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    return m


def value_noise_2d(X, Y, octaves=5, base=1 / 400.0, seed=1):
    rng = np.random.default_rng(seed)
    out = np.zeros_like(X)
    amp = 1.0
    freq = base
    tot = 0
    for o in range(octaves):
        G = rng.random((258, 258))
        u = (X * freq) % 256
        v = (Y * freq) % 256
        i0 = np.floor(u).astype(int); j0 = np.floor(v).astype(int)
        fu = u - i0; fv = v - j0
        fu = fu * fu * (3 - 2 * fu); fv = fv * fv * (3 - 2 * fv)
        a = G[i0, j0]; b_ = G[i0 + 1, j0]; c = G[i0, j0 + 1]; d = G[i0 + 1, j0 + 1]
        out += amp * ((a * (1 - fu) + b_ * fu) * (1 - fv) + (c * (1 - fu) + d * fu) * fv)
        tot += amp
        amp *= 0.5
        freq *= 2.0
    return out / tot


def grid_terrain(name, size, n, height_fn, mat, z_off=0.0):
    xs = np.linspace(-size / 2, size / 2, n)
    X, Y = np.meshgrid(xs, xs, indexing='ij')
    Z = height_fn(X, Y) + z_off
    verts = np.stack([X.ravel(), Y.ravel(), Z.ravel()], 1)
    faces = []
    for i in range(n - 1):
        for j in range(n - 1):
            a = i * n + j
            faces.append((a, a + n, a + n + 1, a + 1))
    return mesh_obj(name, verts, faces, mat, recalc=False)


def build_airfield():
    M_grass = grass_material()
    # Nahbereich flach + Hintergrund-Huegel
    def h(X, Y):
        R = np.sqrt(X ** 2 + Y ** 2)
        hills = value_noise_2d(X, Y, 5, 1 / 350.0, 3) * 70 - 20
        w = np.clip((R - 350) / 600, 0, 1) ** 1.5
        micro = value_noise_2d(X, Y, 3, 1 / 25.0, 5) * 0.25
        return hills * w + micro * (1 - w) - 0.30
    ground = grid_terrain("Ground", 5000, 260, h, M_grass)
    # feiner Nahbereich (flach)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=60, y_segments=60, size=45)
    me = bpy.data.meshes.new("GroundNear"); bm.to_mesh(me); bm.free()
    near = bpy.data.objects.new("GroundNear", me); COL.objects.link(near)
    near.location = (0, 8, -0.005)
    me.materials.append(M_grass)

    # Baumreihen
    M_tree = tree_material()
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
    for v in bm.verts:
        n = v.co.normalized()
        d = 1 + 0.18 * math.sin(7 * n.x + 3 * n.y) * math.cos(5 * n.z + 2 * n.x) + 0.1 * math.sin(13 * n.y)
        v.co = n * d
    tree_me = bpy.data.meshes.new("TreeBlob"); bm.to_mesh(tree_me); bm.free()
    tree_me.shade_smooth()
    tree_me.materials.append(M_tree)
    rng = random.Random(3)
    for k in range(650):
        ang = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(260, 520)
        # Waldkante im Norden/Westen dichter
        x, y = r * math.cos(ang), r * math.sin(ang)
        if rng.random() < 0.35 and y < 0:
            continue
        s = rng.uniform(5, 11)
        ob = bpy.data.objects.new("Tree", tree_me)
        COL.objects.link(ob)
        R = math.hypot(x, y)
        ob.location = (x, y, h(np.array([x]), np.array([y]))[0] + s * 0.8)
        ob.scale = (s * rng.uniform(0.8, 1.3), s * rng.uniform(0.8, 1.3), s * rng.uniform(0.9, 1.4))
    return ground


def hangar_material(door=False):
    m = new_mat("HangarDoor" if door else "HangarMetal")
    b = NB(m)
    p = b.principled()
    P = b.coords().outputs['Object']
    px, py, pz = b.sep(P)
    if door:
        base = (0.12, 0.17, 0.09) if STYLE == "B" else (0.15, 0.32, 0.12)
        metal = 0.0
    else:
        base = (0.42, 0.43, 0.42) if STYLE == "B" else (0.62, 0.64, 0.66)
        metal = 0.85
    if STYLE == "B":
        st = b.noise(b.scalevec(P, 6.0, 6.0, 0.25), 1.2, 6.0, 0.6).outputs['Fac']
        rust = b.maprange(st, 0.5, 0.8, 0.0, 0.85)
        col = b.mix(rust, base, (0.22, 0.09, 0.03))
        bottom = b.maprange(pz, 0.0, 1.6, 0.7, 0.0)
        col = b.mix(bottom, col, (0.10, 0.08, 0.05))
        big = b.noise(P, 0.3, 3.0).outputs['Fac']
        col = b.mix(b.maprange(big, 0.3, 0.7, 0.0, 0.4), col, (0.15, 0.15, 0.14), 'MULTIPLY')
        b.l(col, p.inputs['Base Color'])
        b.l(b.mixf(rust, 0.42, 0.85), p.inputs['Roughness'])
        b.l(b.mixf(rust, metal, 0.0), p.inputs['Metallic'])
    else:
        p.inputs['Base Color'].default_value = (*base, 1)
        p.inputs['Roughness'].default_value = 0.4
        p.inputs['Metallic'].default_value = metal
    # vertikale Wellung (fuer Waende/Tore)
    wave = b.n("ShaderNodeTexWave", wave_type='BANDS', bands_direction='X')
    b.l(P, wave.inputs['Vector'])
    wave.inputs['Scale'].default_value = 0.0
    # Wellung: Sinus ueber x (Wand) -- Periode 0.15 m
    s = b.math('SINE', b.math('MULTIPLY', px, 2 * math.pi / 0.15))
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 0.8
    bump.inputs['Distance'].default_value = 0.02
    b.l(s, bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    m.diffuse_color = (*base, 1)
    return m


def build_hangar(origin=(-8.0, 26.0, 0.0), rot_z=0.0):
    M_roof = hangar_material(False)
    M_wall = hangar_material(False)
    M_door = hangar_material(True)
    M_dark = simple_mat("HangarInterior", (0.03, 0.03, 0.028), rough=0.9)
    M_conc = new_mat("Concrete")
    b = NB(M_conc); p = b.principled(); P = b.coords().outputs['Object']
    n = b.noise(P, 1.5, 6.0, 0.6).outputs['Fac']
    cbase = (0.33, 0.32, 0.30) if STYLE == "B" else (0.55, 0.55, 0.53)
    col = b.mix(b.maprange(n, 0.3, 0.8, 0, 0.6), cbase, (0.12, 0.11, 0.09), 'MULTIPLY' if STYLE == "B" else 'MIX')
    b.l(col, p.inputs['Base Color'])
    p.inputs['Roughness'].default_value = 0.85

    root = bpy.data.objects.new("Hangar", None)
    COL.objects.link(root)
    root.location = origin
    root.rotation_euler = (0, 0, rot_z)
    A, Bh, D = 13.0, 9.0, 24.0
    # Bogendach mit echter Wellung
    dense = 4000
    ph = np.linspace(0, math.pi, dense)
    bx, bz = A * np.cos(ph), Bh * np.sin(ph)
    seg = np.hypot(np.diff(bx), np.diff(bz))
    L = np.concatenate([[0], np.cumsum(seg)])
    period = 0.20
    ns = int(L[-1] / (period / 8))
    Ls = np.linspace(0, L[-1], ns)
    phs = np.interp(Ls, L, ph)
    rings = []
    ys = [0.0, D]
    for y in ys:
        ring = []
        for k, a in enumerate(phs):
            nx_, nz_ = math.cos(a) / A, math.sin(a) / Bh
            nl = math.hypot(nx_, nz_)
            off = 0.035 * math.sin(2 * math.pi * Ls[k] / period)
            ring.append((A * math.cos(a) + off * nx_ / nl, y, Bh * math.sin(a) + off * nz_ / nl))
        rings.append(ring)
    v, f = loft(rings, closed=False)
    roof = mesh_obj("HangarRoof", v, f, M_roof, parent=root, recalc=False)
    # Dach-Material braucht Wellung entlang Bogen -> Bump aus Geometrie reicht

    # Stirnwaende (Streifen, vorne mit Toroeffnung)
    def end_wall(y, opening):
        verts, faces = [], []
        xs = np.linspace(-A, A, 105)
        for k in range(len(xs) - 1):
            x0, x1 = xs[k], xs[k + 1]
            z0t = Bh * math.sqrt(max(0, 1 - (x0 / A) ** 2)) + 0.06
            z1t = Bh * math.sqrt(max(0, 1 - (x1 / A) ** 2)) + 0.06
            zb = 0.0
            xm = 0.5 * (x0 + x1)
            if opening and abs(xm) < 9.0:
                zb = 6.6
            if z0t <= zb and z1t <= zb:
                continue
            o = len(verts)
            verts += [(x0, y, zb), (x1, y, zb), (x1, y, max(z1t, zb)), (x0, y, max(z0t, zb))]
            faces.append((o, o + 1, o + 2, o + 3))
        return verts, faces
    v, f = end_wall(0.0, True)
    mesh_obj("HangarFront", v, f, M_wall, parent=root, smooth=False, recalc=False)
    v, f = end_wall(D - 0.05, False)
    mesh_obj("HangarBack", v, f, M_wall, parent=root, smooth=False, recalc=False)
    # Torsturz
    box("HangarLintel", (0, -0.12, 6.75), (18.4, 0.25, 0.35), M_door, parent=root, bevel=0.03)
    # Schiebetore (halb offen)
    box("HangarDoorL", (-7.2, -0.35, 3.3), (4.6, 0.12, 6.6), M_door, parent=root, bevel=0.03)
    box("HangarDoorL2", (-11.0, -0.55, 3.0), (4.4, 0.12, 6.0), M_door, parent=root, bevel=0.03)
    box("HangarDoorR", (11.2, -0.35, 3.0), (4.4, 0.12, 6.0), M_door, parent=root, bevel=0.03)
    # Torschiene
    box("DoorRail", (0, -0.45, 6.62), (27.0, 0.12, 0.12), M_dark, parent=root)
    # Innenraum dunkel (Boden + Rueckwand innen)
    box("HangarFloor", (0, D / 2, 0.02), (2 * A - 0.2, D - 0.2, 0.04), M_conc, parent=root)
    # Vorfeld Beton
    box("Apron", (0, -9.0, 0.0), (24.0, 18.0, 0.06), M_conc, parent=root)
    # Fenster-/Lichtband und Schild-Brett ohne Text
    box("Sign", (0, -0.2, 7.6), (5.5, 0.08, 0.8), M_door, parent=root, bevel=0.02)
    box("Workbench", (-8.0, D - 2.0, 0.5), (4.0, 1.0, 1.0), M_door, parent=root, bevel=0.03)
    box("Shelf", (8.0, D - 1.0, 1.4), (5.0, 0.6, 2.8), M_door, parent=root, bevel=0.03)
    # schwaches Innenlicht
    ld = bpy.data.lights.new("HangarLight", 'AREA')
    ld.energy = 1500 if STYLE == "B" else 800
    ld.size = 12
    ld.color = (1.0, 0.8, 0.55)
    lo = bpy.data.objects.new("HangarLight", ld); COL.objects.link(lo)
    lo.parent = root
    lo.location = (0, 10, 7.5)
    return root


def build_truck(loc, rot_z):
    M_body = new_mat("TruckPaint")
    b = NB(M_body); p = b.principled(); P = b.coords().outputs['Object']
    base = (0.10, 0.12, 0.05) if STYLE == "B" else (0.14, 0.30, 0.08)
    if STYLE == "B":
        n = b.noise(P, 3.0, 6.0, 0.6).outputs['Fac']
        col = b.mix(b.maprange(n, 0.4, 0.8, 0, 0.5), base, (0.12, 0.09, 0.05))
        pz = b.sep(P)[2]
        col = b.mix(b.maprange(pz, 0.2, 1.0, 0.7, 0.0), col, (0.13, 0.10, 0.07))
        b.l(col, p.inputs['Base Color'])
        p.inputs['Roughness'].default_value = 0.65
    else:
        p.inputs['Base Color'].default_value = (*base, 1)
        p.inputs['Roughness'].default_value = 0.35
        p.inputs['Coat Weight'].default_value = 0.3
    M_tank = simple_mat("TankRed", (0.35, 0.03, 0.02) if STYLE == "B" else (0.75, 0.05, 0.02), rough=0.5 if STYLE == "B" else 0.3)
    M_rub = simple_mat("TruckRubber", (0.02, 0.02, 0.02), rough=0.9)
    M_glass = simple_mat("TruckGlass", (0.05, 0.06, 0.07), rough=0.05, metal=0.0)
    M_chrome = simple_mat("TruckChrome", (0.7, 0.7, 0.7), rough=0.2, metal=1.0)
    M_hub2 = simple_mat("TruckHub", (0.08, 0.08, 0.07), rough=0.6)
    root = bpy.data.objects.new("FuelTruck", None)
    COL.objects.link(root)
    root.location = loc
    root.rotation_euler = (0, 0, rot_z)
    box("Chassis", (0, 0, 0.75), (1.6, 6.6, 0.25), M_hub2, parent=root)
    box("Hood", (0, -2.55, 1.35), (1.15, 1.5, 0.95), M_body, parent=root, bevel=0.12, seg=4)
    box("Grille", (0, -3.31, 1.3), (0.95, 0.04, 0.8), M_chrome, parent=root, bevel=0.03)
    box("Cab", (0, -1.2, 1.75), (1.9, 1.3, 1.75), M_body, parent=root, bevel=0.1, seg=4)
    box("Windshield", (0, -1.86, 2.15), (1.6, 0.03, 0.6), M_glass, parent=root, bevel=0.02)
    for s in (1, -1):
        box("SideWin", (s * 0.955, -1.2, 2.15), (0.03, 0.8, 0.55), M_glass, parent=root, bevel=0.02)
        box("Fender", (s * 0.95, -2.55, 1.05), (0.45, 1.25, 0.12), M_body, parent=root, bevel=0.05)
        cylinder("Headlamp", (s * 0.8, -3.15, 1.45), (s * 0.8, -3.35, 1.45), 0.12, M_chrome, parent=root)
    # Tank (elliptischer Zylinder)
    rings = []
    for y in np.linspace(-0.3, 3.1, 2):
        ring = []
        for j in range(40):
            a = 2 * math.pi * j / 40
            ring.append((1.0 * math.cos(a), y, 1.85 + 0.78 * math.sin(a)))
        rings.append(ring)
    v, f = loft(rings, closed=True, cap_start=True, cap_end=True)
    tank = mesh_obj("Tank", v, f, M_tank, parent=root)
    bm_ = tank.modifiers.new("Bevel", "BEVEL"); bm_.width = 0.15; bm_.segments = 4; bm_.limit_method = 'ANGLE'
    for y in (0.2, 1.4, 2.6):
        rr = []
        for j in range(41):
            a = 2 * math.pi * j / 40
            rr.append((1.03 * math.cos(a), y, 1.85 + 0.81 * math.sin(a)))
        curve_obj("TankBand", rr, 0.025, M_hub2, parent=root)
    cylinder("Hose", (-1.0, 2.9, 1.2), (-1.0, 3.2, 1.0), 0.06, M_rub, parent=root)
    box("RearFender", (0, 2.1, 1.0), (2.1, 2.0, 0.1), M_hub2, parent=root)
    for (y, dual) in ((-2.55, False), (1.6, True), (2.7, True)):
        for s in (1, -1):
            tire("TruckTire", (s * 0.85, y, 0.48), 0.33, 0.14, 0.12, M_rub, axis='X', parent=root, seg=32)
            cylinder("TruckHub", (s * 0.75, y, 0.48), (s * 0.97, y, 0.48), 0.22, M_hub2, parent=root, seg=20)
    box("Bumper", (0, -3.45, 0.75), (1.9, 0.15, 0.15), M_chrome, parent=root, bevel=0.03)
    return root


def build_crates(origin, rot_z=0.0, n_crates=8, n_drums=5):
    M_wood = new_mat("CratePaint")
    b = NB(M_wood); p = b.principled(); P = b.coords().outputs['Object']
    base = (0.12, 0.14, 0.06) if STYLE == "B" else (0.20, 0.32, 0.08)
    n = b.noise(b.scalevec(P, 1, 8, 1), 6.0, 6.0, 0.6).outputs['Fac']
    col = b.mix(b.maprange(n, 0.3, 0.8, 0, 0.45 if STYLE == "B" else 0.1), base, (0.20, 0.13, 0.06))
    b.l(col, p.inputs['Base Color'])
    p.inputs['Roughness'].default_value = 0.8
    M_band = simple_mat("CrateBand", PAL['yellow'], rough=0.6)
    M_drum = worn_metal("Drum", (0.30, 0.05, 0.03) if STYLE == "B" else (0.7, 0.08, 0.02), rough=0.45, metal=0.3, dirt=0.6)
    M_drum2 = worn_metal("Drum2", (0.12, 0.14, 0.07), rough=0.5, metal=0.3, dirt=0.6)
    root = bpy.data.objects.new("Crates", None)
    COL.objects.link(root)
    root.location = origin
    root.rotation_euler = (0, 0, rot_z)
    rng = random.Random(11)
    k = 0
    for row in range(3):
        for col_ in range(3):
            if k >= n_crates:
                break
            for lay in range(2 if (row + col_) % 2 == 0 else 1):
                x = col_ * 0.95 + rng.uniform(-0.05, 0.05)
                y = row * 0.55 + rng.uniform(-0.03, 0.03)
                z = 0.19 + lay * 0.38
                c = box("AmmoCrate", (x, y, z), (0.88, 0.48, 0.37), M_wood, parent=root, bevel=0.015,
                        rot=(0, 0, math.radians(rng.uniform(-6, 6))))
                box("CrateStripe", (x, y - 0.245, z + 0.08), (0.7, 0.01, 0.05), M_band, parent=c)
                c.children[0].location = (0, -0.245, 0.08)
                c.children[0].rotation_euler = (0, 0, 0)
            k += 1
    for d in range(n_drums):
        x = 3.2 + (d % 3) * 0.66 + rng.uniform(-0.04, 0.04)
        y = (d // 3) * 0.66
        mat = M_drum if d % 2 == 0 else M_drum2
        cylinder("Drum", (x, y, 0.0), (x, y, 0.88), 0.29, mat, parent=root, seg=28)
        for zz in (0.29, 0.58):
            rr = [(x + 0.3 * math.cos(a), y + 0.3 * math.sin(a), zz) for a in np.linspace(0, 2 * math.pi, 33)]
            curve_obj("DrumRib", rr, 0.012, mat, parent=root)
    return root


# ----------------------------------------------------------------------------
# Welt / Licht
# ----------------------------------------------------------------------------
def setup_world(sun_elev, sun_rot, strength=1.0, sun_strength=4.0, sun_color=(1, 1, 1), sun_size=1.0):
    w = bpy.data.worlds.new("Sky")
    scene.world = w
    nt = w.node_tree
    bg = nt.nodes.get('Background')
    sky = nt.nodes.new("ShaderNodeTexSky")
    try:
        sky.sky_type = 'MULTIPLE_SCATTERING'
    except Exception:
        sky.sky_type = 'NISHITA'
    sky.sun_disc = False
    sky.sun_elevation = math.radians(sun_elev)
    sky.sun_rotation = math.radians(sun_rot)
    sky.altitude = 200.0
    sky.air_density = 1.0
    sky.aerosol_density = 1.6 if STYLE == "B" else 0.8
    nt.links.new(sky.outputs[0], bg.inputs[0])
    bg.inputs[1].default_value = strength
    # Sonne als Lampe (weicher Schatten)
    ld = bpy.data.lights.new("Sun", 'SUN')
    ld.energy = sun_strength
    ld.angle = math.radians(sun_size)
    ld.color = sun_color
    so = bpy.data.objects.new("Sun", ld)
    COL.objects.link(so)
    # Richtung passend zur Sky-Textur: Sky-Sonne liegt bei Azimut sun_rot
    # (gemessen von +Y Richtung -X?) -> wir richten Lampe aus Richtungsvektor aus
    el = math.radians(sun_elev)
    az = math.radians(sun_rot)
    d = Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
    sky_dir = d
    so.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    return sky, so


def setup_render(samples, out, motion_blur=False, freestyle=False):
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.05
    scene.cycles.use_denoising = True
    try:
        scene.cycles.denoiser = 'OPENIMAGEDENOISE'
    except Exception:
        pass
    scene.cycles.max_bounces = 6
    scene.cycles.diffuse_bounces = 2
    scene.cycles.glossy_bounces = 3
    scene.cycles.transmission_bounces = 6
    scene.cycles.volume_bounces = 0
    scene.cycles.caustics_reflective = False
    scene.cycles.caustics_refractive = False
    scene.cycles.blur_glossy = 1.0
    scene.cycles.volume_step_rate = 16.0
    scene.cycles.volume_max_steps = 48
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = ARGS["res"]
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGB'
    scene.render.filepath = out
    scene.view_settings.view_transform = 'AgX' if STYLE == "B" else 'Standard'
    for look in (("None",) if STYLE == "A" else ("AgX - Medium High Contrast", "AgX - Base Contrast")):
        try:
            scene.view_settings.look = look
            break
        except Exception:
            pass
    scene.view_settings.exposure = -1.35 if STYLE == "A" else (-0.75 if SHOT == "C" else -0.15)
    scene.render.use_motion_blur = motion_blur
    if motion_blur:
        scene.render.motion_blur_shutter = 0.5
    if freestyle:
        scene.render.use_freestyle = True
        scene.render.line_thickness_mode = 'ABSOLUTE'
        scene.render.line_thickness = 1.1
        vl = scene.view_layers[0]
        vl.use_freestyle = True
        fs = vl.freestyle_settings
        ls = fs.linesets[0] if len(fs.linesets) else fs.linesets.new("Lines")
        if ls.linestyle is None:
            ls.linestyle = bpy.data.linestyles.new("LineStyle")
        ls.select_by_visibility = True
        ls.select_silhouette = True
        ls.select_border = True
        ls.select_crease = True
        fs.crease_angle = math.radians(120)
        ls.linestyle.color = (0.02, 0.03, 0.02)
        ls.linestyle.thickness = 1.1
        ls.linestyle.alpha = 0.85


def add_camera(loc, target, lens=50, dof=None):
    cd = bpy.data.cameras.new("Cam")
    cd.lens = lens
    cd.sensor_width = 36
    co = bpy.data.objects.new("Cam", cd)
    COL.objects.link(co)
    co.location = loc
    d = Vector(target) - Vector(loc)
    co.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    if dof:
        cd.dof.use_dof = True
        cd.dof.focus_distance = d.length
        cd.dof.aperture_fstop = dof
    cd.clip_end = 20000
    scene.camera = co
    return co


# ----------------------------------------------------------------------------
# Flug-Szene
# ----------------------------------------------------------------------------
def fields_material():
    m = new_mat("Fields")
    b = NB(m)
    p = b.principled()
    P = b.coords().outputs['Object']
    vor = b.n("ShaderNodeTexVoronoi")
    warp = b.noise(P, 0.002, 2.0).outputs['Color']
    vm = b.n("ShaderNodeMix", data_type='VECTOR')
    vm.inputs[0].default_value = 0.0
    b.l(P, vm.inputs[4]); b.l(warp, vm.inputs[5])
    vm.inputs[0].default_value = 0.0
    b.l(P, vor.inputs['Vector'])
    vor.inputs['Scale'].default_value = 0.006
    ramp = b.n("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.interpolation = 'CONSTANT'
    cols = [(0.03, 0.08, 0.012), (0.10, 0.13, 0.025), (0.17, 0.12, 0.045), (0.035, 0.10, 0.015),
            (0.22, 0.17, 0.06), (0.06, 0.12, 0.02), (0.12, 0.08, 0.04)]
    cr.elements[0].color = (*cols[0], 1)
    cr.elements[1].position = 1.0
    cr.elements[1].color = (*cols[-1], 1)
    for k, c in enumerate(cols[1:-1]):
        e = cr.elements.new((k + 1) / (len(cols) - 1))
        e.color = (*c, 1)
    b.l(vor.outputs['Color'], ramp.inputs[0])
    # Separate R channel for ramp input: use color -> bw
    rgb2bw = b.n("ShaderNodeRGBToBW")
    b.l(vor.outputs['Color'], rgb2bw.inputs[0])
    b.l(rgb2bw.outputs[0], ramp.inputs[0])
    col = ramp.outputs[0]
    # Waldflaechen
    fn = b.noise(P, 0.0012, 6.0, 0.6).outputs['Fac']
    forest = b.maprange(fn, 0.55, 0.58)
    col = b.mix(forest, col, (0.015, 0.035, 0.012))
    # Feldraender (dunklere Linien)
    edge = b.maprange(vor.outputs['Distance'], 0.0, 0.05, 0.0, 1.0)
    # Fein-Variation
    fv = b.noise(P, 0.05, 5.0, 0.6).outputs['Fac']
    col = b.mix(b.maprange(fv, 0.3, 0.7, 0.0, 0.3), col, (0.03, 0.03, 0.02), 'MULTIPLY')
    # Hoehen-Dunst nach Kameradistanz
    cam = b.n("ShaderNodeCameraData")
    dist = cam.outputs['View Distance']
    haze = b.maprange(dist, 1200, 16000, 0.0, 0.85, smooth=True)
    hazec = (0.36, 0.48, 0.66)
    p.inputs['Roughness'].default_value = 0.9
    b.l(col, p.inputs['Base Color'])
    # Dunst als Emission + Abdunklung der Albedo
    em = b.mix(haze, (0, 0, 0), hazec)
    b.l(em, p.inputs['Emission Color'])
    p.inputs['Emission Strength'].default_value = 1.3
    alb = b.mix(haze, col, (0, 0, 0))
    b.l(alb, p.inputs['Base Color'])
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 0.5
    b.l(b.noise(P, 0.03, 6.0).outputs['Fac'], bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    return m


def cloud_material():
    """Guenstige Oberflaechen-Wolke (statt Volumen): weich gestreut + Kantentransparenz."""
    m = new_mat("Cloud")
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type != 'OUTPUT_MATERIAL':
            nt.nodes.remove(n)
    out = [n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'][0]
    b = NB(m)
    tc = b.coords()
    lw = b.n("ShaderNodeLayerWeight")
    lw.inputs['Blend'].default_value = 0.35
    nz = b.noise(tc.outputs['Object'], 3.0, 6.0, 0.6).outputs['Fac']
    edge = b.maprange(lw.outputs['Facing'], 0.35, 0.95, 1.0, 0.0)
    alpha = b.math('MULTIPLY', edge, b.maprange(nz, 0.35, 0.6, 0.4, 1.0))
    diff = b.n("ShaderNodeBsdfDiffuse")
    diff.inputs['Color'].default_value = (0.82, 0.83, 0.86, 1)
    trl = b.n("ShaderNodeBsdfTranslucent")
    trl.inputs['Color'].default_value = (0.9, 0.9, 0.92, 1)
    mx = b.n("ShaderNodeMixShader")
    mx.inputs[0].default_value = 0.35
    b.l(diff.outputs[0], mx.inputs[1]); b.l(trl.outputs[0], mx.inputs[2])
    em = b.n("ShaderNodeEmission")
    em.inputs['Color'].default_value = (0.55, 0.62, 0.75, 1)
    em.inputs['Strength'].default_value = 0.35
    add = b.n("ShaderNodeAddShader")
    b.l(mx.outputs[0], add.inputs[0]); b.l(em.outputs[0], add.inputs[1])
    tr = b.n("ShaderNodeBsdfTransparent")
    mx2 = b.n("ShaderNodeMixShader")
    b.l(alpha, mx2.inputs[0]); b.l(tr.outputs[0], mx2.inputs[1]); b.l(add.outputs[0], mx2.inputs[2])
    b.l(mx2.outputs[0], out.inputs['Surface'])
    return m


def cloud_mesh(M_cloud, seed):
    """Cumulus-Cluster aus mehreren verbeulten Kugeln, flacher Boden."""
    rng = random.Random(seed)
    bm = bmesh.new()
    for k in range(9):
        r = rng.uniform(0.35, 0.65)
        cx, cy = rng.uniform(-0.8, 0.8), rng.uniform(-0.5, 0.5)
        cz = r * 0.45 + rng.uniform(0.0, 0.35) * (1 - abs(cx))
        ret = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=r)
        for v in ret['verts']:
            n = v.co.normalized()
            d = 1 + 0.12 * math.sin(9 * n.x + seed) * math.sin(7 * n.y) + 0.08 * math.sin(17 * n.z + 3 * n.x)
            v.co = Vector((cx, cy, cz)) + v.co * d
            if v.co.z < 0.0:
                v.co.z *= 0.15
    me = bpy.data.meshes.new("CloudBlob%d" % seed)
    bm.to_mesh(me); bm.free()
    me.shade_smooth()
    me.materials.append(M_cloud)
    return me


def build_flight_world():
    M_f = fields_material()
    def h(X, Y):
        return value_noise_2d(X, Y, 6, 1 / 2500.0, 9) * 420 - 100 + value_noise_2d(X, Y, 3, 1 / 300.0, 4) * 30
    terr = grid_terrain("Terrain", 40000, 360, h, M_f)
    # Fluss
    M_cloud = cloud_material()
    rng = random.Random(5)
    cmes = [cloud_mesh(M_cloud, sd) for sd in range(4)]
    return terr, cmes


def place_cloud(cmes, loc, size):
    ob = bpy.data.objects.new("Cloud", random.choice(cmes))
    COL.objects.link(ob)
    ob.location = loc
    ob.scale = (size, size * 0.9, size * 0.7)
    ob.rotation_euler = (0, 0, random.uniform(0, 6.28))
    ob.visible_shadow = True
    return ob


# ----------------------------------------------------------------------------
# Shots
# ----------------------------------------------------------------------------
def shot_ground(kind):
    root, prop = build_fighter(pilot=False)
    ang, z0 = ground_attitude(root)
    build_airfield()
    if kind in ("A", "B"):
        root.location = (0, 0, z0)
        root.rotation_euler = (ang, 0, math.radians(-25))
        build_hangar(origin=(-6.0, 24.0, 0.0), rot_z=math.radians(-8))
        build_truck((-12.0, 8.0, 0.0), math.radians(70))
        build_crates((5.5, 6.0, 0.0), math.radians(15))
        cam = add_camera((7.6, -9.6, 1.35), (-0.4, 0.4, 1.05), lens=40, dof=8.0)
        if kind == "A":
            setup_world(52, 205, strength=1.0, sun_strength=4.5, sun_size=1.5)
        else:
            setup_world(11, 292, strength=0.55, sun_strength=6.0, sun_color=(1.0, 0.72, 0.48), sun_size=1.5)
    else:  # D: Bodenbetrieb
        root.location = (-1.0, 11.0, z0)
        root.rotation_euler = (ang, 0, math.radians(-22))
        build_hangar(origin=(-2.0, 26.0, 0.0), rot_z=0.0)
        build_truck((5.8, 15.0, 0.0), math.radians(-150))
        build_crates((-10.5, 6.2, 0.0), math.radians(25))
        cam = add_camera((-10.5, -1.5, 1.9), (-1.2, 11.5, 1.6), lens=26, dof=11.0)
        setup_world(20, 230, strength=0.9, sun_strength=4.5, sun_color=(1.0, 0.86, 0.70), sun_size=2.0)
    prop.rotation_euler = (0, math.radians(17), 0)
    if kind == "A":
        add_outlines(root)
    return root


def shot_flight():
    root, prop = build_fighter(pilot=True, gear=False)
    terr, cme = build_flight_world()
    alt = 1100.0
    root.location = (0, 0, alt)
    root.rotation_euler = Euler((math.radians(6), math.radians(-35), math.radians(18)), 'YXZ')
    rng = random.Random(21)
    for k in range(30):
        x = rng.uniform(-1800, 1800)
        y = rng.uniform(300, 4000)
        z = alt - rng.uniform(250, 600)
        s_ = rng.uniform(70, 220)
        place_cloud(cme, (x, y, z), s_)
    for (x, y, z, s_) in ((-260, 520, alt - 40, 120), (380, 900, alt - 140, 200)):
        place_cloud(cme, (x, y, z), s_)
    cam = add_camera((-11.5, -12.5, alt + 4.2), (0.5, 0.6, alt - 0.6), lens=42)
    setup_world(38, 210, strength=1.0, sun_strength=4.5, sun_color=(1.0, 0.93, 0.85), sun_size=1.0)
    # Bewegung: Flugzeug + Kamera bewegen sich gemeinsam, Propeller dreht
    scene.frame_start = 1
    scene.frame_end = 2
    scene.render.fps = 24
    v = Vector((0.3, -5.2, -0.4))  # m pro Frame (~125 m/s)
    for obj in (root, cam):
        obj.keyframe_insert("location", frame=1)
        obj.location = obj.location + v
        obj.keyframe_insert("location", frame=2)
        obj.location = obj.location - v
    prop.rotation_euler = (0, 0, 0)
    prop.keyframe_insert("rotation_euler", frame=1)
    prop.rotation_euler = (0, math.radians(-560), 0)
    prop.keyframe_insert("rotation_euler", frame=2)
    for obj in (root, cam, prop):
        if obj.animation_data and obj.animation_data.action:
            try:
                for fc in obj.animation_data.action.fcurves:
                    for kp in fc.keyframe_points:
                        kp.interpolation = 'LINEAR'
            except Exception:
                pass
    scene.frame_set(1)
    # Kamera minimal geneigt (Dutch angle)
    cam.rotation_euler.rotate_axis('Z', math.radians(-4))
    return root


def export_glb(path):
    root, prop = build_fighter(pilot=False)
    # Einfache Export-Materialien (prozedurale Shader sind nicht glTF-exportierbar)
    flat = {
        "Paint_fus": PAL['top'], "Paint_wing": PAL['top'], "Paint_tail": PAL['top'],
    }
    for m in bpy.data.materials:
        if m.name in flat:
            nt = m.node_tree
            p = nt.nodes.get("Principled BSDF")
            for l in list(p.inputs['Base Color'].links): nt.links.remove(l)
            for l in list(p.inputs['Roughness'].links): nt.links.remove(l)
            for l in list(p.inputs['Metallic'].links): nt.links.remove(l)
            for l in list(p.inputs['Normal'].links): nt.links.remove(l)
            p.inputs['Base Color'].default_value = (*flat[m.name], 1)
            p.inputs['Roughness'].default_value = 0.55
            p.inputs['Metallic'].default_value = 0.0
        else:
            nt = m.node_tree
            p = nt.nodes.get("Principled BSDF") if nt else None
            if p and p.inputs['Base Color'].links:
                for l in list(p.inputs['Base Color'].links): nt.links.remove(l)
                p.inputs['Base Color'].default_value = m.diffuse_color
    # Kurven (Haubenrahmen, Antenne) in Meshes umwandeln
    bpy.ops.object.select_all(action='DESELECT')
    for ob in list(scene.objects):
        if ob.type == 'CURVE':
            dg = bpy.context.evaluated_depsgraph_get()
            me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
            no = bpy.data.objects.new(ob.name + "_mesh", me)
            COL.objects.link(no)
            no.parent = ob.parent
            no.matrix_parent_inverse = ob.matrix_parent_inverse
            no.matrix_world = ob.matrix_world
            bpy.data.objects.remove(ob)
    for ob in scene.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True)
    print("GLB exportiert:", path)


# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------
if ARGS["export_glb"]:
    export_glb(ARGS["export_glb"])
else:
    t0 = time.time()
    if SHOT in ("A", "B", "D"):
        shot_ground(SHOT)
        setup_render(ARGS["samples"], ARGS["out"], motion_blur=False, freestyle=False)
    elif SHOT == "C":
        shot_flight()
        setup_render(ARGS["samples"], ARGS["out"], motion_blur=True, freestyle=False)
    t1 = time.time()
    bpy.ops.render.render(write_still=True)
    t2 = time.time()
    print("BUILD_TIME %.1f s, RENDER_TIME %.1f s" % (t1 - t0, t2 - t1))
