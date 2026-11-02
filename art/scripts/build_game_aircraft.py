# -*- coding: utf-8 -*-
"""
Spielfertiges Modell des Jaegers "Falke" (fighter_t1) fuer Godot 4.

Aufruf (headless, Cycles CPU):
  blender -b -P build_game_aircraft.py -- --build            # Geometrie, UVs, Bake, Export (eigen + Gegner)
  blender -b -P build_game_aircraft.py -- --build --quick    # schneller Testlauf (512er Texturen)
  blender -b -P build_game_aircraft.py -- --render-check [--glb pfad] [--tag name]
  blender -b -P build_game_aircraft.py -- --add-svc          # M3: nur svc_*-Marker in vorhandene GLBs
                                                             #     einfuegen (verlustfrei, ohne Neu-Bake)

Ergebnisse:
  models/fighter_t1_game.glb, models/fighter_t1_game_enemy.glb, models/fighter_t1_rig.json
  textures/fighter_t1_*  (Albedo/Normal/ORM je Atlas, Abzeichen, Propellerscheibe)

Konventionen (Blender intern): Z oben, Nase -Y, Meter. glTF-Export mit +Y oben
=> Godot: Y oben, Nase +Z, Pilot-links = +X. Ursprung = Schwerpunkt (28 % MAC).
Generisches Eigendesign, fiktive Abzeichen.
"""
import bpy, bmesh, math, sys, os, json, time
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ART = os.environ.get("ART_DIR") or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
MODELS = os.path.join(ART, "models")
TEX = os.path.join(ART, "textures")
PREV = os.path.join(ART, "previews")
for d in (MODELS, TEX, PREV):
    os.makedirs(d, exist_ok=True)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OPT = {"build": "--build" in argv, "quick": "--quick" in argv,
       "render": "--render-check" in argv, "add_svc": "--add-svc" in argv, "closeups": "--closeups" in argv, "glb": None, "tag": "own"}
for k, a in enumerate(argv):
    if a == "--glb": OPT["glb"] = argv[k + 1]
    if a == "--tag": OPT["tag"] = argv[k + 1]

TEXSIZE = 512 if OPT["quick"] else 2048
DETSIZE = 256 if OPT["quick"] else 1024
SAMPLES = dict(color=1 if OPT["quick"] else 4, normal=1 if OPT["quick"] else 4, ao=4 if OPT["quick"] else 24)


# ============================================================================
# Allgemeine Helfer
# ============================================================================
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def col():
    return bpy.context.scene.collection


def C(v):
    """Blender (Z oben, Nase -Y) -> glTF/Godot (Y oben, Nase +Z)"""
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def mesh_from(name, verts, faces, mat=None, smooth=True, sharp_angle=40.0):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(map(float, v)) for v in verts], [], [tuple(f) for f in faces])
    me.validate(clean_customdata=False)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6) if False else None
    ngons = [f for f in bm.faces if len(f.verts) > 4]
    if ngons:
        bmesh.ops.triangulate(bm, faces=ngons, quad_method='BEAUTY', ngon_method='BEAUTY')
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    if smooth:
        me.shade_smooth()
        try:
            me.set_sharp_from_angle(angle=math.radians(sharp_angle))
        except Exception:
            pass
    ob = bpy.data.objects.new(name, me)
    col().objects.link(ob)
    if mat is not None:
        me.materials.append(mat)
    return ob


def tag(ob, group, node):
    ob["group"] = group
    ob["node"] = node
    return ob


def loft(rings, closed=True, cap_start=False, cap_end=False):
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
        faces.append(tuple(range(M))[::-1])
    if cap_end:
        b = (n - 1) * M
        faces.append(tuple(b + j for j in range(M)))
    return verts, faces


def catmull(points, per_seg=12):
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


def naca_yt(x, t):
    x = np.asarray(x, dtype=float)
    return 5 * t * (0.2969 * np.sqrt(np.maximum(x, 0)) - 0.1260 * x - 0.3516 * x ** 2 + 0.2843 * x ** 3 - 0.1036 * x ** 4)


def naca_yc(x, m, p):
    x = np.asarray(x, dtype=float)
    if m == 0:
        return np.zeros_like(x)
    return np.where(x < p, m / p ** 2 * (2 * p * x - x ** 2), m / (1 - p) ** 2 * ((1 - 2 * p) + 2 * p * x - x ** 2))


def prof_full(m, p, t, n):
    b = np.linspace(0, math.pi, n)
    x = 0.5 * (1 - np.cos(b))
    yc, yt = naca_yc(x, m, p), naca_yt(x, t)
    up = list(zip(x, yc + yt))[::-1]
    lo = list(zip(x[1:], (yc - yt)[1:]))
    return up + lo


def _hinge(m, p, t, xh):
    return float(naca_yc(xh, m, p)), float(naca_yt(xh, t))


def prof_front(m, p, t, n, xh, gapn, narc=6):
    """Hauptflaeche bis zur Scharnierlinie, hinten konkave Mulde (Ruder-Nase passt hinein)."""
    bh = math.acos(1 - 2 * xh)
    b = np.linspace(0, bh, n)
    x = 0.5 * (1 - np.cos(b))
    x[-1] = xh
    yc, yt = naca_yc(x, m, p), naca_yt(x, t)
    up = list(zip(x, yc + yt))[::-1]
    lo = list(zip(x[1:], (yc - yt)[1:]))
    vc, r = _hinge(m, p, t, xh)
    arc = []
    for k in range(1, narc + 1):
        ph = math.pi * k / (narc + 1)
        th = -math.pi / 2 - ph
        rho = r + gapn * math.sin(ph)
        arc.append((xh + rho * math.cos(th), vc + rho * math.sin(th)))
    return up + lo + arc


def prof_rear(m, p, t, n, xh, narc=6):
    """Ruder: Hinterteil ab Scharnier, vorne Halbkreis um die Drehachse."""
    bh = math.acos(1 - 2 * xh)
    b = np.linspace(bh, math.pi, n)
    x = 0.5 * (1 - np.cos(b))
    x[0] = xh
    yc, yt = naca_yc(x, m, p), naca_yt(x, t)
    up = list(zip(x, yc + yt))[::-1]
    lo = list(zip(x, yc - yt))
    vc, r = _hinge(m, p, t, xh)
    arc = []
    for k in range(1, narc + 1):
        ph = math.pi * k / (narc + 1)
        th = math.pi / 2 + ph
        arc.append((xh + r * math.cos(th), vc + r * math.sin(th)))
    return up + arc + lo


def tube(points, radius, sides=6, caps=True):
    pts = [Vector(p) for p in points]
    rings = []
    for i, p in enumerate(pts):
        if i == 0:
            T = (pts[1] - pts[0])
        elif i == len(pts) - 1:
            T = (pts[-1] - pts[-2])
        else:
            T = (pts[i + 1] - pts[i - 1])
        T.normalize()
        ref = Vector((1, 0, 0)) if abs(T.x) < 0.9 else Vector((0, 0, 1))
        N = T.cross(ref).normalized()
        B = T.cross(N)
        rings.append([tuple(p + radius * (math.cos(2 * math.pi * k / sides) * N + math.sin(2 * math.pi * k / sides) * B))
                      for k in range(sides)])
    return loft(rings, closed=True, cap_start=caps, cap_end=caps)


def cyl(p0, p1, r, seg=12, r1=None, caps=True):
    p0, p1 = Vector(p0), Vector(p1)
    r1 = r if r1 is None else r1
    q = (p1 - p0).to_track_quat('Z', 'Y')
    rings = []
    for pp, rr in ((p0, r), (p1, r1)):
        rings.append([tuple(q @ Vector((rr * math.cos(2 * math.pi * j / seg), rr * math.sin(2 * math.pi * j / seg), 0)) + pp)
                      for j in range(seg)])
    return loft(rings, closed=True, cap_start=caps, cap_end=caps)


def box_geo(center, size, basis=None):
    c = Vector(center)
    B = basis or Matrix.Identity(3)
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    vs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                vs.append(tuple(c + B @ Vector((sx * hx, sy * hy, sz * hz))))
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return vs, faces


def rbox_geo(center, size, rad, seg=2):
    """Box mit gerundeten Kanten (Superellipsoid-artig ueber Loft)."""
    cx, cy, cz = center
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    rings = []
    ny = 2 + 2 * seg
    ys = []
    for k in range(seg + 1):
        a = math.pi / 2 * k / seg
        ys.append((-sy + rad - rad * math.cos(a), max(0.05, math.sin(a))))
    ys = ys + [(sy - rad + rad * math.cos(math.pi / 2 * k / seg), max(0.05, math.sin(math.pi / 2 * k / seg))) for k in range(seg, -1, -1)]
    for (y, f) in ys:
        ring = []
        hx, hz = (sx - rad) + rad * f, (sz - rad) + rad * f
        for j in range(16):
            a = 2 * math.pi * j / 16
            c_, s_ = math.cos(a), math.sin(a)
            x = hx * math.copysign(abs(c_) ** 0.35, c_)
            z = hz * math.copysign(abs(s_) ** 0.35, s_)
            ring.append((cx + x, cy + y, cz + z))
        rings.append(ring)
    return loft(rings, closed=True, cap_start=True, cap_end=True)


def revolve_geo(profile, center, seg=24):
    rings = []
    for (r, h) in profile:
        rings.append([(center[0] + r * math.cos(2 * math.pi * j / seg), h, center[2] + r * math.sin(2 * math.pi * j / seg))
                      for j in range(seg)])
    return loft(rings, closed=True, cap_start=True, cap_end=True)


def tire_geo(center, r_major, r_minor, width, seg=24, pseg=10):
    prof = [(r_major + r_minor * math.cos(2 * math.pi * k / pseg), width * math.sin(2 * math.pi * k / pseg)) for k in range(pseg)]
    rings = []
    for j in range(seg):
        a = 2 * math.pi * j / seg
        rings.append([(center[0] + h, center[1] + r * math.cos(a), center[2] + r * math.sin(a)) for (r, h) in prof])
    rings.append(rings[0])
    v, f = loft(rings, closed=True)
    return v, f


def merge_geo(parts):
    V, F = [], []
    for v, f in parts:
        o = len(V)
        V += list(v)
        F += [tuple(i + o for i in ff) for ff in f]
    return V, F


# ============================================================================
# Material-Helfer (prozedurale Bake-Materialien)
# ============================================================================
class NB:
    def __init__(self, mat):
        self.nt = mat.node_tree
        self.nodes = self.nt.nodes
        self.links = self.nt.links

    def n(self, t, **kw):
        node = self.nodes.new(t)
        for k, v in kw.items():
            setattr(node, k, v)
        return node

    def l(self, a, b):
        self.links.new(a, b)

    def _in(self, sock, v):
        if isinstance(v, (int, float)):
            sock.default_value = v
        else:
            self.l(v, sock)

    def math(self, op, a, b=None, clamp=False):
        m = self.n("ShaderNodeMath", operation=op, use_clamp=clamp)
        self._in(m.inputs[0], a)
        if b is not None:
            self._in(m.inputs[1], b)
        return m.outputs[0]

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

    def mapping(self, vec, scale=(1, 1, 1), loc=(0, 0, 0)):
        m = self.n("ShaderNodeMapping")
        self.l(vec, m.inputs['Vector'])
        m.inputs['Scale'].default_value = scale
        m.inputs['Location'].default_value = loc
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


PAL_OWN = dict(name="own", top=(0.085, 0.13, 0.045), top2=(0.17, 0.12, 0.055), bottom=(0.33, 0.42, 0.46),
               nose=(0.72, 0.45, 0.04), band=(0.75, 0.52, 0.03), camo_loc=(0, 0, 0), camo_scale=0.55,
               camo_thr=(0.49, 0.53))
PAL_ENEMY = dict(name="enemy", top=(0.50, 0.37, 0.18), top2=(0.115, 0.155, 0.205), bottom=(0.36, 0.43, 0.50),
                 nose=(0.22, 0.035, 0.03), band=(0.70, 0.70, 0.64), camo_loc=(13.1, 5.7, 2.3), camo_scale=0.8,
                 camo_thr=(0.50, 0.535))


def paint_material(part, PAL):
    """part: fus | wing | tail -- Lack mit Tarnung, Panel-Linien, Nieten, Schmutz, Abgas, Abplatzern."""
    m = new_mat("Bake_paint_%s_%s" % (part, PAL["name"]))
    b = NB(m)
    p = b.principled()
    tc = b.n("ShaderNodeTexCoord")
    P = tc.outputs['Object']
    px, py, pz = b.sep(P)
    nx, ny, nz = b.sep(tc.outputs['Normal'])
    ax = b.math('ABSOLUTE', px)

    if part == 'fus':
        wav = b.noise(P, 1.6, 3.0).outputs['Fac']
        off = b.math('MULTIPLY', b.math('SUBTRACT', wav, 0.5), 0.35)
        f = b.math('ADD', b.math('SUBTRACT', pz, -0.22), off)
        topmask = b.maprange(f, -0.01, 0.01)
    elif part == 'wing':
        topmask = b.maprange(nz, -0.05, 0.05)
    else:
        topmask = b.maprange(nz, -2.0, -1.9)
        hstab = b.maprange(ax, 0.10, 0.14)
        under = b.math('MULTIPLY', hstab, b.maprange(nz, -0.2, -0.1, 1.0, 0.0))
        topmask = b.math('SUBTRACT', topmask, under, clamp=True)

    dz = b.noise(b.mapping(P, (1, 1, 0.3), PAL['camo_loc']), PAL['camo_scale'], 2.0, 0.4).outputs['Fac']
    dmask = b.maprange(dz, PAL['camo_thr'][0], PAL['camo_thr'][1])
    topc = b.mix(dmask, PAL['top'], PAL['top2'])
    colr = b.mix(topmask, PAL['bottom'], topc)

    if part == 'fus':
        nose = b.maprange(py, -3.62, -3.60, 1.0, 0.0)
        colr = b.mix(nose, colr, PAL['nose'])
        band = b.math('MULTIPLY', b.maprange(py, 3.0, 3.02), b.maprange(py, 3.32, 3.34, 1.0, 0.0))
        colr = b.mix(band, colr, PAL['band'])
        ck = b.math('MULTIPLY', b.maprange(py, -1.0, -0.95), b.maprange(py, 0.62, 0.68, 1.0, 0.0))
        ck = b.math('MULTIPLY', ck, b.maprange(pz, 0.40, 0.44))
        ck = b.math('MULTIPLY', ck, b.maprange(ax, 0.27, 0.30, 1.0, 0.0))
        colr = b.mix(ck, colr, (0.04, 0.045, 0.04))
    if part == 'tail':
        tip = b.maprange(pz, 1.36, 1.38)
        colr = b.mix(tip, colr, PAL['nose'])

    # --- Panel-Linien + Nietreihen ---------------------------------------
    def dist_lines(c, spacing, offset=0.0):
        v = b.math('DIVIDE', b.math('ADD', c, offset), spacing)
        fr = b.math('FRACT', v)
        return b.math('MULTIPLY', b.math('SUBTRACT', 0.5, b.math('ABSOLUTE', b.math('SUBTRACT', fr, 0.5))), spacing)

    def line_mask(d, width):
        return b.maprange(d, 0.0, width, 1.0, 0.0, smooth=True)

    def rivets(d_line, along, pitch=0.045, off=0.022):
        dr = b.math('ABSOLUTE', b.math('SUBTRACT', d_line, off))
        ds = dist_lines(along, pitch)
        r = b.math('SQRT', b.math('ADD', b.math('MULTIPLY', dr, dr), b.math('MULTIPLY', ds, ds)))
        return b.maprange(r, 0.0022, 0.0042, 1.0, 0.0, smooth=True)

    w = 0.0055
    d1 = dist_lines(py, 0.82, 0.21)
    L = line_mask(d1, w)
    around = b.math('ADD', pz, ax)
    R = rivets(d1, around if part == 'fus' else (px if part == 'wing' else pz))
    if part == 'wing':
        d2 = dist_lines(px, 1.15, 0.3)
        L = b.math('MAXIMUM', L, line_mask(d2, w))
        R = b.math('MAXIMUM', R, rivets(d2, py))
    if part == 'fus':
        for zz in (0.17, -0.33):
            dz_ = b.math('ABSOLUTE', b.math('SUBTRACT', pz, zz))
            L = b.math('MAXIMUM', L, line_mask(dz_, w))
            R = b.math('MAXIMUM', R, rivets(dz_, py))
        # Motorhaube: Wartungsklappen-Umriss
        cowl = b.math('ABSOLUTE', b.math('SUBTRACT', py, -2.62))
        L = b.math('MAXIMUM', L, line_mask(cowl, w))
    if part == 'tail':
        d3 = dist_lines(pz, 0.55, 0.1)
        L = b.math('MAXIMUM', L, line_mask(d3, w))
        R = b.math('MAXIMUM', R, rivets(d3, py))

    colr = b.mix(b.math('MULTIPLY', L, 0.5), colr, (0.01, 0.01, 0.01))

    # --- Schmutz, Ausbleichen, Abgas, Abplatzer ---------------------------
    g = b.noise(P, 2.2, 5.0, 0.55).outputs['Fac']
    colr = b.mix(b.maprange(g, 0.35, 0.75, 0.0, 0.35), colr, (0.07, 0.06, 0.045), 'MULTIPLY')
    fade = b.noise(P, 0.7, 2.0).outputs['Fac']
    colr = b.mix(b.maprange(fade, 0.4, 0.7, 0.0, 0.12), colr, (0.6, 0.6, 0.55), 'SCREEN')
    # Schmutz entlang der Panel-Linien (Washing)
    colr = b.mix(b.math('MULTIPLY', b.maprange(d1, 0.0, 0.03, 1.0, 0.0), 0.25), colr, (0.05, 0.045, 0.035), 'MULTIPLY')
    if part == 'fus':
        st = b.noise(b.mapping(P, (4.0, 0.25, 4.0)), 3.0, 4.0).outputs['Fac']
        reg = b.math('MULTIPLY', b.maprange(py, -3.4, -3.0), b.maprange(py, -3.0, 0.6, 1.0, 0.0))
        reg = b.math('MULTIPLY', reg, b.maprange(b.math('ABSOLUTE', b.math('SUBTRACT', pz, 0.06)), 0.04, 0.28, 1.0, 0.0))
        reg = b.math('MULTIPLY', reg, b.maprange(ax, 0.15, 0.3))
        ex = b.math('MULTIPLY', reg, b.maprange(st, 0.3, 0.7, 0.35, 0.95))
        colr = b.mix(ex, colr, (0.012, 0.010, 0.009))
        # Oel/Schmutz an der Rumpfunterseite hinter dem Kuehler
        oil = b.math('MULTIPLY', b.maprange(pz, -0.45, -0.60), b.maprange(py, -0.2, 2.5, 1.0, 0.0))
        oil = b.math('MULTIPLY', oil, b.maprange(b.noise(b.mapping(P, (3.0, 0.3, 3.0)), 4.0, 3.0).outputs['Fac'], 0.4, 0.7, 0.0, 0.6))
        colr = b.mix(oil, colr, (0.03, 0.025, 0.02))
    chip_n = b.noise(P, 14.0, 8.0, 0.65).outputs['Fac']
    if part == 'wing':
        walk = b.math('MULTIPLY', b.maprange(ax, 0.5, 0.6), b.maprange(ax, 1.25, 1.45, 1.0, 0.0))
        walk = b.math('MULTIPLY', walk, topmask)
        thr = b.math('SUBTRACT', 0.70, b.math('MULTIPLY', walk, 0.07))
    else:
        thr = 0.70
    chips = b.maprange(b.math('SUBTRACT', chip_n, thr), 0.0, 0.01)
    colr = b.mix(chips, colr, (0.62, 0.62, 0.60))
    rn = b.noise(P, 6.0, 3.0).outputs['Fac']
    rough = b.mixf(chips, b.maprange(rn, 0.3, 0.7, 0.50, 0.72), 0.28)
    b.l(colr, p.inputs['Base Color'])
    b.l(rough, p.inputs['Roughness'])
    b.l(chips, p.inputs['Metallic'])
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 0.6
    bump.inputs['Distance'].default_value = 0.0015
    h = b.math('MULTIPLY', L, -1.0)
    h = b.math('ADD', h, b.math('MULTIPLY', R, 0.45))
    dent = b.noise(P, 3.5, 2.0).outputs['Fac']
    h = b.math('ADD', h, b.math('MULTIPLY', dent, 0.25))
    b.l(h, bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    return m


def worn_metal(name, base, rough=0.35, metal=1.0, dirt=0.4, scale=8.0):
    m = new_mat(name)
    b = NB(m)
    p = b.principled()
    P = b.n("ShaderNodeTexCoord").outputs['Object']
    nz = b.noise(P, scale, 5.0, 0.6).outputs['Fac']
    b.l(b.mix(b.maprange(nz, 0.4, 0.8, 0, dirt), base, (0.05, 0.04, 0.03)), p.inputs['Base Color'])
    b.l(b.maprange(nz, 0.3, 0.8, rough, min(1.0, rough + 0.35)), p.inputs['Roughness'])
    p.inputs['Metallic'].default_value = metal
    return m


def simple_mat(name, color, rough=0.5, metal=0.0):
    m = new_mat(name)
    p = NB(m).principled()
    p.inputs['Base Color'].default_value = (*color, 1.0)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    return m


def make_bake_materials(PAL):
    M = {}
    M['fus'] = paint_material('fus', PAL)
    M['wing'] = paint_material('wing', PAL)
    M['tail'] = paint_material('tail', PAL)
    M['strut'] = worn_metal("Bake_strut_" + PAL['name'], (0.55, 0.56, 0.57), 0.3, 1.0, 0.5)
    M['oleo'] = simple_mat("Bake_oleo_" + PAL['name'], (0.85, 0.85, 0.85), 0.12, 1.0)
    M['rubber'] = worn_metal("Bake_rubber_" + PAL['name'], (0.03, 0.03, 0.03), 0.85, 0.0, 0.3, 20)
    M['hub'] = worn_metal("Bake_hub_" + PAL['name'], PAL['bottom'], 0.5, 0.0, 0.4, 10)
    M['exhaust'] = worn_metal("Bake_exh_" + PAL['name'], (0.16, 0.08, 0.05), 0.7, 0.6, 0.8, 20)
    M['prop'] = worn_metal("Bake_prop_" + PAL['name'], (0.03, 0.03, 0.03), 0.5, 0.0, 0.3, 12)
    M['tip'] = simple_mat("Bake_tip_" + PAL['name'], (0.75, 0.52, 0.03), 0.4)
    M['spinner'] = worn_metal("Bake_spinner_" + PAL['name'], PAL['nose'], 0.45, 0.0, 0.25, 9)
    M['dark'] = simple_mat("Bake_dark_" + PAL['name'], (0.02, 0.02, 0.02), 0.8)
    M['gun'] = simple_mat("Bake_gun_" + PAL['name'], (0.05, 0.05, 0.055), 0.35, 1.0)
    M['leather'] = simple_mat("Bake_leather_" + PAL['name'], (0.10, 0.055, 0.03), 0.6)
    M['suit'] = simple_mat("Bake_suit_" + PAL['name'], (0.12, 0.11, 0.08), 0.8)
    for k, m in M.items():
        m["key"] = k
    return M


# ============================================================================
# Geometrie
# ============================================================================
HS = 5.35
CROOT, CTIP = 2.25, 0.95
YQC = -1.45
DIH = math.radians(6.0)
ZROOT = -0.43


def wing_chord(x):
    t = x / HS
    c = CROOT + (CTIP - CROOT) * t
    th = 0.15 + (0.09 - 0.15) * min(t, 1)
    if t > 0.88:
        e = min(1.0, (t - 0.88) / 0.12)
        c *= math.sqrt(max(0.0, 1 - e ** 2)) * 0.85 + 0.15 * (1 - e)
        th *= max(0.08, math.sqrt(max(0.0, 1 - e ** 2)))
    return max(c, 0.05), th


def wing_frame(sgn, x):
    c, th = wing_chord(x)
    t = x / HS
    tw = math.radians(-1.5 * t)
    z0 = ZROOT + x * math.tan(DIH)

    def f(xc, v):
        yy, zz = (xc - 0.25) * c, v * c
        return (sgn * x, YQC + yy * math.cos(tw) - zz * math.sin(tw), z0 + yy * math.sin(tw) + zz * math.cos(tw))
    return f, c, th


HS_H, YQC_H, Z_H, Y_HINGE_H = 1.85, 3.82, 0.13, 4.20


def hstab_frame(sgn, x):
    t = x / HS_H
    c = 1.05 + (0.62 - 1.05) * t
    th = 0.10
    if t > 0.85:
        e = min(1.0, (t - 0.85) / 0.15)
        c *= math.sqrt(max(0.0, 1 - e ** 2)) * 0.85 + 0.15 * (1 - e)
        th = 0.10 * max(0.1, math.sqrt(max(0, 1 - e ** 2)))
    c = max(c, 0.04)

    def f(xc, v):
        return (sgn * x, YQC_H + (xc - 0.25) * c, Z_H + v * c)
    return f, c, th


def fin_frame(t):
    z = 0.10 + t * 1.42
    c = 1.50 + (0.62 - 1.50) * t
    te = 4.86 - 0.05 * t
    th = 0.11
    if t > 0.82:
        e = min(1.0, (t - 0.82) / 0.18)
        c *= math.sqrt(max(0.0, 1 - e ** 2)) * 0.85 + 0.15 * (1 - e)
        th = 0.11 * max(0.1, math.sqrt(max(0, 1 - e ** 2)))
    c = max(c, 0.04)
    le = te - c

    def f(xc, v):
        return (v * c, le + xc * c, z)
    return f, c, th


def surface_zone(frames, kind, m, p, n, xh_fn=None, gap=0.004):
    """frames: Liste (f, c, th, s). kind: full | front | rear. Liefert (verts, faces, hinge_pts)."""
    rings, hinge = [], []
    for (f, c, th, s) in frames:
        if kind == 'full':
            pr = prof_full(m, p, th, n)
        else:
            xh = xh_fn(s, c)
            if kind == 'front':
                pr = prof_front(m, p, th, max(6, int(n * 0.85)), xh, gap / c)
            else:
                pr = prof_rear(m, p, th, max(4, int(n * 0.45)), xh)
            vc, r = _hinge(m, p, th, xh)
            hinge.append(Vector(f(xh, vc)))
        rings.append([f(a, v) for (a, v) in pr])
    v, fc = loft(rings, closed=True, cap_start=True, cap_end=True)
    return v, fc, hinge


def build_raw(BM):
    """Erzeugt alle Rohteile (Blender-Objekte, Identitaets-Transformation) und Rig-Metadaten."""
    rig = {}
    ringstore = {}

    # ---------------- Rumpf ----------------
    tab = [(-4.10, 0.29, 0.20, -0.33), (-3.95, 0.37, 0.29, -0.43), (-3.50, 0.45, 0.38, -0.55),
           (-2.70, 0.50, 0.44, -0.63), (-1.70, 0.53, 0.48, -0.68), (-0.80, 0.54, 0.50, -0.70),
           (0.00, 0.52, 0.52, -0.67), (0.90, 0.45, 0.50, -0.57), (1.90, 0.36, 0.44, -0.44),
           (2.90, 0.27, 0.37, -0.30), (3.80, 0.17, 0.31, -0.16), (4.45, 0.075, 0.26, -0.02),
           (4.72, 0.012, 0.22, 0.07)]
    S = catmull(tab, 4)
    nseg, ex = 40, 2.4
    rings = []
    for (y, w, zt, zb) in S:
        zc, h = (zt + zb) / 2, (zt - zb) / 2
        ring = []
        for j in range(nseg):
            a = 2 * math.pi * j / nseg
            c_, s_ = math.cos(a), math.sin(a)
            ring.append((w * math.copysign(abs(c_) ** (2 / ex), c_), y, zc + h * math.copysign(abs(s_) ** (2 / ex), s_)))
        rings.append(ring)
    ringstore['fus'] = rings
    v, f = loft(rings, closed=True, cap_start=True, cap_end=True)
    tag(mesh_from("Fuselage", v, f, BM['fus']), 'fus', 'fuselage')

    def fus_at(y):
        return S[np.argmin(np.abs(S[:, 0] - y))]

    # ---------------- Fluegel ----------------
    NW = 15
    hinge_w = lambda s, c: 0.75
    zones = [('full', 0.0, 0.62, 3, None), ('flap', 0.62, 2.75, 4, 'flap'), ('full', 2.75, 2.90, 2, None),
             ('ail', 2.90, 4.65, 4, 'aileron'), ('tip', 4.65, HS, 0, None)]
    for sgn, side in ((1, 'L'), (-1, 'R')):
        wparts = []
        ringstore['wing_' + side] = []
        for (kind, x0, x1, ns, cs) in zones:
            if kind == 'tip':
                xs = [4.65, 0.88 * HS] + list((0.88 + 0.12 * np.sin(np.linspace(0.15, 1.0, 7) * math.pi / 2)) * HS)
            else:
                xs = list(np.linspace(x0, x1, ns))
            fr = [(*wing_frame(sgn, x), x) for x in xs]
            if kind in ('full', 'tip'):
                vv, ff, _ = surface_zone(fr, 'full', 0.02, 0.4, NW)
                wparts.append((vv, ff))
                ringstore['wing_' + side].append(vv)
            else:
                vv, ff, _ = surface_zone(fr, 'front', 0.02, 0.4, NW, hinge_w)
                wparts.append((vv, ff))
                ringstore['wing_' + side].append(vv)
                xr = list(np.linspace(x0 + 0.012, x1 - 0.012, ns))
                frr = [(*wing_frame(sgn, x), x) for x in xr]
                vr, frr_, hp = surface_zone(frr, 'rear', 0.02, 0.4, NW, hinge_w)
                name = "%s_%s" % (cs, side)
                tag(mesh_from(name + "_raw", vr, frr_, BM['wing']), 'wing', name)
                axis = (hp[0] - hp[-1]).normalized() if sgn > 0 else (hp[-1] - hp[0]).normalized()
                # Achse zeigt immer Richtung Modell -X (Pilot rechts) -> positiv = Hinterkante runter
                if axis.x > 0:
                    axis = -axis
                rig[name] = dict(pivot=hp[0] if sgn > 0 else hp[0], axis=axis, kind='hinge', parent='wing_' + side)
        V, F = merge_geo(wparts)
        tag(mesh_from("Wing_%s_raw" % side, V, F, BM['wing']), 'wing', 'wing_' + side)

        # MG in der Vorderkante
        gx = sgn * 2.35
        fW, cW, _ = wing_frame(sgn, abs(gx))
        le = Vector(fW(0.0, 0.0))
        gz = le.z + 0.01
        g1 = cyl((gx, le.y + 0.25, gz), (gx, le.y - 0.42, gz), 0.018, 8)
        g2 = cyl((gx, le.y + 0.15, gz), (gx, le.y - 0.05, gz), 0.042, 10, r1=0.03)
        tag(mesh_from("Gun_%s_raw" % side, *merge_geo([g1, g2]), BM['gun']), 'detail', 'wing_' + side)
        rig['_gun_' + side] = Vector((gx, le.y - 0.42, gz))
        rig['_ammo_' + side] = Vector((gx, le.y + 0.55, 0))
        if sgn > 0:
            fP, _, _ = wing_frame(1, 4.3)
            pl = Vector(fP(0.05, -0.02))
            tag(mesh_from("Pitot_raw", *cyl(pl + Vector((0, 0.1, 0)), pl + Vector((0, -0.5, -0.03)), 0.008, 6), BM['strut']),
                'detail', 'wing_L')
        fT, cT, _ = wing_frame(sgn, HS * 0.995)
        rig['_tip_' + side] = Vector(fT(0.5, 0.0))

    # ---------------- Hoehenleitwerk ----------------
    NH = 12
    hinge_h = lambda s, c: 0.25 + (Y_HINGE_H - YQC_H) / c
    elev_parts = []
    for sgn, side in ((1, 'L'), (-1, 'R')):
        hparts = []
        zonesH = [('full', [0.0, 0.15]), ('elev', list(np.linspace(0.15, 1.55, 4))),
                  ('full', [1.55, 0.85 * HS_H] + list((0.85 + 0.15 * np.sin(np.linspace(0.15, 1.0, 6) * math.pi / 2)) * HS_H))]
        for kind, xs in zonesH:
            fr = [(*hstab_frame(sgn, x), x) for x in xs]
            if kind == 'full':
                vv, ff, _ = surface_zone(fr, 'full', 0, 0.4, NH)
                hparts.append((vv, ff))
            else:
                vv, ff, _ = surface_zone(fr, 'front', 0, 0.4, NH, hinge_h)
                hparts.append((vv, ff))
                xr = list(np.linspace(0.15 + 0.012, 1.55 - 0.012, 4))
                frr = [(*hstab_frame(sgn, x), x) for x in xr]
                vr, fr_, hp = surface_zone(frr, 'rear', 0, 0.4, NH, hinge_h)
                elev_parts.append((vr, fr_))
                rig['_elev_hinge'] = hp[0]
        V, F = merge_geo(hparts)
        tag(mesh_from("HStab_%s_raw" % side, V, F, BM['tail']), 'wing', 'stabilizer')
    V, F = merge_geo(elev_parts)
    tag(mesh_from("Elevator_raw", V, F, BM['tail']), 'wing', 'elevator')
    rig['elevator'] = dict(pivot=Vector((0, Y_HINGE_H, Z_H)), axis=Vector((-1, 0, 0)), kind='hinge', parent='fuselage')

    # ---------------- Seitenleitwerk ----------------
    NF = 12
    t_r0, t_r1 = (0.32 - 0.10) / 1.42, 0.80
    hinge_f = lambda s, c: 0.68
    fparts = []
    zonesF = [('full', [0.0, t_r0]), ('rud', list(np.linspace(t_r0, t_r1, 4))),
              ('full', [t_r1, 0.82] + list(0.82 + 0.18 * np.sin(np.linspace(0.15, 1.0, 6) * math.pi / 2)))]
    for kind, ts in zonesF:
        fr = [(*fin_frame(t), t) for t in ts]
        if kind == 'full':
            vv, ff, _ = surface_zone(fr, 'full', 0, 0.4, NF)
            fparts.append((vv, ff))
        else:
            vv, ff, _ = surface_zone(fr, 'front', 0, 0.4, NF, hinge_f)
            fparts.append((vv, ff))
            dz = 0.012 / 1.42
            tr = list(np.linspace(t_r0 + dz, t_r1 - dz, 4))
            frr = [(*fin_frame(t), t) for t in tr]
            vr, fr_, hp = surface_zone(frr, 'rear', 0, 0.4, NF, hinge_f)
            tag(mesh_from("Rudder_raw", vr, fr_, BM['tail']), 'fus', 'rudder')
            rig['rudder'] = dict(pivot=hp[0], axis=(hp[-1] - hp[0]).normalized(), kind='rudder', parent='fuselage')
    V, F = merge_geo(fparts)
    ringstore['fin'] = V
    tag(mesh_from("Fin_raw", V, F, BM['tail']), 'fus', 'fuselage')
    ringstore['hstab'] = [hstab_frame(s, x)[0](a, 0) for s in (1, -1) for x in (0.0, 1.8) for a in (0.0, 1.0)]

    # ---------------- Cockpithaube ----------------
    ctab = [(-1.20, 0.22, 0.40), (-1.00, 0.27, 0.62), (-0.70, 0.30, 0.86), (-0.30, 0.31, 0.93),
            (0.20, 0.30, 0.92), (0.65, 0.25, 0.82), (1.10, 0.17, 0.66), (1.55, 0.09, 0.50)]
    CS = catmull(ctab, 8)
    zb = 0.36
    narc = 16

    def can_pt(y, ph, sc=1.0):
        w = float(np.interp(y, CS[:, 0], CS[:, 1]))
        zt = float(np.interp(y, CS[:, 0], CS[:, 2]))
        c_, s_ = math.cos(ph), math.sin(ph)
        return (w * sc * math.copysign(abs(c_) ** (2 / 2.6), c_), y, zb + (zt - zb) * sc * (abs(s_) ** (2 / 2.6)))

    def can_shell(ys, sc):
        rr = [[can_pt(y, math.pi * j / narc, sc) for j in range(narc + 1)] for y in ys]
        return loft(rr, closed=False)

    def frame_arc(y, sc, r=0.013):
        pts = [can_pt(y, math.pi * j / 24, sc) for j in range(25)]
        pts = [p for p in pts if p[2] > 0.42]
        return tube(pts, r, 5)

    def rail(y0, y1, ph, sc, r=0.011, n=10):
        return tube([can_pt(y, ph, sc) for y in np.linspace(y0, y1, n)], r, 5)

    HOOD = 1.03
    ws = can_shell(np.linspace(-1.20, -0.72, 5), 1.0)
    rear = can_shell(np.linspace(0.30, 1.55, 8), 1.0)
    hood = can_shell(np.linspace(-0.72, 0.30, 8), HOOD)
    for nm, geo, node in (("GlassFixed_raw", merge_geo([ws, rear]), 'fuselage'), ("GlassHood_raw", hood, 'canopy')):
        o = mesh_from(nm, *geo, None)
        tag(o, 'glass', node)
    fr_fixed = merge_geo([frame_arc(-1.0, 1.012), frame_arc(-0.735, 1.012), frame_arc(0.78, 1.012),
                          rail(-1.18, -0.735, math.pi * 0.22, 1.012), rail(-1.18, -0.735, math.pi * 0.78, 1.012),
                          rail(0.32, 1.50, math.pi * 0.5, 1.012)])
    tag(mesh_from("FrameFixed_raw", *fr_fixed, BM['fus']), 'fus', 'fuselage')
    fr_hood = merge_geo([frame_arc(-0.70, HOOD * 1.012), frame_arc(-0.22, HOOD * 1.012), frame_arc(0.28, HOOD * 1.012),
                         rail(-0.70, 0.28, math.pi * 0.5, HOOD * 1.012)])
    tag(mesh_from("FrameHood_raw", *fr_hood, BM['fus']), 'fus', 'canopy')
    rig['canopy'] = dict(pivot=Vector((0, -0.72, zb)), axis=Vector((0, 1, 0)), kind='slide', parent='fuselage')
    tag(mesh_from("Headrest_raw", *rbox_geo((0, 0.42, 0.66), (0.24, 0.05, 0.30), 0.02, 1), BM['dark']), 'detail', 'fuselage')
    tag(mesh_from("Gunsight_raw", *rbox_geo((0, -0.78, 0.60), (0.06, 0.08, 0.10), 0.01, 1), BM['dark']), 'detail', 'fuselage')
    # Pilot (einfach, eigener Knoten -> ausblendbar)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.11)
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0.12, 0.76))
    s2 = bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.2)
    for vv in s2['verts']:
        vv.co = Vector((vv.co.x * 1.15, vv.co.y * 0.7 + 0.20, vv.co.z * 0.8 + 0.52))
    me = bpy.data.meshes.new("Pilot_raw")
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    po = bpy.data.objects.new("Pilot_raw", me)
    col().objects.link(po)
    me.materials.append(BM['suit'])
    me.materials.append(BM['leather'])
    for pl in me.polygons:
        pl.material_index = 1 if pl.center.z > 0.66 else 0
    tag(po, 'detail', 'pilot')

    # Antenne
    tag(mesh_from("Antenna_raw", *merge_geo([cyl((0, 1.05, 0.55), (0, 1.12, 0.98), 0.012, 6, r1=0.006),
                                              tube([(0, 1.12, 0.98), (0, 4.45, 1.45)], 0.003, 4)]), BM['strut']),
        'detail', 'fuselage')

    # ---------------- Spinner & Propeller ----------------
    HUB = Vector((0, -4.36, -0.065))
    prof = [(0.25, -4.02)] + [(max(0.305 * (max(0.0, 1 - (k / 12) ** 2.0)) ** 0.5, 0.003), -4.08 - 0.72 * k / 12) for k in range(13)]
    tag(mesh_from("Spinner_raw", *revolve_geo(prof, (0, 0, HUB.z), 24), BM['spinner']), 'detail', 'prop_spinner')
    pv, pf = [], []
    radii = np.concatenate([np.linspace(0.16, 1.40, 9), 1.40 + 0.13 * np.sin(np.linspace(0.2, 1, 5) * math.pi / 2)])
    for bl in range(3):
        rot = 2 * math.pi * bl / 3 + 0.3
        rr = []
        for r in radii:
            c = 0.17 + 0.09 * math.sin(min(1, (r - 0.16) / 0.9) * math.pi * 0.6)
            if r > 1.40:
                e = (r - 1.40) / 0.13
                c *= math.sqrt(max(0, 1 - e ** 2)) * 0.9 + 0.1 * (1 - e)
            c = max(c, 0.03)
            th = 0.16 - 0.10 * (r - 0.16) / 1.4
            if r < 0.3:
                th = 0.35
            beta = math.atan(2.6 / (2 * math.pi * max(r, 0.25)))
            ring = []
            for (a_, b_) in prof_full(0.03, 0.35, th, 9):
                u, vv = (a_ - 0.35) * c, b_ * c
                lx = u * math.cos(beta) - vv * math.sin(beta)
                ly = u * math.sin(beta) + vv * math.cos(beta)
                X = lx * math.cos(rot) + r * math.sin(rot)
                Z = -lx * math.sin(rot) + r * math.cos(rot)
                ring.append((HUB.x + X, HUB.y + ly, HUB.z + Z))
            rr.append(ring)
        vv_, ff_ = loft(rr, closed=True, cap_start=True, cap_end=True)
        o = len(pv)
        pv += vv_
        pf += [tuple(i + o for i in q) for q in ff_]
    bo = mesh_from("Blades_raw", pv, pf, BM['prop'])
    bo.data.materials.append(BM['tip'])
    for pl in bo.data.polygons:
        c_ = pl.center - HUB
        if math.hypot(c_.x, c_.z) > 1.30:
            pl.material_index = 1
    tag(bo, 'detail', 'prop_blades')
    rig['propeller'] = dict(pivot=HUB, axis=Vector((0, -1, 0)), kind='spin', parent='fuselage')
    # Propellerscheibe
    seg = 32
    dv = [(HUB.x, HUB.y + 0.02, HUB.z)] + [(HUB.x + 1.53 * math.cos(2 * math.pi * k / seg), HUB.y + 0.02,
                                           HUB.z + 1.53 * math.sin(2 * math.pi * k / seg)) for k in range(seg)]
    df = [(0, 1 + k, 1 + (k + 1) % seg) for k in range(seg)]
    do = mesh_from("PropDisc_raw", dv, df, None, smooth=False)
    uv = do.data.uv_layers.new(name="UVMap")
    for li, loop in enumerate(do.data.loops):
        p_ = do.data.vertices[loop.vertex_index].co
        uv.data[li].uv = (0.5 + (p_.x - HUB.x) / 3.06, 0.5 + (p_.z - HUB.z) / 3.06)
    tag(do, 'disc', 'prop_disc')
    rig['prop_disc'] = dict(pivot=HUB, kind='static', parent='fuselage')

    # ---------------- Hauptfahrwerk (Einfahren nach innen) ----------------
    for sgn, side in ((1, 'L'), (-1, 'R')):
        P = Vector((sgn * 1.85, -1.45, -0.24))
        Bt = Vector((sgn * 1.84, -1.75, -1.58))
        W = Vector((sgn * 1.70, -1.75, -1.58))
        K = P + 0.55 * (Bt - P)
        leg = merge_geo([cyl(P + Vector((0, 0, 0.05)), K, 0.055, 10), cyl(K, Bt, 0.04, 10),
                         cyl(Bt + Vector((0, 0, 0.14)), Bt - Vector((0, 0, 0.03)), 0.036, 8),
                         cyl(Bt, W, 0.03, 8)])
        tag(mesh_from("Leg_%s_raw" % side, *leg, BM['strut']), 'detail', 'gear_main_' + side)
        # Klappe am Bein (aussen)
        dleg = (P - Bt).normalized()
        xa = Vector((1, 0, 0))
        xa = (xa - dleg * xa.dot(dleg)).normalized()
        ya = dleg.cross(xa)
        Bm = Matrix((xa, ya, dleg)).transposed()
        Dc = P + (Bt - P) * 0.42 + Vector((sgn * 0.075, 0, 0))
        tag(mesh_from("Door_%s_raw" % side, *box_geo(Dc, (0.015, 0.30, 0.78), Bm), BM['wing'], smooth=False),
            'wing', 'gear_door_' + side)
        tw = merge_geo([tire_geo(W, 0.255, 0.085, 0.075, 24, 10)])
        tag(mesh_from("Tire_%s_raw" % side, *tw, BM['rubber']), 'detail', 'wheel_main_' + side)
        tag(mesh_from("Hub_%s_raw" % side, *cyl(W - Vector((0.06, 0, 0)), W + Vector((0.06, 0, 0)), 0.18, 16), BM['hub']),
            'detail', 'wheel_main_' + side)
        # Einfahrbewegung: Rad landet flach in der Fluegelwurzel
        L_ = (W - P).length
        Tdir = Vector((sgn * 0.48, -1.40, -0.335)) - P
        T = P + Tdir.normalized() * L_
        de = (W - P).normalized()
        ae = Vector((1, 0, 0))
        ae = (ae - de * ae.dot(de)).normalized()
        dr = (T - P).normalized()
        ar = Vector((0, 0, -sgn))
        ar = (ar - dr * ar.dot(dr)).normalized()
        Fe = Matrix((de, ae, de.cross(ae))).transposed()
        Fr = Matrix((dr, ar, dr.cross(ar))).transposed()
        Rm = Fr @ Fe.transposed()
        axis, ang = Rm.to_quaternion().to_axis_angle()
        rig['gear_main_' + side] = dict(pivot=P, axis=axis.normalized(), kind='gear', angle=math.degrees(ang),
                                        parent='wing_' + side, target=T)
        rig['gear_door_' + side] = dict(pivot=P, kind='follow', parent='gear_main_' + side)
        rig['wheel_main_' + side] = dict(pivot=W, axis=Vector((1, 0, 0)), kind='wheel', parent='gear_main_' + side,
                                         radius=0.34)

    # ---------------- Spornrad ----------------
    ST0, ST1, TW = Vector((0, 4.20, 0.02)), Vector((0, 4.34, -0.40)), Vector((0, 4.34, -0.43))
    tag(mesh_from("TailStrut_raw", *merge_geo([cyl(ST0, ST1, 0.035, 8), cyl(TW - Vector((0.045, 0, 0)), TW + Vector((0.045, 0, 0)), 0.02, 6)]),
                  BM['strut']), 'detail', 'tailwheel')
    tag(mesh_from("TailTire_raw", *merge_geo([tire_geo(TW, 0.075, 0.04, 0.035, 16, 8),
                                               cyl(TW - Vector((0.04, 0, 0)), TW + Vector((0.04, 0, 0)), 0.05, 10)]), BM['rubber']),
        'detail', 'wheel_tail')
    rig['tailwheel'] = dict(pivot=ST0, axis=(ST0 - ST1).normalized(), kind='steer', parent='fuselage')
    rig['wheel_tail'] = dict(pivot=TW, axis=Vector((1, 0, 0)), kind='wheel', parent='tailwheel', radius=0.115)

    # ---------------- Auspuff, Kuehler, Einlauf ----------------
    exs = []
    for sgn in (1, -1):
        for k in range(6):
            y = -3.55 + k * 0.17
            x0 = sgn * fus_at(y)[1] * 0.93
            exs.append(cyl((x0, y, 0.10), (x0 + sgn * 0.085, y + 0.06, 0.08), 0.033, 8))
    tag(mesh_from("Exhaust_raw", *merge_geo(exs), BM['exhaust']), 'detail', 'fuselage')
    tag(mesh_from("Radiator_raw", *rbox_geo((0, -0.25, -0.70), (0.60, 1.5, 0.34), 0.1, 2), BM['fus']), 'fus', 'fuselage')
    tag(mesh_from("RadIntake_raw", *rbox_geo((0, -1.0, -0.76), (0.48, 0.03, 0.18), 0.015, 1), BM['dark']), 'detail', 'fuselage')
    tag(mesh_from("AirIntake_raw", *rbox_geo((0.42, -3.1, -0.25), (0.10, 0.45, 0.14), 0.04, 1), BM['fus']), 'fus', 'fuselage')

    return rig, ringstore, fus_at


# ============================================================================
# Abzeichen- und Propellerscheiben-Texturen (numpy)
# ============================================================================
def value_noise(h, w, cell, seed):
    rng = np.random.default_rng(seed)
    gh, gw = h // cell + 2, w // cell + 2
    g = rng.random((gh, gw))
    ys = np.arange(h) / cell
    xs = np.arange(w) / cell
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = (ys - y0)[:, None], (xs - x0)[None, :]
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]; b_ = g[y0][:, x0 + 1]; c_ = g[y0 + 1][:, x0]; d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b_ * fx) * (1 - fy) + (c_ * (1 - fx) + d * fx) * fy


def srgb(c):
    return np.array(c, dtype=float) / 255.0


def make_insignia(nation, path):
    """1024x512 RGBA: links Rundabzeichen, rechts Seitenleitwerks-Markierung (beide fiktiv)."""
    SS = 2
    H, W = 512 * SS, 1024 * SS
    img = np.zeros((H, W, 4))
    yy, xx = np.mgrid[0:H, 0:W]
    # linkes Feld: Kreis-Koordinaten (-1..1)
    u = (xx - H / 2) / (H / 2 * 0.96)
    v = (yy - H / 2) / (H / 2 * 0.96)
    r = np.sqrt(u * u + v * v)

    def put(mask, rgb):
        img[mask, :3] = srgb(rgb)
        img[mask, 3] = 1.0
    left = xx < H
    if nation == 'own':
        put(left & (r < 1.0), (46, 60, 108))           # Marine-Ring
        put(left & (r < 0.84), (222, 220, 208))        # weiss
        put(left & (np.abs(u) + np.abs(v) < 0.66), (46, 60, 108))  # Raute
        put(left & (r < 0.20), (226, 186, 52))         # gelber Punkt
    else:
        # Sechseck (flache Seite oben), weisser Rand, weinrot, sandfarbener Ring, Punkt
        hexd = np.maximum(np.abs(v) * 1.0, (np.abs(v) * 0.5 + np.abs(u) * 0.866))
        put(left & (hexd < 0.92), (226, 222, 210))
        put(left & (hexd < 0.80), (112, 30, 30))
        put(left & (r < 0.46), (204, 172, 112))
        put(left & (r < 0.30), (112, 30, 30))
        put(left & (r < 0.13), (226, 222, 210))
    # rechtes Feld: Leitwerksmarkierung 0..1 in u2, v2
    u2 = (xx - H) / H
    v2 = yy / H
    right = (xx >= H) & (v2 > 0.1) & (v2 < 0.9) & (u2 > 0.02) & (u2 < 0.98)
    inner = (v2 > 0.14) & (v2 < 0.86) & (u2 > 0.05) & (u2 < 0.95)
    put(right, (222, 220, 208))
    if nation == 'own':
        put(right & inner & ((v2 < 0.38) | (v2 > 0.62)), (46, 60, 108))
        put(right & inner & (v2 >= 0.38) & (v2 <= 0.62), (226, 186, 52))
    else:
        diag = (u2 + (v2 - 0.5) * 0.6) < 0.5
        put(right & inner & diag, (112, 30, 30))
        put(right & inner & ~diag, (204, 172, 112))
    # Abnutzung: Schmutz und kleine Abplatzer
    n1 = value_noise(H, W, 24 * SS, 3 if nation == 'own' else 5)
    n2 = value_noise(H, W, 5 * SS, 11)
    img[..., :3] *= (0.86 + 0.14 * n1)[..., None]
    chip = (n2 > 0.83) & (n1 > 0.55)
    img[chip, 3] = 0.0
    img = img.reshape(512, SS, 1024, SS, 4).mean(axis=(1, 3))
    save_rgba(img, path)


def make_prop_disc(path):
    S = 512
    yy, xx = np.mgrid[0:S, 0:S]
    u = (xx + 0.5) / S * 2 - 1
    v = (yy + 0.5) / S * 2 - 1
    r = np.sqrt(u * u + v * v)
    ang = np.arctan2(v, u)
    img = np.zeros((S, S, 4))
    img[..., :3] = srgb((22, 22, 22))
    blade = np.clip((r - 0.19) / 0.05, 0, 1) * np.clip((0.995 - r) / 0.01, 0, 1)
    streak = 0.85 + 0.15 * np.cos(ang * 3 + r * 4)
    a = 0.22 * blade * streak * (1.0 - 0.35 * r)
    tip = (r > 0.85) & (r < 0.995)
    img[tip, :3] = srgb((215, 165, 40))
    a = np.where(tip, 0.30 * np.clip((0.995 - r) / 0.01, 0, 1), a)
    img[..., 3] = a
    save_rgba(img, path)


def save_rgba(arr, path):
    h, w = arr.shape[:2]
    im = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    im.colorspace_settings.name = 'sRGB'
    # Blender-Bilder: Zeile 0 = unten
    im.pixels.foreach_set(np.ascontiguousarray(arr[::-1]).astype(np.float32).ravel())
    im.filepath_raw = path
    im.file_format = 'PNG'
    im.save()
    bpy.data.images.remove(im)


# ============================================================================
# Abziehbilder (auf Oberflaeche projiziertes Gitter)
# ============================================================================
def make_decal(name, targets, center, n, u, size, uvrect, grid=8, offset=0.003):
    center, n, u = Vector(center), Vector(n).normalized(), Vector(u)
    u = (u - n * u.dot(n)).normalized()
    v = n.cross(u)
    verts, faces, uvs = [], [], []
    bvhs = []
    for t in targets:
        bm = bmesh.new()
        bm.from_mesh(t.data)
        bvhs.append(BVHTree.FromBMesh(bm))
        bm.free()
    for j in range(grid + 1):
        for i in range(grid + 1):
            s, tt = i / grid, j / grid
            p0 = center + u * (s - 0.5) * size[0] + v * (tt - 0.5) * size[1]
            best = None
            for bv in bvhs:
                hit = bv.ray_cast(p0 + n * 0.4, -n, 1.0)
                if hit[0] is not None and (best is None or hit[3] < best[3]):
                    best = hit
            if best is not None:
                nn = best[1] if best[1].dot(n) > 0 else -best[1]
                verts.append(tuple(best[0] + nn * offset))
            else:
                verts.append(tuple(p0))
            uvs.append((uvrect[0] + s * (uvrect[2] - uvrect[0]), uvrect[1] + tt * (uvrect[3] - uvrect[1])))
    for j in range(grid):
        for i in range(grid):
            a = j * (grid + 1) + i
            faces.append((a, a + 1, a + grid + 2, a + grid + 1))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    me.shade_smooth()
    uvl = me.uv_layers.new(name="UVMap")
    for li, loop in enumerate(me.loops):
        uvl.data[li].uv = uvs[loop.vertex_index]
    ob = bpy.data.objects.new(name, me)
    col().objects.link(ob)
    return ob


# ============================================================================
# UV + Bake
# ============================================================================
def select_only(objs, active=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def uv_unwrap(objs, margin):
    select_only(objs)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(50), island_margin=margin, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    try:
        bpy.ops.uv.pack_islands(rotate=True, margin=margin)
    except Exception as e:
        print("pack_islands:", e)
    bpy.ops.object.mode_set(mode='OBJECT')


def set_bake_mode(mat, mode, img):
    nt = mat.node_tree
    p = nt.nodes.get("Principled BSDF")
    out = [n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'][0]
    em = nt.nodes.get("BakeEmit") or nt.nodes.new("ShaderNodeEmission")
    em.name = "BakeEmit"
    tn = nt.nodes.get("BakeTarget") or nt.nodes.new("ShaderNodeTexImage")
    tn.name = "BakeTarget"
    tn.image = img
    nt.nodes.active = tn
    for l in list(em.inputs['Color'].links):
        nt.links.remove(l)
    if mode in ('albedo', 'rough', 'metal'):
        sock = {'albedo': 'Base Color', 'rough': 'Roughness', 'metal': 'Metallic'}[mode]
        si = p.inputs[sock]
        if si.links:
            nt.links.new(si.links[0].from_socket, em.inputs['Color'])
        else:
            dv = si.default_value
            em.inputs['Color'].default_value = (dv[0], dv[1], dv[2], 1) if mode == 'albedo' else (dv, dv, dv, 1)
        em.inputs['Strength'].default_value = 1.0
        nt.links.new(em.outputs[0], out.inputs['Surface'])
    else:
        nt.links.new(p.outputs[0], out.inputs['Surface'])


def new_image(name, size, noncolor):
    im = bpy.data.images.get(name)
    if im:
        bpy.data.images.remove(im)
    im = bpy.data.images.new(name, size, size, alpha=False)
    im.colorspace_settings.name = 'Non-Color' if noncolor else 'sRGB'
    return im


def save_image(im, path):
    im.filepath_raw = path
    im.file_format = 'PNG'
    im.save()


def bake_group(objs, mats, size, maps, prefix, hide_for_ao=()):
    scene = bpy.context.scene
    copies = []
    for o in objs:
        c = o.copy()
        c.data = o.data.copy()
        col().objects.link(c)
        for i, m in enumerate(c.data.materials):
            c.data.materials[i] = mats[m["key"]]
        copies.append(c)
    for o in objs:
        o.hide_render = True
    select_only(copies)
    bpy.ops.object.join()
    bo = bpy.context.view_layer.objects.active
    bo.name = "BAKE_" + prefix
    results = {}
    for mp in maps:
        t0 = time.time()
        im = new_image(prefix + "_" + mp, size, mp != 'albedo')
        btype = {'albedo': 'EMIT', 'rough': 'EMIT', 'metal': 'EMIT', 'normal': 'NORMAL', 'ao': 'AO'}[mp]
        for m in bo.data.materials:
            set_bake_mode(m, mp, im)
        scene.cycles.samples = SAMPLES['ao'] if mp == 'ao' else (SAMPLES['normal'] if mp == 'normal' else SAMPLES['color'])
        hidden = []
        if mp == 'ao':
            for h in hide_for_ao:
                if not h.hide_render:
                    h.hide_render = True
                    hidden.append(h)
        select_only([bo])
        kw = dict(type=btype, margin=max(4, size // 256), use_clear=True)
        if btype == 'NORMAL':
            kw.update(normal_space='TANGENT')
        bpy.ops.object.bake(**kw)
        for h in hidden:
            h.hide_render = False
        results[mp] = im
        print("  bake %s %s %.1fs" % (prefix, mp, time.time() - t0))
    for m in bo.data.materials:
        set_bake_mode(m, 'normal', None)
    bpy.data.objects.remove(bo)
    for o in objs:
        o.hide_render = False
    return results


def pack_orm(ao, rough, metal, path):
    n = ao.size[0] * ao.size[1]
    A = np.empty(n * 4, np.float32); ao.pixels.foreach_get(A)
    Rr = np.empty(n * 4, np.float32); rough.pixels.foreach_get(Rr)
    Mm = np.empty(n * 4, np.float32); metal.pixels.foreach_get(Mm)
    A, Rr, Mm = A.reshape(-1, 4), Rr.reshape(-1, 4), Mm.reshape(-1, 4)
    out = np.stack([np.clip(A[:, 0] * 0.85 + 0.15, 0, 1), Rr[:, 0], Mm[:, 0], np.ones(n, np.float32)], 1)
    im = new_image(os.path.basename(path), ao.size[0], True)
    im.pixels.foreach_set(out.ravel())
    save_image(im, path)
    return im


# ============================================================================
# Godot-Materialien
# ============================================================================
def gltf_settings_group():
    ng = bpy.data.node_groups.get("glTF Material Output")
    if ng:
        return ng
    ng = bpy.data.node_groups.new("glTF Material Output", 'ShaderNodeTree')
    try:
        ng.interface.new_socket(name="Occlusion", in_out='INPUT', socket_type='NodeSocketFloat')
    except Exception:
        ng.inputs.new('NodeSocketFloat', 'Occlusion')
    return ng


def load_img(path, noncolor):
    im = bpy.data.images.load(path, check_existing=True)
    im.colorspace_settings.name = 'Non-Color' if noncolor else 'sRGB'
    return im


def pbr_material(name, albedo, normal, orm):
    m = new_mat(name)
    nt = m.node_tree
    b = NB(m)
    p = b.principled()
    ta = b.n("ShaderNodeTexImage"); ta.image = load_img(albedo, False); ta.name = "albedo"
    b.l(ta.outputs['Color'], p.inputs['Base Color'])
    to = b.n("ShaderNodeTexImage"); to.image = load_img(orm, True); to.name = "orm"
    sp = b.n("ShaderNodeSeparateColor")
    b.l(to.outputs['Color'], sp.inputs[0])
    b.l(sp.outputs[1], p.inputs['Roughness'])
    b.l(sp.outputs[2], p.inputs['Metallic'])
    g = b.n("ShaderNodeGroup"); g.node_tree = gltf_settings_group()
    b.l(sp.outputs[0], g.inputs['Occlusion'])
    tn = b.n("ShaderNodeTexImage"); tn.image = load_img(normal, True); tn.name = "normal"
    nm = b.n("ShaderNodeNormalMap")
    b.l(tn.outputs['Color'], nm.inputs['Color'])
    b.l(nm.outputs['Normal'], p.inputs['Normal'])
    m.use_backface_culling = True
    return m


def decal_material(name, path):
    m = new_mat(name)
    b = NB(m)
    p = b.principled()
    t = b.n("ShaderNodeTexImage"); t.image = load_img(path, False); t.name = "albedo"
    t.extension = 'CLIP'
    b.l(t.outputs['Color'], p.inputs['Base Color'])
    rnd = b.math('ROUND', t.outputs['Alpha'])
    b.l(rnd, p.inputs['Alpha'])
    p.inputs['Roughness'].default_value = 0.6
    m.use_backface_culling = True
    try:
        m.surface_render_method = 'DITHERED'
    except Exception:
        pass
    return m


def disc_material(name, path):
    m = new_mat(name)
    b = NB(m)
    p = b.principled()
    t = b.n("ShaderNodeTexImage"); t.image = load_img(path, False)
    b.l(t.outputs['Color'], p.inputs['Base Color'])
    b.l(t.outputs['Alpha'], p.inputs['Alpha'])
    p.inputs['Roughness'].default_value = 0.7
    m.use_backface_culling = False
    try:
        m.surface_render_method = 'BLENDED'
    except Exception:
        pass
    return m


def glass_material():
    m = new_mat("M_Glass")
    p = NB(m).principled()
    p.inputs['Base Color'].default_value = (0.80, 0.88, 0.92, 1)
    p.inputs['Roughness'].default_value = 0.05
    p.inputs['Alpha'].default_value = 0.22
    m.use_backface_culling = False
    try:
        m.surface_render_method = 'BLENDED'
    except Exception:
        pass
    return m


# ============================================================================
# Zusammenbau
# ============================================================================
def dedupe_materials(ob):
    me = ob.data
    mats = list(me.materials)
    uniq = []
    remap = []
    for m in mats:
        if m in uniq:
            remap.append(uniq.index(m))
        else:
            uniq.append(m)
            remap.append(len(uniq) - 1)
    if len(uniq) == len(mats):
        return
    idx = np.empty(len(me.polygons), np.int32)
    me.polygons.foreach_get("material_index", idx)
    idx = np.array(remap, np.int32)[idx]
    me.materials.clear()
    for m in uniq:
        me.materials.append(m)
    me.polygons.foreach_set("material_index", idx)
    me.update()


def hinge_basis(axis, kind):
    a = Vector(axis).normalized()
    if kind == 'rudder' or kind == 'steer':
        Z = a
        X = Vector((-1, 0, 0))
        X = (X - Z * X.dot(Z)).normalized()
        Y = Z.cross(X)
        return Matrix((X, Y, Z)).transposed()
    X = a
    ref = Vector((0, 0, 1)) if abs(X.z) < 0.9 else Vector((0, 1, 0))
    Y = ref.cross(X).normalized()
    Z = X.cross(Y)
    return Matrix((X, Y, Z)).transposed()


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons) if ob.type == 'MESH' else 0


def godot_axis_of(blender_local):
    return {'X': 'x', 'Y': '-z', 'Z': 'y'}[blender_local]


def main_build():
    t_start = time.time()
    reset_scene()
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.render.bake.margin_type = 'EXTEND'
    world = bpy.data.worlds.new("BakeWorld")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    world.light_settings.distance = 0.7

    BM = make_bake_materials(PAL_OWN)
    rig, rings, fus_at = build_raw(BM)

    # Schwerpunkt: 28 % MAC
    lam = CTIP / CROOT
    mac = 2 / 3 * CROOT * (1 + lam + lam * lam) / (1 + lam)
    cg = Vector((0.0, YQC - 0.25 * mac + 0.28 * mac, -0.10))
    print("MAC %.3f m, CG %s" % (mac, tuple(round(c, 3) for c in cg)))

    raws = [o for o in scene.objects if o.get("group")]
    groups = {g: [o for o in raws if o["group"] == g] for g in ('fus', 'wing', 'detail')}

    # ---------------- UV ----------------
    for g, objs in groups.items():
        uv_unwrap(objs, 0.004 if g != 'detail' else 0.006)

    # ---------------- Texturen ----------------
    insig_own = os.path.join(TEX, "insignia_own.png")
    insig_enemy = os.path.join(TEX, "insignia_enemy.png")
    discp = os.path.join(TEX, "prop_disc.png")
    make_insignia('own', insig_own)
    make_insignia('enemy', insig_enemy)
    make_prop_disc(discp)

    gear_like = [o for o in raws if o["node"].startswith(("gear_", "wheel_", "tailwheel")) or o["node"] in
                 ("prop_blades", "prop_spinner", "prop_disc", "pilot") or o["group"] in ('glass', 'disc')]
    BM_E = make_bake_materials(PAL_ENEMY)
    texpaths = {}
    for g, objs in groups.items():
        size = DETSIZE if g == 'detail' else TEXSIZE
        pre = "fighter_t1_%s" % g
        hide = [o for o in gear_like if o not in objs] if g != 'detail' else [o for o in raws if o["group"] in ('glass', 'disc')]
        res = bake_group(objs, BM, size, ['albedo', 'rough', 'metal', 'normal', 'ao'], pre, hide)
        pa = os.path.join(TEX, pre + "_albedo.png")
        pn = os.path.join(TEX, pre + "_normal.png")
        po = os.path.join(TEX, pre + "_orm.png")
        save_image(res['albedo'], pa)
        save_image(res['normal'], pn)
        pack_orm(res['ao'], res['rough'], res['metal'], po)
        res_e = bake_group(objs, BM_E, size, ['albedo'], pre + "_enemy", [])
        pae = os.path.join(TEX, "fighter_t1_enemy_%s_albedo.png" % g)
        save_image(res_e['albedo'], pae)
        texpaths[g] = dict(albedo=pa, normal=pn, orm=po, albedo_enemy=pae)
        for im in list(res.values()) + list(res_e.values()):
            bpy.data.images.remove(im)

    # ---------------- Godot-Materialien ----------------
    FM = {g: pbr_material("M_%s" % {'fus': 'Fuselage', 'wing': 'Wings', 'detail': 'Details'}[g],
                          texpaths[g]['albedo'], texpaths[g]['normal'], texpaths[g]['orm']) for g in groups}
    FM['glass'] = glass_material()
    FM['decal'] = decal_material("M_Insignia", insig_own)
    FM['disc'] = disc_material("M_PropDisc", discp)

    # ---------------- Abziehbilder ----------------
    def raws_of(node, grp=None):
        return [o for o in raws if o["node"] == node and (grp is None or o["group"] == grp)]
    ROUND = (0.0, 0.0, 0.5, 1.0)
    FLASH = (0.5, 0.1, 1.0, 0.9)
    decals = []
    for sgn, side in ((1, 'L'), (-1, 'R')):
        tw = raws_of('wing_' + side, 'wing')
        nup = Vector((-sgn * math.sin(DIH), 0, math.cos(DIH)))
        fW, _, _ = wing_frame(sgn, 3.75)
        cen = Vector((sgn * 3.75, -1.25, fW(0.3, 0)[2]))
        decals.append(('decal_wing_%s_top' % side, 'wing_' + side, make_decal('decal_wing_%s_top' % side, tw, cen, nup, (sgn, 0, 0), (0.84, 0.84), ROUND)))
        decals.append(('decal_wing_%s_bottom' % side, 'wing_' + side, make_decal('decal_wing_%s_bottom' % side, tw, cen, -nup, (-sgn, 0, 0), (0.84, 0.84), ROUND)))
        decals.append(('decal_fuselage_%s' % side, 'fuselage', make_decal('decal_fuselage_%s' % side, [o for o in raws if o.name == "Fuselage"],
                                                                        (sgn * 0.3, 2.05, 0.02), (sgn, 0, 0), (0, sgn, 0), (0.54, 0.54), ROUND)))
        decals.append(('decal_fin_%s' % side, 'fuselage', make_decal('decal_fin_%s' % side, [o for o in raws if o.name == "Fin_raw"],
                                                                   (sgn * 0.1, 4.02, 0.74), (sgn, 0, 0), (0, sgn, 0), (0.32, 0.256), FLASH, grid=4)))
    for nm, node, ob in decals:
        ob.data.materials.append(FM['decal'])
        ob["group"] = 'decal'
        ob["node"] = nm
        rig[nm] = dict(pivot=cg, kind='decal', parent=node)

    # ---------------- Endmaterialien auf Rohteile ----------------
    for o in raws:
        g = o["group"]
        if g in FM:
            if g == 'glass':
                o.data.materials.clear(); o.data.materials.append(FM['glass'])
            elif g == 'disc':
                o.data.materials.clear(); o.data.materials.append(FM['disc'])
            else:
                for i in range(len(o.data.materials)):
                    o.data.materials[i] = FM[g]
    # Glas braucht UVs fuer konsistente Primitive (einfach projiziert)
    for o in raws:
        if o["group"] == 'glass' and not o.data.uv_layers:
            uvl = o.data.uv_layers.new(name="UVMap")

    # ---------------- Knoten bilden ----------------
    nodes = {}
    all_raw = [o for o in scene.objects if o.get("node")]
    by_node = {}
    for o in all_raw:
        by_node.setdefault(o["node"], []).append(o)
    for name in sorted(by_node):
        parts = by_node[name]
        select_only(parts)
        if len(parts) > 1:
            bpy.ops.object.join()
        ob = bpy.context.view_layer.objects.active
        ob.name = name
        ob.data.name = name
        for k in ("group", "node"):
            if k in ob:
                del ob[k]
        dedupe_materials(ob)
        nodes[name] = ob

    root = bpy.data.objects.new("fighter_t1", None)
    col().objects.link(root)
    root.empty_display_size = 1.0

    # Weltmatrizen (nach CG-Verschiebung)
    Wm = {}
    info = {}
    defaults = {'fuselage': dict(pivot=cg, kind='static', parent=None), 'wing_L': dict(pivot=cg, kind='static', parent='fuselage'),
                'wing_R': dict(pivot=cg, kind='static', parent='fuselage'), 'stabilizer': dict(pivot=cg, kind='static', parent='fuselage'),
                'pilot': dict(pivot=cg, kind='static', parent='fuselage'),
                'prop_blades': dict(pivot=rig['propeller']['pivot'], kind='static', parent='propeller'),
                'prop_spinner': dict(pivot=rig['propeller']['pivot'], kind='static', parent='propeller')}
    for k, v in defaults.items():
        rig.setdefault(k, v)
    if 'propeller' not in nodes:
        pe = bpy.data.objects.new("propeller", None)
        col().objects.link(pe)
        nodes['propeller'] = pe
    order = ['fuselage', 'wing_L', 'wing_R', 'stabilizer', 'elevator', 'rudder', 'canopy', 'pilot', 'propeller',
             'prop_blades', 'prop_spinner', 'prop_disc', 'aileron_L', 'aileron_R', 'flap_L', 'flap_R',
             'gear_main_L', 'gear_main_R', 'gear_door_L', 'gear_door_R', 'wheel_main_L', 'wheel_main_R',
             'tailwheel', 'wheel_tail'] + [d[0] for d in decals]
    for name in order:
        r = rig[name]
        kind = r['kind']
        if kind in ('hinge', 'rudder', 'gear', 'steer'):
            B = hinge_basis(r['axis'], kind)
        else:
            B = Matrix.Identity(3)
        if kind == 'follow':
            B = Wm[r['parent']].to_3x3()
            Pv = r['pivot']
        else:
            Pv = r['pivot']
        Mloc = Matrix.Translation(Pv) @ B.to_4x4()
        ob = nodes[name]
        if ob.type == 'MESH':
            ob.data.transform(Mloc.inverted())
            ob.data.update()
        Wm[name] = Matrix.Translation(-cg) @ Mloc
        par = nodes[r['parent']] if r.get('parent') else root
        Wp = Wm[r['parent']] if r.get('parent') else Matrix.Identity(4)
        ob.parent = par
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.matrix_basis = Wp.inverted() @ Wm[name]

    # ---------------- Marker ----------------
    def surf_point(objs, origin, direction):
        best = None
        for o in objs:
            if o.type != 'MESH':
                continue
            inv = o.matrix_world.inverted()
            ok, loc, nrm, idx = o.ray_cast(inv @ origin, (inv.to_3x3() @ direction).normalized())
            if ok:
                wl = o.matrix_world @ loc
                d = (wl - origin).length
                if best is None or d < best[0]:
                    best = (d, wl)
        return best[1] if best else origin

    bpy.context.view_layer.update()
    markers = {}

    def marker(name, pos_world_orig, extras=None, display='PLAIN_AXES', size=0.15):
        e = bpy.data.objects.new(name, None)
        col().objects.link(e)
        e.empty_display_type = display
        e.empty_display_size = size
        e.parent = root
        e.location = pos_world_orig - cg
        if extras:
            for k, v in extras.items():
                e[k] = v
        markers[name] = dict(pos=C(pos_world_orig - cg), **(extras or {}))
        return e
    shifted = lambda v: v - cg  # noqa
    W_all = [nodes[n] for n in ('fuselage', 'wing_L', 'wing_R')]

    def sp(origin, direction):
        return surf_point(W_all, Vector(origin) - cg, Vector(direction)) + cg

    # Schadenszonen (Halbachsen in Godot-Achsen x, y=oben, z=vorne)
    zones = {
        'engine': ((0, -3.2, -0.05), (0.45, 0.45, 0.85)),
        'fuel_tank_L': ((1.15, -1.35, -0.32), (0.50, 0.12, 0.45)),
        'fuel_tank_R': ((-1.15, -1.35, -0.32), (0.50, 0.12, 0.45)),
        'cockpit': ((0, -0.20, 0.45), (0.35, 0.45, 0.80)),
        'wing_L': ((3.0, -1.25, -0.15), (2.35, 0.25, 0.85)),
        'wing_R': ((-3.0, -1.25, -0.15), (2.35, 0.25, 0.85)),
        'tail': ((0, 4.15, 0.55), (1.85, 0.90, 0.75)),
    }
    for k, (c_, h_) in zones.items():
        marker("dmg_" + k, Vector(c_), {"half_extents": list(h_)}, 'CUBE', 0.2)
    for side in ('L', 'R'):
        marker("gun_wing_" + side, rig['_gun_' + side], {"fire_dir": [0, 0, 1], "caliber_mm": 7.9})
        g = rig['_ammo_' + side]
        marker("ammo_bay_" + side, sp((g.x, g.y, 2.0), (0, 0, -1)))
        sgn = 1 if side == 'L' else -1
        marker("hardpoint_wing_" + side, sp((sgn * 2.75, -1.45, -2.0), (0, 0, 1)), {"max_kg": 50})
        marker("wingtip_" + side, rig['_tip_' + side])
        y = -3.13
        marker("exhaust_" + side, Vector((sgn * (fus_at(y)[1] * 0.93 + 0.07), y + 0.03, 0.09)), {"dir": [sgn, -0.1, 0.1]})
        gm = rig['gear_main_' + side]
        marker("contact_main_" + side, rig['wheel_main_' + side]['pivot'] - Vector((0, 0, 0.34)))
    marker("hardpoint_center", sp((0, -2.35, -2.0), (0, 0, 1)), {"max_kg": 250})
    marker("fuel_port", sp((0, -1.65, 2.0), (0, 0, -1)))
    marker("contact_tail", rig['wheel_tail']['pivot'] - Vector((0, 0, 0.115)))
    marker("cam_cockpit", Vector((0, 0.08, 0.80)))
    marker("cg", cg)
    # M3 Bodenbetrieb: Service-Marker (feste Namen, ServiceMarkers.AIRCRAFT)
    for nm_, (o_, d_, off_) in SVC_SPECS.items():
        marker(nm_, surf_point(W_all, Vector(o_), Vector(d_)) + Vector(off_) + cg)

    # ---------------- Kollision ----------------
    def hull(name, pts):
        bm = bmesh.new()
        for p_ in pts:
            bm.verts.new(Vector(p_) - cg)
        bmesh.ops.convex_hull(bm, input=bm.verts)
        loose = [v for v in bm.verts if not v.link_faces]
        bmesh.ops.delete(bm, geom=loose, context='VERTS')
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new(name, me)
        col().objects.link(o)
        o.parent = root
        o.display_type = 'WIRE'
        return o
    fr = rings['fus']
    fpts = [p_ for i, r_ in enumerate(fr) if i % 6 == 0 or i == len(fr) - 1 for j, p_ in enumerate(r_) if j % 5 == 0]
    fpts += [(0, -0.3, 0.93), (0.3, -0.3, 0.6), (-0.3, -0.3, 0.6), (0, 1.0, 0.72)]
    cols = [hull("col_fuselage-convcolonly", fpts)]
    for side in ('L', 'R'):
        sgn = 1 if side == 'L' else -1
        pts = []
        for x in (0.55, 4.6, 5.2):
            f_, c_, th_ = wing_frame(sgn, x)
            for (a, v) in prof_full(0.02, 0.4, th_, 7):
                pts.append(f_(a, v))
        cols.append(hull("col_wing_%s-convcolonly" % side, pts))
    pts = []
    for sgn in (1, -1):
        for x in (0.0, 1.8):
            f_, c_, th_ = hstab_frame(sgn, x)
            pts += [f_(a, v) for (a, v) in prof_full(0, 0.4, th_, 5)]
    cols.append(hull("col_stabilizer-convcolonly", pts))
    pts = []
    for t in (0.0, 0.95):
        f_, c_, th_ = fin_frame(t)
        pts += [f_(a, v) for (a, v) in prof_full(0, 0.4, th_, 5)]
    cols.append(hull("col_fin-convcolonly", pts))

    # ---------------- Statistik ----------------
    tri = {n: tri_count(o) for n, o in nodes.items() if o.type == 'MESH'}
    total = sum(tri.values())
    print("TRIS", total, json.dumps(tri, indent=0))

    # ---------------- Bodenlage ----------------
    yM, zM = rig['wheel_main_L']['pivot'].y - cg.y, rig['wheel_main_L']['pivot'].z - cg.z - 0.34
    yT, zT = rig['wheel_tail']['pivot'].y - cg.y, rig['wheel_tail']['pivot'].z - cg.z - 0.115
    best = None
    for k in range(40001):
        a = math.radians(-25 + k * 0.001)
        d = (yM * math.sin(a) + zM * math.cos(a)) - (yT * math.sin(a) + zT * math.cos(a))
        if best is None or abs(d) < abs(best[1]):
            best = (a, d)
    a_g = best[0]
    h_g = -(yM * math.sin(a_g) + zM * math.cos(a_g))

    # ---------------- Rig-JSON ----------------
    def node_entry(name, r, extra):
        e = dict(node=name, parent=r.get('parent') or 'fighter_t1', pivot=C(Wm[name].translation))
        e.update(extra)
        return e
    parts = {}
    for side in ('L', 'R'):
        for nm, rng, desc in (('aileron_' + side, [-20, 15], "positiv = Hinterkante nach unten"),
                              ('flap_' + side, [0, 40], "positiv = Klappe nach unten (Landung 40)")):
            ax = Wm[nm].to_3x3() @ Vector((1, 0, 0))
            parts[nm] = node_entry(nm, rig[nm], dict(type="rotate", axis_local="x", axis_model=C(ax),
                                                     min_deg=rng[0], max_deg=rng[1], sign=desc))
        gname = 'gear_main_' + side
        ax = Wm[gname].to_3x3() @ Vector((1, 0, 0))
        parts[gname] = node_entry(gname, rig[gname], dict(
            type="rotate", axis_local="x", axis_model=C(ax), extended_deg=0.0,
            retracted_deg=round(rig[gname]['angle'], 2),
            sign="positiv = einfahren (nach innen in die Fluegelwurzel)", children=["gear_door_" + side, "wheel_main_" + side],
            note="Bein + Klappe + Rad; Pivot am oberen Gelenk im Fluegel"))
        parts['gear_door_' + side] = node_entry('gear_door_' + side, rig['gear_door_' + side], dict(
            type="fixed_to_parent", note="Beinklappe, bewegt sich mit gear_main"))
        parts['wheel_main_' + side] = node_entry('wheel_main_' + side, rig['wheel_main_' + side], dict(
            type="spin", axis_local="x", radius_m=0.34, sign="positiv = Rollen vorwaerts"))
    ax = Wm['elevator'].to_3x3() @ Vector((1, 0, 0))
    parts['elevator'] = node_entry('elevator', rig['elevator'], dict(type="rotate", axis_local="x", axis_model=C(ax),
                                   min_deg=-25, max_deg=20, sign="positiv = Hinterkante unten (Nase runter); beide Haelften in einem Objekt"))
    ax = Wm['rudder'].to_3x3() @ Vector((0, 0, 1))
    parts['rudder'] = node_entry('rudder', rig['rudder'], dict(type="rotate", axis_local="y", axis_model=C(ax),
                                 min_deg=-25, max_deg=25, sign="positiv = Hinterkante nach rechts (-X) -> Gieren nach rechts"))
    ax = Wm['tailwheel'].to_3x3() @ Vector((0, 0, 1))
    parts['tailwheel'] = node_entry('tailwheel', rig['tailwheel'], dict(type="rotate", axis_local="y", axis_model=C(ax),
                                    min_deg=-35, max_deg=35, sign="positiv = Rad schwenkt nach +X (Pilot links); frei schwenkend oder an Seitenruder koppeln (gleiches Vorzeichen wie rudder = Gegenrichtung beachten)",
                                    children=["wheel_tail"]))
    parts['wheel_tail'] = node_entry('wheel_tail', rig['wheel_tail'], dict(type="spin", axis_local="x", radius_m=0.115,
                                     sign="positiv = Rollen vorwaerts"))
    parts['propeller'] = node_entry('propeller', rig['propeller'], dict(type="spin", axis_local="z", axis_model=[0, 0, 1],
                                    sign="positiv um +Z (von vorne gesehen gegen den Uhrzeigersinn, aus dem Cockpit im Uhrzeigersinn)",
                                    children=["prop_blades", "prop_spinner"], radius_m=1.53, blades=3))
    parts['prop_disc'] = node_entry('prop_disc', rig['prop_disc'], dict(type="toggle",
                                    note="halbtransparente Scheibe; bei hoher Drehzahl einblenden und prop_blades ausblenden. Standard: sichtbar -> im Spiel per Code setzen."))
    parts['canopy'] = node_entry('canopy', rig['canopy'], dict(type="translate", axis_local="z", closed_m=0.0, open_m=-0.55,
                                 sign="Haube gleitet nach hinten: position.z von 0 bis -0.55"))
    parts['pilot'] = dict(node='pilot', parent='fuselage', type="toggle", note="einfache Pilotenfigur, ausblendbar")

    data = dict(
        model="fighter_t1_game.glb", enemy_model="fighter_t1_game_enemy.glb",
        convention=dict(up="+Y", forward_nose="+Z", left_wing="+X (Pilot links)", units="m",
                        origin="Schwerpunkt (28 %% MAC, MAC = %.3f m)" % mac,
                        angles="Grad; Rotation um die angegebene LOKALE Achse des Knotens, Ausgangslage = 0 (Transform aus dem GLB beibehalten und relativ drehen, z.B. node.transform.basis = rest_basis * Basis(axis, deg_to_rad(a)))"),
        ground=dict(root_rotation_x_deg=round(math.degrees(a_g), 3), nose_up_deg=round(-math.degrees(a_g), 3),
                    origin_height_m=round(h_g, 3), note="Dreipunktlage: Wurzel um X drehen, dann auf Hoehe origin_height_m ueber Boden setzen"),
        parts=parts, markers=markers,
        collision=[o.name for o in cols],
        materials=dict(
            M_Fuselage=dict(albedo=os.path.basename(texpaths['fus']['albedo']), normal=os.path.basename(texpaths['fus']['normal']),
                            orm=os.path.basename(texpaths['fus']['orm']), enemy_albedo=os.path.basename(texpaths['fus']['albedo_enemy'])),
            M_Wings=dict(albedo=os.path.basename(texpaths['wing']['albedo']), normal=os.path.basename(texpaths['wing']['normal']),
                         orm=os.path.basename(texpaths['wing']['orm']), enemy_albedo=os.path.basename(texpaths['wing']['albedo_enemy'])),
            M_Details=dict(albedo=os.path.basename(texpaths['detail']['albedo']), normal=os.path.basename(texpaths['detail']['normal']),
                           orm=os.path.basename(texpaths['detail']['orm']), enemy_albedo=os.path.basename(texpaths['detail']['albedo_enemy'])),
            M_Insignia=dict(albedo="insignia_own.png", enemy_albedo="insignia_enemy.png",
                            note="Abzeichen-Atlas 1024x512: links Rundabzeichen, rechts Leitwerksmarkierung; Nation = Textur tauschen"),
            M_PropDisc=dict(albedo="prop_disc.png"), M_Glass=dict()),
        triangles=dict(total=total, per_node=tri),
        lod="Nur LOD0 geliefert; Godot erzeugt LODs beim Import (mesh/generate_lods = an).",
    )

    # ---------------- Export ----------------
    def export(path):
        bpy.ops.object.select_all(action='DESELECT')
        root.select_set(True)
        for o in root.children_recursive:
            o.select_set(True)
        kw = dict(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
                  export_extras=True, export_cameras=False, export_lights=False, export_tangents=True,
                  export_animations=False)
        try:
            bpy.ops.export_scene.gltf(**kw)
        except TypeError as e:
            print("Exportparameter:", e)
            kw.pop('export_animations', None)
            bpy.ops.export_scene.gltf(**kw)
        print("GLB:", path, os.path.getsize(path) / 1e6, "MB")

    out_own = os.path.join(MODELS, "fighter_t1_game.glb")
    export(out_own)
    # Gegner: gleiche Geometrie, andere Albedo + Abzeichen
    swap = {'M_Fuselage': texpaths['fus']['albedo_enemy'], 'M_Wings': texpaths['wing']['albedo_enemy'],
            'M_Details': texpaths['detail']['albedo_enemy'], 'M_Insignia': insig_enemy}
    for mn, pth in swap.items():
        m = bpy.data.materials[mn]
        m.node_tree.nodes["albedo"].image = load_img(pth, False)
    root.name = "fighter_t1_enemy"
    out_enemy = os.path.join(MODELS, "fighter_t1_game_enemy.glb")
    export(out_enemy)
    root.name = "fighter_t1"
    data["file_sizes_mb"] = {os.path.basename(p): round(os.path.getsize(p) / 1e6, 2) for p in (out_own, out_enemy)}
    with open(os.path.join(MODELS, "fighter_t1_rig.json"), "w") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
    print("FERTIG in %.1f s" % (time.time() - t_start))


# ============================================================================
# M3: Service-Marker (Bodenbetrieb). Blender-Koordinaten relativ zum Schwerpunkt:
# Strahl-Ursprung, Richtung, Versatz nach dem Treffer. Namen = ServiceMarkers.AIRCRAFT.
# ============================================================================
SVC_SPECS = {
    "svc_fuel_cap": ((0.0, -0.25, 3.0), (0, 0, -1), (0, 0, 0.02)),        # Tankdeckel oben vor der Haube
    "svc_gun_hatch_L": ((2.35, 0.10, 3.0), (0, 0, -1), (0, 0, 0.02)),     # MG-Klappe Fluegeloberseite links
    "svc_gun_hatch_R": ((-2.35, 0.10, 3.0), (0, 0, -1), (0, 0, 0.02)),    # ... rechts
    "svc_entry": ((1.05, 0.75, 3.0), (0, 0, -1), (0, 0, 0.02)),           # Trittflaeche Fluegelwurzel links
    "svc_engine": ((2.5, -2.0, 0.10), (-1, 0, 0), (0.05, 0, 0)),          # Motorhaube linke Seite
}


def add_svc_markers():
    """Fuegt die svc_*-Marker als leere Knoten in die fertigen GLBs ein, ohne Geometrie,
    Materialien oder Texturen anzufassen (nur der JSON-Block wird ergaenzt). Positionen per
    Strahl auf Rumpf/Fluegel des re-importierten Modells. Bestehende Marker bleiben unveraendert."""
    import struct
    own = os.path.join(MODELS, "fighter_t1_game.glb")
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=own)
    bpy.context.view_layer.update()
    W = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name in ('fuselage', 'wing_L', 'wing_R')]
    pts = {}
    for nm, (o_, d_, off_) in SVC_SPECS.items():
        best = None
        org, dr = Vector(o_), Vector(d_).normalized()
        for o in W:
            inv = o.matrix_world.inverted()
            ok, loc, _n, _i = o.ray_cast(inv @ org, (inv.to_3x3() @ dr).normalized())
            if ok:
                wl = o.matrix_world @ loc
                if best is None or (wl - org).length < (best - org).length:
                    best = wl
        if best is None:
            raise RuntimeError("kein Treffer fuer " + nm)
        pts[nm] = C(best + Vector(off_))
    print("SVC", pts)
    for fn in ("fighter_t1_game.glb", "fighter_t1_game_enemy.glb"):
        path = os.path.join(MODELS, fn)
        b = open(path, "rb").read()
        jl = struct.unpack("<I", b[12:16])[0]
        j = json.loads(b[20:20 + jl].decode("utf-8"))
        rest = b[20 + jl:]
        nodes = j["nodes"]
        root = j["scenes"][j.get("scene", 0)]["nodes"][0]
        kids = nodes[root].setdefault("children", [])
        for nm, pos in pts.items():
            idx = next((i for i, n in enumerate(nodes) if n.get("name") == nm), None)
            if idx is None:
                nodes.append({"name": nm, "translation": pos})
                kids.append(len(nodes) - 1)
            else:
                nodes[idx]["translation"] = pos
        js = json.dumps(j, separators=(",", ":")).encode("utf-8")
        js += b" " * ((4 - len(js) % 4) % 4)
        out = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + len(rest)) + struct.pack("<II", len(js), 0x4E4F534A) + js + rest
        open(path, "wb").write(out)
        print("GLB gepatcht:", path, len(out) / 1e6, "MB")
    rp = os.path.join(MODELS, "fighter_t1_rig.json")
    with open(rp) as fh:
        rig = json.load(fh)
    for nm, pos in pts.items():
        rig["markers"][nm] = dict(pos=pos)
    with open(rp, "w") as fh:
        json.dump(rig, fh, indent=2, ensure_ascii=False)


# ============================================================================
# Pruef-Renders (GLB re-importiert)
# ============================================================================
def look_at(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def render_check(glb, tagname):
    reset_scene()
    scene = bpy.context.scene
    bpy.ops.import_scene.gltf(filepath=glb)
    with open(os.path.join(MODELS, "fighter_t1_rig.json")) as fh:
        rigd = json.load(fh)
    objs = {o.name: o for o in scene.objects}
    for o in scene.objects:
        if "colonly" in o.name:
            o.hide_render = True
            o.hide_viewport = True
    root = [o for o in scene.objects if o.parent is None and o.name.startswith("fighter_t1")][0]
    pd = objs.get("prop_disc")
    if pd:
        pd.hide_render = True

    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 640, 360
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = 'AgX'
    try:
        scene.view_settings.look = 'AgX - Medium High Contrast'
    except Exception:
        pass
    w = bpy.data.worlds.new("W")
    scene.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = nt.nodes["Background"]
    sky = nt.nodes.new("ShaderNodeTexGradient") if False else None
    bg.inputs[0].default_value = (0.42, 0.52, 0.68, 1)
    bg.inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
    sun.data.energy = 3.8
    sun.data.angle = math.radians(2.0)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    gmat = bpy.data.materials.new("Ground")
    gmat.use_nodes = True
    gp = gmat.node_tree.nodes["Principled BSDF"]
    gp.inputs['Base Color'].default_value = (0.20, 0.21, 0.19, 1)
    gp.inputs['Roughness'].default_value = 0.9
    bpy.ops.mesh.primitive_plane_add(size=200)
    ground = bpy.context.active_object
    ground.data.materials.append(gmat)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.data.lens = 40

    g = rigd['ground']
    ground_pose = (Matrix.Translation((0, 0, g['origin_height_m'])) @ Matrix.Rotation(math.radians(g['root_rotation_x_deg']), 4, 'X'))
    rest = {o.name: o.matrix_basis.copy() for o in scene.objects}

    def reset_pose():
        for o in scene.objects:
            if o.name in rest:
                o.matrix_basis = rest[o.name]

    def gaxis(a):
        return {'x': Vector((1, 0, 0)), 'y': Vector((0, 0, 1)), 'z': Vector((0, -1, 0))}[a]

    def pose(name, value):
        o = objs.get(name)
        p = rigd['parts'][name]
        if p['type'] == 'translate':
            o.matrix_basis = rest[name] @ Matrix.Translation(gaxis(p['axis_local']) * value)
        else:
            o.matrix_basis = rest[name] @ Matrix.Rotation(math.radians(value), 4, gaxis(p['axis_local']))

    def shot(fname, cam_pos, target, lens=40, on_ground=True):
        ground.hide_render = not on_ground
        root.matrix_basis = ground_pose if on_ground else Matrix.Identity(4)
        cam.location = cam_pos
        cam.data.lens = lens
        bpy.context.view_layer.update()
        look_at(cam, target)
        scene.render.filepath = os.path.join(PREV, fname)
        t0 = time.time()
        bpy.ops.render.render(write_still=True)
        print("render", fname, "%.1fs" % (time.time() - t0))

    tg = "" if tagname == "own" else "_" + tagname
    shot("game_model_front34%s.png" % tg, (-7.5, -9.5, 2.6), (0, -0.5, 1.4), 38)
    shot("game_model_rear34%s.png" % tg, (8.5, 9.0, 5.0), (0, 0, 1.0), 38)
    shot("game_model_below%s.png" % tg, (-6.0, -7.0, -5.0), (0, 0.3, 0), 36, on_ground=False)
    # Rig-Ansicht: Fahrwerk ein, Ruder ausgeschlagen, Haube offen
    reset_pose()
    for s in ('L', 'R'):
        pose('gear_main_' + s, rigd['parts']['gear_main_' + s]['retracted_deg'])
    pose('aileron_L', 15); pose('aileron_R', -20)
    pose('flap_L', 40); pose('flap_R', 40)
    pose('elevator', -25); pose('rudder', 25)
    pose('canopy', -0.55)
    pose('tailwheel', 30)
    shot("game_model_rig_below%s.png" % tg, (6.5, -7.5, -4.5), (0, 0.3, -0.2), 36, on_ground=False)
    shot("game_model_rig_top%s.png" % tg, (-6.5, 8.0, 6.0), (0, 0.5, 0.2), 36, on_ground=False)
    if OPT.get("closeups"):
        shot("game_model_rig_gear%s.png" % tg, (1.2, -3.2, -3.2), (1.3, 0.0, -0.3), 30, on_ground=False)
        shot("game_model_rig_tail%s.png" % tg, (-3.0, 9.0, 2.2), (0, 5.4, 0.5), 40, on_ground=False)
        shot("game_model_rig_wing%s.png" % tg, (-4.0, 4.5, 1.8), (-3.6, 0.2, -0.2), 35, on_ground=False)
        reset_pose()
        pose('gear_main_L', rigd['parts']['gear_main_L']['retracted_deg'] * 0.5)
        shot("game_model_rig_gearhalf%s.png" % tg, (4.5, -1.6, -1.2), (1.2, 0.0, -0.6), 32, on_ground=False)
    reset_pose()


if OPT["build"]:
    main_build()
if OPT["add_svc"]:
    add_svc_markers()
if OPT["render"]:
    render_check(OPT["glb"] or os.path.join(MODELS, "fighter_t1_game.glb"), OPT["tag"])
