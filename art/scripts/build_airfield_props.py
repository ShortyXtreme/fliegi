# -*- coding: utf-8 -*-
"""
Platz-Modelle fuer M3 "Bodenbetrieb" (Stil B: stilisiert-realistisch, PBR, Tarnfarben, Abnutzung).
Eigene Designs, keine echten Marken/Hoheitszeichen.

Aufruf (headless, Cycles CPU):
  blender -b -P build_airfield_props.py -- --build [--only fuel_truck,ammo_cart] [--quick]
  blender -b -P build_airfield_props.py -- --render           # Kontroll-Renders aus den GLBs

Ergebnisse: art/models/ground/<name>.glb (+ Kopie game/assets/ground/), art/textures/ground/*,
            art/models/ground/ground_props.json (Dreiecke, Marker, Konventionen),
            art/previews/ground_*.png

Konventionen (Blender intern Z oben, vorn +Y, rechts +X) -> glTF/Godot: Y oben, vorn -Z, rechts +X.
Ursprung = Boden (y = 0); Fahrzeuge: Mitte zwischen den Achsen, Gebaeude/Props: Mitte der Grundflaeche.
Marker = leere Knoten mit den festen Namen aus ServiceMarkers (hose_reel, seat_driver, ...).
Alle Oberflaechen-Effekte werden in 1 Atlas je Modell gebacken (Albedo, Normal, ORM).
"""
import bpy, math, sys, os, json, time, shutil
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv_saved = sys.argv
sys.argv = [a for a in sys.argv if a not in ("--build", "--quick", "--render")]  # BGA nichts ausfuehren lassen
import build_game_aircraft as BGA  # noqa: E402  (Geometrie-, Bake- und Material-Helfer)
sys.argv = _argv_saved
from build_game_aircraft import (NB, new_mat, col, C, mesh_from, loft, tube, cyl, box_geo, rbox_geo,  # noqa
                                 tire_geo, merge_geo, select_only, uv_unwrap, bake_group, pack_orm,
                                 save_image, pbr_material, worn_metal, tri_count, reset_scene)

ART = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
MODELS = os.path.join(ART, "models", "ground")
TEX = os.path.join(ART, "textures", "ground")
PREV = os.path.join(ART, "previews")
GAME = os.path.abspath(os.path.join(ART, "..", "game", "assets", "ground"))
for d in (MODELS, TEX, PREV, GAME):
    os.makedirs(d, exist_ok=True)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OPT = {"build": "--build" in argv, "render": "--render" in argv, "quick": "--quick" in argv, "only": None}
for k, a in enumerate(argv):
    if a == "--only":
        OPT["only"] = argv[k + 1].split(",")
BGA.SAMPLES = dict(color=1, normal=2, ao=4 if OPT["quick"] else 12)

# ============================================================================
# Bake-Materialien (prozedural, werden gebacken)
# ============================================================================
OLIVE = (0.095, 0.115, 0.050)
OLIVE2 = (0.16, 0.13, 0.065)
BLACK = (0.025, 0.025, 0.025)
STEEL = (0.50, 0.50, 0.49)
RUST = (0.20, 0.085, 0.035)
MUD = (0.13, 0.10, 0.065)


def _coord(b):
    return b.n("ShaderNodeTexCoord").outputs['Object']


def paint(key, base, base2=None, chip=(0.30, 0.29, 0.27), dirt=0.55, rough=0.6, scale=1.0,
          camo=0.0, dirt_h=0.9, streak=0.25, metal_chip=1.0):
    """Lack mit Farbschwankung, optional 2-Ton-Tarnung, Abplatzern (Metall), Schmutz unten, Laufspuren."""
    m = new_mat("Bake_" + key)
    b = NB(m)
    p = b.principled()
    P = _coord(b)
    xyz = b.sep(P)
    var = b.noise(P, 2.5 * scale, 4, 0.5).outputs['Fac']
    col_ = b.mix(b.maprange(var, 0.3, 0.7), tuple(c * 0.82 for c in base), tuple(min(1, c * 1.15) for c in base))
    if base2 is not None and camo > 0:
        cm = b.noise(b.mapping(P, (0.35 * scale,) * 3, (3.1, 1.7, 0.4)), 1.0, 3, 0.45, 0.3).outputs['Fac']
        col_ = b.mix(b.maprange(cm, 0.5, 0.53), col_, base2)
    # Laufspuren (senkrecht gestreckt)
    st = b.noise(b.mapping(P, (14 * scale, 14 * scale, 0.9 * scale)), 1.0, 3, 0.6).outputs['Fac']
    stm = b.maprange(st, 0.55, 0.85, 0, streak)
    col_ = b.mix(stm, col_, MUD)
    # Schmutz von unten
    dn = b.noise(P, 6 * scale, 5, 0.6).outputs['Fac']
    dz = b.maprange(xyz[2], 0.0, dirt_h, dirt, 0.0, smooth=True)
    dm = b.math('MULTIPLY', dz, b.maprange(dn, 0.25, 0.65, 0.4, 1.3))
    col_ = b.mix(dm, col_, MUD)
    # Abplatzer
    cn = b.noise(P, 22 * scale, 8, 0.7).outputs['Fac']
    chipm = b.maprange(cn, 0.70, 0.73)
    col_ = b.mix(chipm, col_, chip)
    b.l(col_, p.inputs['Base Color'])
    b.l(b.mixf(chipm, b.maprange(var, 0, 1, rough - 0.08, rough + 0.12), 0.35), p.inputs['Roughness'])
    b.l(b.mixf(chipm, 0.0, metal_chip), p.inputs['Metallic'])
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 0.25
    bump.inputs['Distance'].default_value = 0.01
    fine = b.noise(P, 90 * scale, 4, 0.5).outputs['Fac']
    b.l(b.math('ADD', b.math('MULTIPLY', chipm, -0.6), b.math('MULTIPLY', fine, 0.15)), bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    return m


def wood(key, base=(0.30, 0.21, 0.12), axis=0, plank=0.14, weather=0.5, scale=1.0):
    """Bretter: Fugen quer zu 'axis', Maserung laengs, vergraut."""
    m = new_mat("Bake_" + key)
    b = NB(m)
    p = b.principled()
    P = _coord(b)
    xyz = b.sep(P)
    other = [1, 0, 0][axis] if axis != 2 else 0
    u = xyz[other if axis != 2 else 0]  # Koordinate quer zu den Brettern
    fr = b.math('FRACT', b.math('DIVIDE', u, plank))
    seam = b.math('MAXIMUM', b.maprange(fr, 0.0, 0.04, 1, 0), b.maprange(fr, 0.96, 1.0, 0, 1))
    pid = b.math('FLOOR', b.math('DIVIDE', u, plank))
    sc = [1, 1, 1]
    sc[axis] = 0.08
    grain = b.noise(b.mapping(P, tuple(s * 18 * scale for s in sc)), 1.0, 6, 0.6, 1.5).outputs['Fac']
    pv = b.n("ShaderNodeTexWhiteNoise")
    b.l(pid, pv.inputs[1]) if len(pv.inputs) > 1 else None
    try:
        pv.noise_dimensions = '1D'
        b.l(pid, pv.inputs['W'])
    except Exception:
        pass
    plank_v = pv.outputs['Value']
    c = b.mix(b.maprange(grain, 0.3, 0.75), tuple(x * 0.7 for x in base), base)
    c = b.mix(b.maprange(plank_v, 0, 1, 0, 0.5), c, tuple(x * 0.75 for x in base))
    gn = b.noise(P, 1.5 * scale, 3, 0.5).outputs['Fac']
    c = b.mix(b.maprange(gn, 0.3, 0.7, weather * 0.4, weather), c, (0.32, 0.30, 0.27))
    c = b.mix(b.math('MULTIPLY', seam, 0.85), c, (0.03, 0.025, 0.02))
    dz = b.maprange(xyz[2], 0.0, 0.5, 0.5, 0.0, smooth=True)
    c = b.mix(dz, c, MUD)
    b.l(c, p.inputs['Base Color'])
    b.l(b.maprange(grain, 0, 1, 0.7, 0.9), p.inputs['Roughness'])
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 0.35
    bump.inputs['Distance'].default_value = 0.01
    b.l(b.math('SUBTRACT', b.math('MULTIPLY', grain, 0.3), seam), bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    return m


def corrugated(key, base, axis=1, period=0.15, rust=0.4):
    m = paint(key, base, chip=RUST, dirt=0.6, rough=0.55, scale=0.4, dirt_h=1.5, streak=0.45, metal_chip=0.0)
    nt = m.node_tree
    b = NB(m)
    p = b.principled()
    P = _coord(b)
    xyz = b.sep(P)
    w = b.math('SINE', b.math('MULTIPLY', xyz[axis], 2 * math.pi / period))
    bump = [n for n in nt.nodes if n.type == 'BUMP'][0]
    old = bump.inputs['Height'].links[0].from_socket
    b.l(b.math('ADD', old, b.math('MULTIPLY', w, 2.5)), bump.inputs['Height'])
    bump.inputs['Distance'].default_value = 0.012
    # Rost-Flecken
    rn = b.noise(P, 1.2, 5, 0.65).outputs['Fac']
    bc = p.inputs['Base Color'].links[0].from_socket
    b.l(b.mix(b.maprange(rn, 0.62, 0.72, 0, rust), bc, RUST), p.inputs['Base Color'])
    return m


def rubber(key, tread=False):
    m = new_mat("Bake_" + key)
    b = NB(m)
    p = b.principled()
    P = _coord(b)
    n = b.noise(P, 30, 4, 0.5).outputs['Fac']
    b.l(b.mix(b.maprange(n, 0.3, 0.7), (0.025, 0.025, 0.025), (0.06, 0.055, 0.05)), p.inputs['Base Color'])
    p.inputs['Roughness'].default_value = 0.88
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 0.4
    h = b.math('MULTIPLY', n, 0.2)
    if tread:
        xyz = b.sep(P)
        ang = b.n("ShaderNodeMath", operation='ARCTAN2')
        b.l(xyz[1], ang.inputs[0]); b.l(xyz[2], ang.inputs[1])
        h = b.math('ADD', h, b.math('GREATER_THAN', b.math('SINE', b.math('MULTIPLY', ang.outputs[0], 28)), 0.3))
    b.l(h, bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    return m


def ribbed(key, base, axis=0, period=0.04, rough=0.4, metal=0.0):
    """Kuehlergrill/Lamellen/Schlauchwindungen per Bump."""
    m = new_mat("Bake_" + key)
    b = NB(m)
    p = b.principled()
    P = _coord(b)
    xyz = b.sep(P)
    w = b.math('SINE', b.math('MULTIPLY', xyz[axis], 2 * math.pi / period))
    n = b.noise(P, 12, 4, 0.5).outputs['Fac']
    b.l(b.mix(b.maprange(w, -1, 1), tuple(c * 0.4 for c in base), base), p.inputs['Base Color'])
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 0.8
    b.l(b.math('ADD', w, b.math('MULTIPLY', n, 0.3)), bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    return m


def ground_mat(key, grass=(0.10, 0.13, 0.045), earth=(0.17, 0.12, 0.07), mix=0.5):
    m = new_mat("Bake_" + key)
    b = NB(m)
    p = b.principled()
    P = _coord(b)
    xyz = b.sep(P)
    n1 = b.noise(P, 0.6, 5, 0.6).outputs['Fac']
    n2 = b.noise(P, 9, 6, 0.7).outputs['Fac']
    gr = b.mix(b.maprange(n2, 0.3, 0.7), tuple(c * 0.7 for c in grass), tuple(c * 1.3 for c in grass))
    ea = b.mix(b.maprange(n2, 0.3, 0.7), tuple(c * 0.8 for c in earth), tuple(c * 1.2 for c in earth))
    sl = b.maprange(xyz[2], 0.0, 0.6, 0.35, 0.0)  # Fuss etwas erdiger
    msk = b.math('ADD', b.maprange(n1, mix - 0.08, mix + 0.08), sl)
    b.l(b.mix(msk, gr, ea), p.inputs['Base Color'])
    b.l(b.maprange(n2, 0, 1, 0.85, 1.0), p.inputs['Roughness'])
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 0.6
    b.l(b.math('ADD', n2, b.math('MULTIPLY', n1, 2.0)), bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    return m


def concrete(key, base=(0.29, 0.285, 0.265)):
    m = paint(key, base, chip=(0.28, 0.27, 0.25), dirt=0.6, rough=0.9, scale=0.6, dirt_h=0.7, streak=0.5, metal_chip=0.0)
    return m


def simple(key, color, rough=0.5, metal=0.0):
    m = new_mat("Bake_" + key)
    p = NB(m).principled()
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    return m


class Mats(dict):
    """Lazy-Materialtabelle: key -> Material (Material traegt m['key'] fuer bake_group)."""
    DEF = {
        'olive': lambda: paint('olive', OLIVE, OLIVE2, camo=1.0),
        'olive_plain': lambda: paint('olive_plain', OLIVE, scale=1.5),
        'black': lambda: paint('black', BLACK, chip=(0.25, 0.24, 0.22), dirt=0.7, rough=0.65),
        'tankpaint': lambda: paint('tankpaint', (0.20, 0.22, 0.16), chip=RUST, dirt=0.5, rough=0.5, streak=0.4, dirt_h=1.6),
        'redband': lambda: paint('redband', (0.36, 0.05, 0.03), dirt=0.4),
        'yellow': lambda: paint('yellow', (0.70, 0.52, 0.06), chip=(0.10, 0.10, 0.09), dirt=0.3, rough=0.7, scale=0.8, metal_chip=0.0),
        'red': lambda: paint('red', (0.45, 0.04, 0.03), dirt=0.3, rough=0.4, scale=3),
        'drum': lambda: paint('drum', (0.10, 0.14, 0.15), chip=RUST, dirt=0.6, rough=0.55, streak=0.5, scale=3),
        'steel': lambda: worn_metal("Bake_steel", STEEL, 0.4, 1.0, 0.5, 10),
        'darksteel': lambda: worn_metal("Bake_darksteel", (0.12, 0.12, 0.12), 0.5, 1.0, 0.5, 10),
        'brass': lambda: worn_metal("Bake_brass", (0.62, 0.45, 0.18), 0.35, 1.0, 0.35, 14),
        'rubber': lambda: rubber('rubber'),
        'tire': lambda: rubber('tire', tread=True),
        'hose': lambda: ribbed('hose', (0.05, 0.05, 0.045), axis=0, period=0.045, rough=0.8),
        'grille': lambda: ribbed('grille', (0.12, 0.12, 0.11), axis=0, period=0.035, rough=0.4, metal=1.0),
        'glass': lambda: simple('glass', (0.03, 0.045, 0.05), 0.06),
        'lamp': lambda: simple('lamp', (0.75, 0.72, 0.55), 0.1),
        'wood': lambda: wood('wood', axis=1),
        'wood_x': lambda: wood('wood_x', axis=0),
        'wood_z': lambda: wood('wood_z', (0.27, 0.19, 0.11), axis=2, plank=0.22, weather=0.6, scale=0.5),
        'crate': lambda: wood('crate', (0.26, 0.24, 0.12), axis=0, plank=0.10, weather=0.25, scale=2),
        'roof': lambda: corrugated('roof', (0.14, 0.15, 0.10), axis=1, period=0.16),
        'earth': lambda: ground_mat('earth'),
        'concrete': lambda: concrete('concrete'),
        'canvas': lambda: paint('canvas', (0.20, 0.18, 0.11), dirt=0.5, rough=0.9, scale=2, metal_chip=0.0, chip=(0.14, 0.12, 0.08)),
    }

    def __getitem__(self, k):
        if k not in self:
            m = self.DEF[k]()
            m["key"] = k
            dict.__setitem__(self, k, m)
        return dict.__getitem__(self, k)


# ============================================================================
# Aufbau-Helfer
# ============================================================================
class Asset:
    def __init__(self, name):
        self.name = name
        self.root = bpy.data.objects.new(name, None)
        col().objects.link(self.root)
        self.objs = []
        self.markers = {}
        self.M = Mats()

    def part(self, name, geo, mat, loc=None, parent=None, smooth=False, sharp=35):
        v, f = geo
        o = mesh_from(name, v, f, self.M[mat], smooth=smooth, sharp_angle=sharp)
        o.parent = parent or self.root
        if loc is not None:
            o.location = loc
        self.objs.append(o)
        return o

    def multi(self, name, parts, parent=None, loc=None, smooth=False):
        """Mehrere (geo, mat)-Teile in ein Objekt mit mehreren Materialslots."""
        keys = []
        V, F, FM = [], [], []
        for geo, mk in parts:
            if mk not in keys:
                keys.append(mk)
            o_ = len(V)
            V += list(geo[0])
            for ff in geo[1]:
                F.append(tuple(i + o_ for i in ff))
                FM.append(keys.index(mk))
        import bmesh
        me = bpy.data.meshes.new(name)
        me.from_pydata([tuple(map(float, v)) for v in V], [], [tuple(f) for f in F])
        me.polygons.foreach_set("material_index", FM)
        for k in keys:
            me.materials.append(self.M[k])
        bm = bmesh.new()
        bm.from_mesh(me)
        ngons = [f for f in bm.faces if len(f.verts) > 4]
        if ngons:  # Materialindex bleibt beim Triangulieren erhalten
            bmesh.ops.triangulate(bm, faces=ngons, quad_method='BEAUTY', ngon_method='BEAUTY')
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()
        if smooth:
            me.shade_smooth()
            try:
                me.set_sharp_from_angle(angle=math.radians(35))
            except Exception:
                pass
        o = bpy.data.objects.new(name, me)
        col().objects.link(o)
        o.data.update()
        o.parent = parent or self.root
        if loc is not None:
            o.location = loc
        self.objs.append(o)
        return o

    def marker(self, name, pos, parent=None, **extras):
        e = bpy.data.objects.new(name, None)
        col().objects.link(e)
        e.empty_display_type = 'PLAIN_AXES'
        e.empty_display_size = 0.2
        e.parent = parent or self.root
        e.location = pos
        for k, v in extras.items():
            e[k] = v
        self.markers[name] = dict(pos=C(Vector(pos)), **extras)
        return e


def ring_pts(cx, cz, rx, rz, y, n, a0=0.0):
    return [(cx + rx * math.cos(a0 + 2 * math.pi * k / n), y, cz + rz * math.sin(a0 + 2 * math.pi * k / n)) for k in range(n)]


def cyl_x(x0, x1, y, z, r, seg=16):
    return cyl((x0, y, z), (x1, y, z), r, seg)


def cyl_y(y0, y1, x, z, r, seg=16, r1=None):
    return cyl((x, y0, z), (x, y1, z), r, seg, r1)


def cyl_z(z0, z1, x, y, r, seg=16, r1=None):
    return cyl((x, y, z0), (x, y, z1), r, seg, r1)


def box(x0, x1, y0, y1, z0, z1):
    return box_geo(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0))


def arc_sheet(yc, zc, R, x0, x1, a0, a1, n=14, th=0.025, drop=0.05):
    """Kotfluegel: Bogen in der YZ-Ebene ueber dem Rad, Querschnitt mit leicht abgekanteter Aussenseite."""
    prof = [(x0, 0.0), (x1, 0.0), (x1 + 0.015 * math.copysign(1, x1), -drop), (x1, -drop - 0.005), (x1 - 0.01 * math.copysign(1, x1), -th), (x0, -th)]
    rings = []
    for k in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * k / n)
        rings.append([(px, yc + (R + pr) * math.cos(a), zc + (R + pr) * math.sin(a)) for px, pr in prof])
    return loft(rings, closed=True, cap_start=True, cap_end=True)


def wheel_geo(r=0.46, w=0.11, hub=(0.30, 0.10)):
    t = tire_geo((0, 0, 0), r - 0.10, 0.10, w, seg=20, pseg=8)
    h1 = cyl_x(-w * 0.85, w * 0.85, 0, 0, r - 0.13, 16)
    h2 = cyl_x(-w * 0.9 - 0.02, w * 0.9 + 0.02, 0, 0, 0.09, 10)
    return [(t, 'tire'), (h1, 'black'), (h2, 'darksteel')]


# ============================================================================
# Fahrzeuge
# ============================================================================
AX_F, AX_R, TRACK, WR = 1.85, -1.85, 0.80, 0.46


def build_chassis(A, rear_end=-3.35, reel=False):
    # Rahmen, Achsen, Raeder
    A.multi("chassis", [
        (box(-0.50, -0.42, rear_end + 0.05, 2.90, 0.58, 0.80), 'black'),
        (box(0.42, 0.50, rear_end + 0.05, 2.90, 0.58, 0.80), 'black'),
        (box(-0.50, 0.50, 1.20, 1.30, 0.62, 0.76), 'black'),
        (box(-0.50, 0.50, -0.6, -0.5, 0.62, 0.76), 'black'),
        (box(-0.50, 0.50, rear_end + 0.05, rear_end + 0.15, 0.62, 0.76), 'black'),
        (cyl_x(-0.72, 0.72, AX_F, WR, 0.05, 8), 'darksteel'),
        (cyl_x(-0.72, 0.72, AX_R, WR, 0.07, 8), 'darksteel'),
        (cyl_y(AX_R - 0.15, AX_R + 0.15, 0, WR, 0.16, 10), 'darksteel'),          # Differential
        (cyl_y(AX_R + 0.1, 1.4, 0, 0.62, 0.04, 6), 'darksteel'),                  # Kardanwelle
        (box(-0.48, 0.48, 2.86, 3.02, 0.46, 0.62), 'darksteel'),                   # Stossstange vorn
        (box(-0.85, 0.85, 2.95, 3.04, 0.48, 0.59), 'darksteel'),
        (box(-0.95, 0.95, rear_end - 0.05, rear_end + 0.05, 0.47, 0.60), 'darksteel'),  # hinten
        (cyl_y(-1.0, 0.2, 0.62, 0.55, 0.04, 6), 'darksteel'),                     # Auspuff
        (cyl_y(-1.3, -1.0, 0.62, 0.55, 0.035, 6, 0.03), 'darksteel'),
    ])
    for nm, y, sx in (("wheel_FL", AX_F, -1), ("wheel_FR", AX_F, 1), ("wheel_RL", AX_R, -1), ("wheel_RR", AX_R, 1)):
        A.multi(nm, wheel_geo(), loc=(sx * TRACK, y, WR), smooth=True)
    # Kotfluegel + Trittbretter
    parts = []
    for sx in (-1, 1):
        parts.append((arc_sheet(AX_F, WR, 0.56, sx * 0.62, sx * 1.0, 3, 177), 'olive'))
        parts.append((arc_sheet(AX_R, WR, 0.56, sx * 0.62, sx * 1.02, 8, 172), 'olive'))
        parts.append((box(min(sx * 0.62, sx * 1.0), max(sx * 0.62, sx * 1.0), AX_R + 0.56, AX_F - 0.56, 0.52, 0.56), 'black'))
        parts.append((box(min(sx * 0.5, sx * 0.62), max(sx * 0.5, sx * 0.62), AX_R + 0.6, AX_F - 0.6, 0.53, 0.55), 'black'))
    A.multi("fenders", parts, smooth=True)


def build_cab(A):
    parts = [
        (rbox_geo((0, 2.12, 1.23), (1.0, 1.26, 0.76), 0.12, 2), 'olive'),     # Motorhaube
        (box(-0.47, 0.47, 2.74, 2.80, 0.86, 1.58), 'steel'),                   # Kuehlerrahmen
        (box(-0.40, 0.40, 2.79, 2.83, 0.92, 1.52), 'grille'),
        (box(-0.04, 0.04, 2.70, 2.84, 1.58, 1.64), 'steel'),                   # Kuehlerdeckel
        (box(-0.90, 0.90, 0.25, 1.50, 0.80, 2.12), 'olive'),                   # Kabine
        (rbox_geo((0, 0.86, 2.15), (1.88, 1.38, 0.10), 0.04, 1), 'olive'),     # Dach
        (box(-0.78, -0.03, 1.50, 1.52, 1.62, 2.04), 'glass'),                  # Frontscheiben
        (box(0.03, 0.78, 1.50, 1.52, 1.62, 2.04), 'glass'),
        (box(-0.55, 0.55, 0.23, 0.25, 1.70, 1.98), 'glass'),                   # Heckscheibe
        (box(-0.88, 0.88, 1.40, 1.55, 0.86, 0.95), 'black'),                   # Spritzwand-Kante
    ]
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 0.90, sx * 0.92))
        parts += [
            (box(x0, x1, 0.80, 1.36, 1.56, 2.02), 'glass'),                    # Seitenfenster
            (box(x0, x1, 0.32, 1.40, 0.84, 0.88), 'black'),                    # Tuerunterkante
            (box(x0, x1, 0.74, 0.78, 0.88, 2.08), 'black'),                    # Tuerfuge
            (box(min(sx * 0.92, sx * 0.95), max(sx * 0.92, sx * 0.95), 0.86, 0.98, 1.36, 1.39), 'steel'),  # Griff
            (cyl_y(2.15, 2.32, sx * 0.80, 1.14, 0.11, 12), 'black'),          # Scheinwerfer
            (cyl_y(2.32, 2.34, sx * 0.80, 1.14, 0.095, 12), 'lamp'),
            (cyl_z(1.00, 1.05, sx * 0.80, 2.24, 0.03, 6), 'black'),
            (cyl((sx * 0.90, 1.45, 1.95), (sx * 1.08, 1.50, 2.02), 0.012, 4), 'darksteel'),  # Spiegel
            (box(min(sx * 1.06, sx * 1.12), max(sx * 1.06, sx * 1.12), 1.48, 1.51, 1.95, 2.10), 'darksteel'),
            (box(min(sx * 0.505, sx * 0.51), max(sx * 0.505, sx * 0.51), 1.62, 2.62, 1.05, 1.40), 'grille'),  # Lueftungsschlitze
        ]
    A.multi("cab", parts)
    A.marker("seat_driver", (-0.40, 0.92, 1.42))
    A.marker("seat_passenger", (0.40, 0.92, 1.42))
    A.marker("entry_driver", (-1.25, 1.0, 0.0))
    A.marker("entry_passenger", (1.25, 1.0, 0.0))


def build_fuel_truck():
    A = Asset("fuel_truck")
    build_cab(A)
    build_chassis(A)
    # Tank: elliptischer Querschnitt mit gewoelbten Enden
    rings = []
    y0, y1, rx, rz, zc = -2.62, 0.08, 0.78, 0.62, 1.47
    prof = [(y0 - 0.16, 0.45), (y0 - 0.10, 0.80), (y0 - 0.04, 0.96), (y0, 1.0), (y1, 1.0), (y1 + 0.04, 0.96), (y1 + 0.10, 0.80), (y1 + 0.16, 0.45)]
    for y, s in prof:
        rings.append(ring_pts(0, zc, rx * s, rz * s, y, 24))
    tank = loft(rings, closed=True, cap_start=True, cap_end=True)
    parts = [(tank, 'tankpaint')]
    for yb in (-2.15, -0.35):
        r2 = [ring_pts(0, zc, rx * 1.012, rz * 1.012, yb + d, 24) for d in (-0.035, 0.035)]
        parts.append((loft(r2, True, True, True), 'redband' if yb < -1 else 'black'))
        parts.append((box(-0.55, 0.55, yb - 0.08, yb + 0.08, 0.80, 1.0), 'black'))  # Sattel
    parts += [
        (cyl_z(2.05, 2.16, 0, -0.35, 0.24, 16), 'tankpaint'),                     # Domdeckel
        (cyl_z(2.16, 2.19, 0, -0.35, 0.20, 16), 'darksteel'),
        (cyl_z(2.05, 2.12, 0, -1.75, 0.10, 10), 'brass'),                          # Einfuellstutzen
        (box(-0.22, 0.22, -2.45, -0.75, 2.08, 2.12), 'wood'),                      # Laufsteg
    ]
    for sx in (-1, 1):
        parts.append((tube([(sx * 0.32, -2.5, 2.08), (sx * 0.32, -2.5, 2.35), (sx * 0.32, -0.7, 2.35), (sx * 0.32, -0.7, 2.08)], 0.018, 5), 'steel'))
    parts.append((tube([(0.6, -2.66, 0.9), (0.6, -2.66, 2.0), (0.6, -2.66, 2.0)], 0.02, 4), 'steel'))  # Leiter
    parts.append((tube([(0.85, -2.66, 0.9), (0.85, -2.66, 2.0)], 0.02, 4), 'steel'))
    for k in range(6):
        parts.append((cyl_x(0.6, 0.85, -2.66, 0.95 + k * 0.2, 0.012, 4), 'steel'))
    parts.append((cyl((0, -2.70, 1.0), (0, -2.95, 1.05), 0.04, 8), 'darksteel'))   # Ablassrohr zur Trommel
    # Schlauchtrommel-Gestell
    for sx in (-1, 1):
        parts.append((box(sx * 0.46 - 0.03, sx * 0.46 + 0.03, -3.30, -2.85, 0.78, 1.25), 'black'))
    parts.append((box(0.50, 0.70, -3.25, -2.95, 0.80, 0.98), 'darksteel'))      # Pumpe
    parts.append((cyl_x(0.70, 0.78, -3.10, 0.89, 0.06, 10), 'brass'))
    A.multi("tank", parts, smooth=True)
    zr, yr = 1.16, -3.08
    drum = A.multi("hose_reel_drum", [
        (cyl_x(-0.40, 0.40, 0, 0, 0.26, 20), 'hose'),
        (cyl_x(-0.44, -0.40, 0, 0, 0.33, 20), 'olive_plain'),
        (cyl_x(0.40, 0.44, 0, 0, 0.33, 20), 'olive_plain'),
        (cyl_x(-0.50, 0.50, 0, 0, 0.04, 8), 'darksteel'),
        (cyl_x(0.50, 0.56, 0, 0, 0.12, 8), 'darksteel'),                          # Kurbel
        (cyl((0.56, 0, 0.1), (0.62, 0.06, 0.1), 0.018, 5), 'black'),
    ], loc=(0, yr, zr), smooth=True)
    # Schlauchende mit Zapfpistole in Halterung
    A.multi("hose_end", [
        (tube([(-0.2, yr - 0.2, zr - 0.18), (-0.25, yr - 0.32, 0.95), (-0.35, yr - 0.32, 0.80), (-0.55, yr - 0.27, 0.80)], 0.03, 6), 'rubber'),
        (cyl((-0.55, yr - 0.27, 0.80), (-0.72, yr - 0.27, 0.80), 0.035, 8), 'brass'),
        (box(-0.78, -0.70, yr - 0.32, yr - 0.22, 0.70, 0.86), 'black'),
    ], smooth=True)
    A.marker("hose_reel", (0, yr, zr))
    A.marker("hose_nozzle", (-0.72, yr - 0.27, 0.80))
    # Erdungskabel mit Klemme (hinten links)
    A.multi("ground_strap", [
        (tube([(-0.62, -3.30, 0.58), (-0.64, -3.32, 0.30), (-0.66, -3.30, 0.04)], 0.012, 4), 'darksteel'),
        (box(-0.70, -0.62, -3.33, -3.27, 0.0, 0.05), 'brass'),
    ])
    A.marker("ground_clip", (-0.62, -3.30, 0.58))
    A.marker("fuel_fill", (0, -1.75, 2.12))
    return A, 1024


def build_ammo_cart():
    A = Asset("ammo_cart")
    build_cab(A)
    build_chassis(A, rear_end=-3.35)
    zf = 1.05  # Ladeflaeche
    parts = [
        (box(-1.05, 1.05, -3.30, 0.15, zf - 0.08, zf), 'wood'),
        (box(-1.05, 1.05, 0.10, 0.18, zf, zf + 0.85), 'wood_x'),                # Stirnwand
    ]
    for yb in (-3.0, -2.2, -1.4, -0.6):
        parts.append((box(-1.05, 1.05, yb - 0.04, yb + 0.04, 0.80, zf - 0.08), 'black'))  # Querholme
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 1.00, sx * 1.06))
        parts.append((box(x0, x1, -3.30, 0.15, zf, zf + 0.42), 'wood'))           # Bordwand
        for yp in (-3.25, -1.6, 0.12):
            parts.append((box(min(sx * 1.06, sx * 1.09), max(sx * 1.06, sx * 1.09), yp - 0.04, yp + 0.04, zf - 0.1, zf + 0.46), 'darksteel'))
        # Planenspriegel (Gestell, ohne Plane)
        parts.append((tube([(sx * 1.03, -0.3, zf + 0.42), (sx * 1.03, -0.3, zf + 1.25)], 0.02, 4), 'darksteel'))
    parts.append((tube([(-1.03, -0.3, zf + 1.25), (-0.6, -0.3, zf + 1.45), (0.6, -0.3, zf + 1.45), (1.03, -0.3, zf + 1.25)], 0.02, 4), 'darksteel'))
    parts.append((box(-0.85, -0.35, -0.35, 0.05, zf + 0.85, zf + 1.0), 'canvas'))  # zusammengelegte Plane
    # Munitions-Kennzeichnung: gelbe Raute (eigenes Design) auf der Stirnwand
    d = 0.16
    parts.append((([(-0.0, 0.185, zf + 0.6 + d), (d, 0.185, zf + 0.6), (0, 0.185, zf + 0.6 - d), (-d, 0.185, zf + 0.6),
                    (-0.0, 0.19, zf + 0.6 + d), (d, 0.19, zf + 0.6), (0, 0.19, zf + 0.6 - d), (-d, 0.19, zf + 0.6)],
                   [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]), 'yellow'))
    A.multi("bed", parts)
    # Heckklappe (eigener Knoten, Scharnier unten)
    A.multi("tailgate", [(box(-1.05, 1.05, -0.03, 0.03, 0.0, 0.42), 'wood_x'),
                         (box(-1.05, 1.05, -0.04, 0.04, 0.36, 0.42), 'darksteel')], loc=(0, -3.33, zf))
    i = 0
    for y in (-0.55, -1.40, -2.25):
        for x in (-0.45, 0.45):
            i += 1
            A.marker("crate_slot_%d" % i, (x, y, zf))
    A.marker("cargo_access", (0, -3.9, 0.0))
    return A, 1024


# ============================================================================
# Kleinteile
# ============================================================================
CRATE = (0.62, 0.36, 0.30)


def build_ammo_crate():
    A = Asset("ammo_crate")
    w, d, h = CRATE
    parts = [(box(-w / 2, w / 2, -d / 2, d / 2, 0, h - 0.03), 'crate'),
             (box(-w / 2 + 0.01, w / 2 - 0.01, -d / 2 + 0.01, d / 2 - 0.01, h - 0.03, h), 'crate'),   # Deckel
             (box(-w / 2 - 0.004, w / 2 + 0.004, -d / 2 - 0.004, d / 2 + 0.004, h * 0.62, h * 0.72), 'yellow')]  # Kennband
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append((box(*sorted((sx * (w / 2 - 0.04), sx * (w / 2 + 0.005))), *sorted((sy * (d / 2 - 0.04), sy * (d / 2 + 0.005))), 0, h + 0.003), 'darksteel'))
        # Griffe (Seilschlaufe + Leiste)
        parts.append((tube([(sx * (w / 2 + 0.005), -0.08, h * 0.55), (sx * (w / 2 + 0.04), -0.06, h * 0.48),
                            (sx * (w / 2 + 0.04), 0.06, h * 0.48), (sx * (w / 2 + 0.005), 0.08, h * 0.55)], 0.009, 5, True), 'canvas'))
        parts.append((box(*sorted((sx * w / 2, sx * (w / 2 + 0.012))), -0.12, 0.12, h * 0.56, h * 0.62), 'crate'))
    parts.append((box(-0.03, 0.03, d / 2, d / 2 + 0.012, h - 0.09, h - 0.02), 'darksteel'))  # Verschluss
    parts.append((box(-0.03, 0.03, -d / 2 - 0.012, -d / 2, h - 0.09, h - 0.02), 'darksteel'))
    A.multi("crate", parts)
    A.marker("carry", (0, 0, h * 0.5))
    A.marker("hand_L", (-(w / 2 + 0.04), 0, h * 0.5))
    A.marker("hand_R", (w / 2 + 0.04, 0, h * 0.5))
    return A, 512


def build_fuel_drum():
    A = Asset("fuel_drum")
    r, h = 0.29, 0.88
    prof = [(r - 0.02, 0.0), (r, 0.015), (r, 0.28), (r + 0.012, 0.29), (r + 0.012, 0.31), (r, 0.32),
            (r, 0.56), (r + 0.012, 0.57), (r + 0.012, 0.59), (r, 0.60), (r, h - 0.015), (r - 0.02, h)]
    rings = [ring_pts(0, 0, rr, rr, z, 24) for rr, z in prof]
    rings = [[(p[0], p[2], p[1]) for p in ring] for ring in rings]  # Ringe in XY-Ebene
    parts = [(loft(rings, True, True, True), 'drum'),
             (loft([[(p[0] * 1.03, p[1] * 1.03, 0.35) for p in rings[2]], [(p[0] * 1.03, p[1] * 1.03, 0.52) for p in rings[2]]], True, False, False), 'redband'),
             (cyl_z(h - 0.012, h + 0.01, 0.17, 0.0, 0.035, 8), 'brass'),
             (cyl_z(h - 0.012, h + 0.008, -0.17, 0.05, 0.022, 8), 'darksteel'),
             (cyl_z(h - 0.025, h - 0.005, 0, 0, r - 0.03, 24), 'drum')]
    A.multi("drum", parts, smooth=True)
    A.marker("carry", (0, 0, h * 0.5))
    return A, 512


def build_toolbox():
    A = Asset("toolbox")
    parts = [(box(-0.25, 0.25, -0.11, 0.11, 0.0, 0.17), 'red'),
             (rbox_geo((0, 0, 0.20), (0.51, 0.23, 0.07), 0.02, 1), 'red'),
             (tube([(-0.12, 0, 0.235), (-0.12, 0, 0.29), (0.12, 0, 0.29), (0.12, 0, 0.235)], 0.011, 5), 'darksteel'),
             (box(-0.045, 0.045, -0.118, -0.11, 0.13, 0.19), 'steel'),
             (box(-0.252, 0.252, -0.112, 0.112, 0.0, 0.02), 'darksteel')]
    A.multi("toolbox", parts)
    A.marker("carry", (0, 0, 0.29))
    return A, 256


def build_extinguisher():
    A = Asset("extinguisher")
    prof = [(0.0, 0.0), (0.085, 0.0), (0.09, 0.02), (0.09, 0.50), (0.07, 0.56), (0.035, 0.58), (0.0, 0.58)]
    rings = [[(p[0], p[2], p[1]) for p in ring_pts(0, 0, rr, rr, z, 16)] for rr, z in prof if rr > 0]
    parts = [(loft(rings, True, True, True), 'red'),
             (cyl_z(0.57, 0.64, 0, 0, 0.022, 8), 'brass'),
             (box(-0.02, 0.10, -0.015, 0.015, 0.63, 0.65), 'darksteel'),
             (tube([(0.02, 0, 0.61), (0.08, 0.02, 0.58), (0.10, 0.03, 0.40), (0.095, 0.02, 0.25)], 0.012, 5), 'rubber'),
             (cyl_z(0.21, 0.26, 0.095, 0.02, 0.016, 6, 0.01), 'darksteel'),
             (cyl_z(0.0, 0.03, 0, 0, 0.092, 16), 'black')]
    A.multi("extinguisher", parts, smooth=True)
    A.marker("carry", (0, 0, 0.62))
    return A, 256


def build_wheel_chocks():
    A = Asset("wheel_chocks")
    parts = []
    for sx in (-1, 1):
        x0 = sx * 0.45
        v = [(x0 - 0.10, -0.15, 0), (x0 + 0.10, -0.15, 0), (x0 + 0.10, 0.15, 0), (x0 - 0.10, 0.15, 0),
             (x0 - 0.10, -0.15, 0.16), (x0 + 0.10, -0.15, 0.16), (x0 + 0.10, -0.03, 0.16), (x0 - 0.10, -0.03, 0.16)]
        # Keil: Rueckseite senkrecht, Anlaufflaeche schraeg zur +Y-Seite (Rad)
        f = [(0, 3, 2, 1), (0, 1, 5, 4), (4, 5, 6, 7), (7, 6, 2, 3), (1, 2, 6, 5), (0, 4, 7, 3)]
        parts.append(((v, f), 'wood_x'))
        parts.append((box(x0 - 0.105, x0 + 0.105, -0.155, -0.10, 0.10, 0.14), 'yellow'))
    parts.append((tube([(-0.35, -0.13, 0.08), (-0.15, -0.20, 0.02), (0.15, -0.20, 0.02), (0.35, -0.13, 0.08)], 0.012, 5), 'canvas'))
    A.multi("chocks", parts)
    A.marker("carry", (0, -0.2, 0.05))
    return A, 256


def build_parking_mark():
    A = Asset("parking_mark")
    z0, z1 = 0.0, 0.012
    parts = []
    # Mittellinie (Einrollen von hinten = -Y), Haltebalken auf Hoehe der Hauptraeder, Eckwinkel
    parts.append((box(-0.08, 0.08, -7.0, 0.2, z0, z1), 'yellow'))
    parts.append((box(-1.6, 1.6, 0.20, 0.50, z0, z1), 'yellow'))
    for sx in (-1, 1):
        for sy, yy in ((-1, -7.5), (1, 4.0)):
            parts.append((box(*sorted((sx * 6.5, sx * 5.0)), *sorted((yy, yy - sy * 0.15)), z0, z1), 'yellow'))
            parts.append((box(*sorted((sx * 6.5, sx * 6.35)), *sorted((yy, yy - sy * 1.5)), z0, z1), 'yellow'))
    # Pfeilspitze am Einrollpunkt
    parts.append((([(-0.6, -7.6, z1), (0.6, -7.6, z1), (0.0, -6.8, z1), (-0.6, -7.6, z0), (0.6, -7.6, z0), (0.0, -6.8, z0)],
                   [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)]), 'yellow'))
    A.multi("mark", parts)
    A.marker("stand_point", (0, 0, 0))
    A.marker("main_wheel_stop", (0, 0.35, 0))
    return A, 512


# ============================================================================
# Gebaeude
# ============================================================================
def build_hangar():
    A = Asset("hangar")
    a, H, D, th = 12.0, 8.5, 18.0, 0.15
    N = 32
    ts = [math.pi * k / N for k in range(N + 1)]
    outer = [(a * math.cos(t), H * math.sin(t)) for t in ts]
    inner = [((a - th) * math.cos(t), (H - th) * math.sin(t)) for t in ts]
    yb, yf = -D / 2 - 0.3, D / 2 + 0.3
    V, F = [], []

    def vid(p):
        V.append(p)
        return len(V) - 1
    O0 = [vid((x, yb, z)) for x, z in outer]; O1 = [vid((x, yf, z)) for x, z in outer]
    I0 = [vid((x, yb, z)) for x, z in inner]; I1 = [vid((x, yf, z)) for x, z in inner]
    for k in range(N):
        F += [(O0[k], O0[k + 1], O1[k + 1], O1[k]), (I0[k], I1[k], I1[k + 1], I0[k + 1]),
              (O0[k], I0[k], I0[k + 1], O0[k + 1]), (O1[k], O1[k + 1], I1[k + 1], I1[k])]
    A.multi("roof", [((V, F), 'roof')])
    # Boegen (Stahlrippen aussen) + Fundament
    parts = []
    for yr in [-D / 2 + 0.2 + i * (D - 0.4) / 6 for i in range(7)]:
        pts = [((a + 0.06) * math.cos(t), yr, (H + 0.06) * math.sin(t)) for t in ts]
        parts.append((tube(pts, 0.08, 4, True), 'darksteel'))
    for sx in (-1, 1):
        parts.append((box(*sorted((sx * (a - 0.3), sx * (a + 0.35))), -D / 2 - 0.3, D / 2 + 0.3, 0, 0.35), 'concrete'))
    parts.append((box(-a, a, -D / 2, D / 2, 0, 0.06), 'concrete'))                        # Boden
    parts.append((box(-a + 1, a - 1, D / 2, D / 2 + 6.0, 0, 0.04), 'concrete'))            # Vorfeld
    A.multi("frame", parts)

    # Stirnwaende aus Brettern: Spalten zwischen Bodenlinie und Bogen
    def wall(y0, y1, opening, mat, name):
        xs = sorted(set([round(a * math.cos(t), 4) for t in ts] + ([-opening[0], opening[0]] if opening else [])))
        V, F = [], []

        def zt(x):
            return H * math.sqrt(max(0.0, 1 - (x / a) ** 2)) - 0.02

        def zl(x):
            return opening[1] if opening and abs(x) < opening[0] - 1e-6 else 0.0
        for i in range(len(xs) - 1):
            x0, x1 = xs[i], xs[i + 1]
            xm = (x0 + x1) / 2
            lo = zl(xm)
            t0, t1 = zt(x0), zt(x1)
            if max(t0, t1) <= lo:
                continue
            b = len(V)
            V += [(x0, y0, lo), (x1, y0, lo), (x1, y0, max(t1, lo)), (x0, y0, max(t0, lo)),
                  (x0, y1, lo), (x1, y1, lo), (x1, y1, max(t1, lo)), (x0, y1, max(t0, lo))]
            F += [(b, b + 1, b + 2, b + 3), (b + 5, b + 4, b + 7, b + 6), (b + 3, b + 2, b + 6, b + 7), (b, b + 4, b + 5, b + 1)]
            if i == 0 or (opening and abs(x0 + opening[0]) < 1e-6) or (opening and abs(x0 - opening[0]) < 1e-6):
                F.append((b, b + 3, b + 7, b + 4))
            if i == len(xs) - 2 or (opening and abs(x1 + opening[0]) < 1e-6) or (opening and abs(x1 - opening[0]) < 1e-6):
                F.append((b + 1, b + 5, b + 6, b + 2))
        A.multi(name, [((V, F), mat)])
    wall(D / 2 - 0.15, D / 2, (8.0, 5.6), 'wood_z', "front_wall")
    wall(-D / 2, -D / 2 + 0.15, None, 'wood_z', "back_wall")
    # Torschienen + Torfluegel (4, links zwei offen zur Seite geschoben)
    yd = D / 2 + 0.10
    A.multi("door_rail", [(box(-12.0, 12.0, yd - 0.06, yd + 0.10, 5.6, 5.8), 'darksteel'),
                          (box(-12.0, 12.0, yd - 0.06, yd + 0.10, 0.0, 0.05), 'darksteel')])
    leaf_x = [-10.1, -9.9 + 0.0, 2.05, 6.0]   # Mittelpunkte
    leaf_y = [0.18, 0.0, 0.0, 0.18]
    for i, (xc, dy) in enumerate(zip(leaf_x, leaf_y)):
        w2 = 2.0
        lp = [(box(-w2, w2, -0.05, 0.05, 0.05, 5.55), 'wood_z'),
              (box(-w2, w2, 0.05, 0.09, 0.05, 0.20), 'olive_plain'),
              (box(-w2, w2, 0.05, 0.09, 5.40, 5.55), 'olive_plain'),
              (box(-w2, w2, 0.05, 0.09, 2.70, 2.85), 'olive_plain'),
              (box(-w2, -w2 + 0.15, 0.05, 0.09, 0.05, 5.55), 'olive_plain'),
              (box(w2 - 0.15, w2, 0.05, 0.09, 0.05, 5.55), 'olive_plain')]
        # Diagonalstrebe
        ang = math.atan2(2.6, 2 * w2 - 0.3)
        L = math.hypot(2.6, 2 * w2 - 0.3)
        Bm = Matrix.Rotation(ang, 3, 'Y')
        lp.append((box_geo((0, 0.07, 1.42), (L, 0.04, 0.14), Bm), 'olive_plain'))
        lp.append((box_geo((0, 0.07, 4.12), (L, 0.04, 0.14), Bm), 'olive_plain'))
        lp.append((box(-0.3 + (1.2 if i % 2 else -1.2), -0.2 + (1.2 if i % 2 else -1.2), 0.09, 0.14, 1.3, 1.6), 'darksteel'))
        A.multi("door_leaf_%d" % (i + 1), lp, loc=(xc, yd + dy, 0))
    # Kleinkram: Lampe ueber dem Tor, Fenster seitlich in der Stirnwand
    A.multi("details", [(cyl((0, D / 2, 6.6), (0, D / 2 + 0.5, 6.4), 0.03, 5), 'darksteel'),
                        (cyl((0, D / 2 + 0.45, 6.45), (0, D / 2 + 0.45, 6.25), 0.18, 10, 0.05), 'olive_plain'),
                        (box(-10.6, -9.4, D / 2 + 0.005, D / 2 + 0.03, 1.6, 2.6), 'glass'),
                        (box(9.4, 10.6, D / 2 + 0.005, D / 2 + 0.03, 1.6, 2.6), 'glass')])
    A.marker("door", (0, D / 2 + 0.4, 1.0))
    A.marker("aircraft_spot", (0, 0, 0))
    return A, 1024


def build_fuel_depot():
    A = Asset("fuel_depot")
    parts = [(box(-6.0, 6.0, -4.0, 4.0, 0, 0.15), 'concrete')]
    # Stehtank
    tx, ty, R, Ht = -2.6, -0.6, 1.6, 3.6
    prof = [(R + 0.08, 0.15), (R + 0.08, 0.35), (R, 0.35), (R, Ht), (R + 0.05, Ht), (R + 0.05, Ht + 0.06), (0.25, Ht + 0.7), (0.0, Ht + 0.72)]
    rings = [[(tx + p[0], ty + p[2], p[1]) for p in ring_pts(0, 0, rr, rr, z, 28)] for rr, z in prof if rr > 0]
    parts.append((loft(rings, True, True, True), 'tankpaint'))
    parts.append((loft([[(tx + p[0], ty + p[2], 2.2) for p in ring_pts(0, 0, R * 1.008, R * 1.008, 0, 28)],
                        [(tx + p[0], ty + p[2], 2.5) for p in ring_pts(0, 0, R * 1.008, R * 1.008, 0, 28)]], True, False, False), 'redband'))
    # Leiter + Gelaender
    lx = tx + R + 0.12
    for dy in (-0.22, 0.22):
        parts.append((tube([(lx, ty + dy, 0.15), (lx, ty + dy, Ht + 0.9)], 0.025, 4), 'steel'))
    for k in range(17):
        parts.append((cyl((lx, ty - 0.22, 0.4 + k * 0.22), (lx, ty + 0.22, 0.4 + k * 0.22), 0.014, 4), 'steel'))
    rail = [(tx + (R - 0.05) * math.cos(t), ty + (R - 0.05) * math.sin(t), Ht + 0.9) for t in [math.radians(-50 + 10 * k) for k in range(11)]]
    parts.append((tube(rail, 0.02, 4), 'steel'))
    parts.append((cyl_z(Ht + 0.7, Ht + 1.0, tx, ty, 0.06, 8), 'darksteel'))      # Entlueftung
    # Rohrleitung zur Zapfsaeule
    px, py = 1.0, 1.6
    parts.append((tube([(tx + R * 0.7, ty + R * 0.7, 0.5), (tx + R * 0.7 + 0.3, ty + R * 0.7 + 0.3, 0.5),
                        (px - 0.3, py, 0.5), (px - 0.3, py, 0.3)], 0.05, 8), 'darksteel'))
    parts.append((cyl_z(0.35, 0.70, tx + R * 0.72 + 0.12, ty + R * 0.72 + 0.12, 0.09, 10), 'red'))  # Schieber
    parts.append((cyl((tx + R * 0.72, ty + R * 0.72 + 0.24, 0.78), (tx + R * 0.72 + 0.24, ty + R * 0.72, 0.78), 0.12, 12), 'red'))
    # Zapfsaeule (Handpumpe) mit Zapfhahn
    parts += [(box(px - 0.30, px + 0.30, py - 0.22, py + 0.22, 0.15, 1.30), 'olive'),
              (rbox_geo((px, py, 1.34), (0.66, 0.50, 0.10), 0.03, 1), 'olive'),
              (cyl((px + 0.30, py, 1.05), (px + 0.45, py, 1.05), 0.03, 8), 'darksteel'),
              (cyl((px + 0.45, py, 1.05), (px + 0.45, py, 0.55), 0.02, 6), 'black'),            # Hebel
              (cyl((px, py + 0.22, 0.95), (px, py + 0.42, 0.95), 0.035, 8), 'brass'),           # Auslauf
              (cyl((px, py + 0.42, 0.95), (px, py + 0.47, 0.85), 0.03, 8), 'brass'),
              (tube([(px - 0.2, py + 0.22, 0.6), (px - 0.35, py + 0.45, 0.3), (px - 0.5, py + 0.4, 0.2), (px - 0.6, py + 0.25, 0.6)], 0.028, 6), 'rubber'),
              (box(px - 0.25, px - 0.15, py + 0.22, py + 0.26, 1.0, 1.2), 'yellow')]
    A.multi("depot", parts, smooth=True)
    A.marker("fuel_tap", (px, py + 0.47, 0.85))
    A.marker("fuel_tap_truck", (px + 1.8, py + 1.2, 0.0))
    # Fassstapel: 2x4 stehend, 3 liegend oben
    r, h = 0.29, 0.88
    drum_rings = [[(p[0], p[2], p[1]) for p in ring_pts(0, 0, rr, rr, z, 14)] for rr, z in
                  [(r - 0.02, 0.0), (r, 0.02), (r, 0.30), (r + 0.012, 0.31), (r, 0.33), (r, 0.56), (r + 0.012, 0.57), (r, 0.59), (r, h - 0.02), (r - 0.02, h)]]
    dv, df = loft(drum_rings, True, True, True)
    dp = []
    import random
    rnd = random.Random(7)
    for i in range(4):
        for j in range(2):
            o = Vector((2.4 + i * 0.62, -2.6 + j * 0.62, 0.15))
            Rz = Matrix.Rotation(rnd.uniform(0, 6.28), 3, 'Z')
            dp.append((([tuple(o + Rz @ Vector(p)) for p in dv], df), 'drum'))
    for i in range(3):
        o = Vector((2.4 + 0.31 + i * 0.62, -2.6 - 0.44 + 0.0, 0.15 + h + r))
        Rx = Matrix.Rotation(math.radians(-90), 3, 'X')
        dp.append((([tuple(o + Rx @ Vector(p)) for p in dv], df), 'drum'))
    # Holzbohlen unter den Faessern
    dp.append((box(2.0, 4.6, -3.0, -1.7, 0.15, 0.15 + 0.001), 'wood'))
    A.multi("drum_stack", dp, smooth=True)
    # Sandsack-Mauer hinten (Splitterschutz)
    sb = []
    for row in range(3):
        for k in range(14):
            x = -5.6 + k * 0.82 + (0.41 if row % 2 else 0)
            if x > 5.6:
                continue
            sb.append((rbox_geo((x, -3.7, 0.15 + 0.11 + row * 0.2), (0.78, 0.40, 0.22), 0.08, 1), 'canvas'))
    A.multi("sandbags", sb, smooth=True)
    return A, 1024


def build_ammo_bunker():
    A = Asset("ammo_bunker")
    a, b_, H, cy, wy = 6.5, 5.5, 3.7, -1.0, 2.5
    nx, ny = 30, 22

    def hgt(x, y):
        q = 1 - (x / a) ** 2 - ((y - cy) / b_) ** 2
        return H * max(0.0, q) ** 0.55 - 0.08  # Rand leicht im Boden
    V, F = [], []
    ys = [cy - b_ + (wy - (cy - b_)) * j / ny for j in range(ny + 1)]
    xs = [-a + 2 * a * i / nx for i in range(nx + 1)]
    for y in ys:
        for x in xs:
            V.append((x, y, hgt(x, y)))
    for j in range(ny):
        for i in range(nx):
            k = j * (nx + 1) + i
            if max(V[k][2], V[k + 1][2], V[k + nx + 2][2], V[k + nx + 1][2]) > 0.0:
                F.append((k, k + 1, k + nx + 2, k + nx + 1))
    A.multi("mound", [((V, F), 'earth')], smooth=True)
    # Stirnmauer (Beton) mit Oberkante entlang des Erdprofils
    th = 0.4
    xw = [x for x in xs if hgt(x, wy) > 0.0]
    xw = [xw[0] - 2 * a / nx] + xw + [xw[-1] + 2 * a / nx]
    V, F = [], []
    for i in range(len(xw) - 1):
        x0, x1 = xw[i], xw[i + 1]
        t0, t1 = max(hgt(x0, wy) + 0.33, 0.5), max(hgt(x1, wy) + 0.33, 0.5)
        bb = len(V)
        V += [(x0, wy, 0), (x1, wy, 0), (x1, wy, t1), (x0, wy, t0), (x0, wy + th, 0), (x1, wy + th, 0), (x1, wy + th, t1), (x0, wy + th, t0)]
        F += [(bb, bb + 1, bb + 2, bb + 3), (bb + 5, bb + 4, bb + 7, bb + 6), (bb + 3, bb + 2, bb + 6, bb + 7)]
        if i == 0:
            F.append((bb, bb + 3, bb + 7, bb + 4))
        if i == len(xw) - 2:
            F.append((bb + 1, bb + 5, bb + 6, bb + 2))
    parts = [((V, F), 'concrete')]
    # Fluegelmauern schraeg nach vorn
    for sx in (-1, 1):
        x0 = sx * (xw[-1] if sx > 0 else -xw[0])
        bm = Matrix.Rotation(sx * math.radians(-25), 3, 'Z')
        parts.append((box_geo((x0 + sx * 0.9 * math.sin(math.radians(25)) * 0, wy + th + 0.9, 0.35), (0.3, 1.8, 0.7), bm), 'concrete'))
    # Tuerrahmen, Doppeltuer, Vordach, Schild, Lueftung
    yd = wy + th
    parts += [(box(-1.25, 1.25, yd, yd + 0.08, 0.0, 2.55), 'concrete'),
              (box(-1.6, 1.6, yd, yd + 0.9, 2.55, 2.70), 'concrete'),
              (box(-0.5, 0.5, yd + 0.08, yd + 0.10, 2.15, 2.45), 'yellow'),
              (cyl_z(hgt(0, -1.0) - 0.3, hgt(0, -1.0) + 0.9, 0.0, -1.0, 0.12, 10), 'darksteel'),
              (cyl_z(hgt(0, -1.0) + 0.9, hgt(0, -1.0) + 1.05, 0.0, -1.0, 0.22, 10, 0.05), 'darksteel'),
              (box(-1.6, 1.6, yd + 0.08, yd + 1.6, 0.0, 0.08), 'concrete')]
    A.multi("headwall", parts)
    for sx in (-1, 1):
        o = -sx * 1.0  # Scharnier aussen: Knoten am Scharnier, Fluegel reicht bis zur Mitte
        lp = [(box(*sorted((o, 0)), 0.0, 0.06, 0.05, 2.1), 'olive_plain'),
              (box(*sorted((o + sx * 0.08, -sx * 0.08)), 0.06, 0.08, 0.15, 0.25), 'darksteel'),
              (box(*sorted((o + sx * 0.08, -sx * 0.08)), 0.06, 0.08, 1.85, 1.95), 'darksteel'),
              (box(*sorted((-sx * 0.12, -sx * 0.16)), 0.06, 0.14, 0.95, 1.25), 'steel'),
              (cyl_z(0.3, 0.55, 0, 0.03, 0.04, 6), 'darksteel'),
              (cyl_z(1.6, 1.85, 0, 0.03, 0.04, 6), 'darksteel')]
        A.multi("ammo_door_%s" % ("L" if sx < 0 else "R"), lp, loc=(sx * 1.0, yd + 0.08, 0.0))
    A.marker("ammo_door", (0, yd + 0.25, 1.0))
    A.marker("ammo_door_truck", (0, yd + 5.0, 0.0))
    return A, 1024


BUILDERS = dict(fuel_truck=build_fuel_truck, ammo_cart=build_ammo_cart, ammo_crate=build_ammo_crate,
                fuel_drum=build_fuel_drum, hangar=build_hangar, fuel_depot=build_fuel_depot,
                ammo_bunker=build_ammo_bunker, toolbox=build_toolbox, extinguisher=build_extinguisher,
                wheel_chocks=build_wheel_chocks, parking_mark=build_parking_mark)
AO_DIST = dict(hangar=3.0, fuel_depot=1.5, ammo_bunker=2.0, parking_mark=0.1)


# ============================================================================
# Bake + Export
# ============================================================================
def finish(A, size):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("BakeWorld")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    world.light_settings.distance = AO_DIST.get(A.name, 0.5)
    size = 256 if OPT["quick"] else size
    objs = A.objs
    # Erstes Objekt ohne Transform zuerst (Objektkoordinaten der Bake-Kopie = Modellraum)
    objs.sort(key=lambda o: 0 if o.location.length < 1e-6 else 1)
    uv_unwrap(objs, 0.004 if size >= 1024 else 0.008)
    t0 = time.time()
    res = bake_group(objs, A.M, size, ['albedo', 'rough', 'metal', 'normal', 'ao'], A.name)
    pa = {k: os.path.join(TEX, "%s_%s.png" % (A.name, k)) for k in ('albedo', 'normal', 'orm')}
    save_image(res['albedo'], pa['albedo'])
    save_image(res['normal'], pa['normal'])
    pack_orm(res['ao'], res['rough'], res['metal'], pa['orm'])
    print("  Bake %s: %.1fs" % (A.name, time.time() - t0))
    mat = pbr_material("M_" + A.name, pa['albedo'], pa['normal'], pa['orm'])
    tris = {}
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(mat)
        tris[o.name] = tri_count(o)
    # Export
    bpy.ops.object.select_all(action='DESELECT')
    A.root.select_set(True)
    for o in A.root.children_recursive:
        o.select_set(True)
    out = os.path.join(MODELS, A.name + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_apply=True, export_yup=True,
                              export_extras=True, export_cameras=False, export_lights=False, export_tangents=True,
                              export_animations=False)
    shutil.copy(out, os.path.join(GAME, A.name + ".glb"))
    mb = os.path.getsize(out) / 1e6
    total = sum(tris.values())
    print("GLB %s: %.2f MB, %d Dreiecke" % (out, mb, total))
    return dict(file="ground/" + A.name + ".glb", triangles=total, per_node=tris, texture_size=size,
                size_mb=round(mb, 2), markers=A.markers)


def main_build():
    info_path = os.path.join(MODELS, "ground_props.json")
    info = {}
    if os.path.exists(info_path):
        with open(info_path) as fh:
            info = json.load(fh).get("assets", {})
    names = OPT["only"] or list(BUILDERS)
    for nm in names:
        t0 = time.time()
        reset_scene()
        scene = bpy.context.scene
        scene.render.engine = 'CYCLES'
        scene.cycles.device = 'CPU'
        scene.render.bake.margin_type = 'EXTEND'
        A, size = BUILDERS[nm]()
        info[nm] = finish(A, size)
        print("== %s fertig in %.1fs" % (nm, time.time() - t0))
    data = dict(convention=dict(up="+Y", forward="-Z (Fahrzeugfront, Gebaeudeoeffnung)", right="+X", units="m",
                                origin="Boden y=0; Fahrzeuge Mitte zwischen den Achsen; sonst Mitte der Grundflaeche"),
                vehicle=dict(wheelbase=AX_F - AX_R, track=2 * TRACK, wheel_radius=WR,
                             nodes="wheel_FL/FR/RL/RR (Drehpunkt = Nabe, rollen um lokale X), hose_reel_drum (um X), tailgate (Scharnier unten, um X)"),
                assets=info)
    with open(info_path, "w") as fh:
        json.dump(data, fh, indent=1, ensure_ascii=False)


# ============================================================================
# Kontroll-Renders (aus den exportierten GLBs)
# ============================================================================
def render_previews():
    reset_scene()
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 24
    try:
        scene.cycles.use_denoising = True
    except Exception:
        pass
    scene.render.resolution_x, scene.render.resolution_y = 640, 360
    scene.view_settings.view_transform = 'AgX' if 'AgX' in [i.identifier for i in scene.view_settings.bl_rna.properties['view_transform'].enum_items] else 'Filmic'
    try:
        scene.view_settings.look = 'AgX - Medium High Contrast'
    except Exception:
        pass
    w = bpy.data.worlds.new("W")
    scene.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.55, 0.70, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
    sun.data.energy = 4.0
    sun.data.angle = math.radians(2)
    sun.rotation_euler = (math.radians(48), 0, math.radians(-40))
    scene.collection.objects.link(sun)
    gm = ground_mat('preview_ground', grass=(0.13, 0.16, 0.07), earth=(0.20, 0.17, 0.12), mix=0.7)
    bpy.ops.mesh.primitive_plane_add(size=400)
    g = bpy.context.active_object
    g.data.materials.append(gm)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam

    def imp(name, loc, rot_deg=0.0):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, name + ".glb"))
        new = [o for o in bpy.data.objects if o not in before]
        roots = [o for o in new if o.parent is None]
        grp = []
        for r in roots:
            r.rotation_mode = 'XYZ'
            r.location = loc
            r.rotation_euler = (0, 0, math.radians(rot_deg))
            grp.append(r)
        return new

    def look(pos, tgt, lens):
        cam.location = pos
        cam.data.lens = lens
        d = Vector(tgt) - Vector(pos)
        cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()

    def shot(fname, items, pos, tgt, lens):
        made = []
        for it in items:
            made += imp(*it)
        look(pos, tgt, lens)
        scene.render.filepath = os.path.join(PREV, fname)
        t0 = time.time()
        bpy.ops.render.render(write_still=True)
        print("render", fname, "%.1fs" % (time.time() - t0))
        for o in made:
            bpy.data.objects.remove(o, do_unlink=True)

    crates = [("ammo_crate", (x, y, 1.05), 0) for y in (-0.55, -1.40, -2.25) for x in (-0.45, 0.45)][:4]
    # Fahrzeuge (Ammo-Lkw um 180 gedreht neben dem Tankwagen, Kisten auf Slots 1-4)
    shot("ground_vehicles.png",
         [("fuel_truck", (0, 0, 0), 0), ("ammo_cart", (3.4, 0, 0), 180)] +
         [("ammo_crate", (3.4 - c[1][0], -c[1][1], c[1][2]), 180) for c in crates] +
         [("fuel_drum", (-1.9, -2.6, 0), 0), ("fuel_drum", (-2.4, -3.1, 0), 0), ("ammo_crate", (-1.6, -3.6, 0), 30),
          ("extinguisher", (-1.4, 1.2, 0), 0), ("wheel_chocks", (1.6, 3.6, 0), 0), ("toolbox", (1.4, 4.4, 0), 60)],
         (-8.5, 7.5, 3.6), (1.4, 0, 0.9), 30)
    shot("ground_vehicles_rear.png",
         [("fuel_truck", (0, 0, 0), 0), ("ammo_cart", (3.4, 0.0, 0), 0)] + [("ammo_crate", (3.4 + c[1][0], c[1][1], c[1][2]), 0) for c in crates],
         (7.0, -9.0, 4.2), (1.6, -1.0, 1.0), 32)
    shot("ground_buildings.png",
         [("hangar", (0, 0, 0), 0), ("fuel_depot", (22, 8, 0), -30), ("ammo_bunker", (-20, 10, 0), 25),
          ("parking_mark", (0, 22, 0), 180), ("fuel_truck", (10, 18, 0), 120)],
         (8, 52, 14), (0, 6, 3), 26)
    shot("ground_depot_bunker.png",
         [("fuel_depot", (0, 0, 0), 0), ("ammo_bunker", (15, -1, 0), 0), ("ammo_crate", (15.6, 4.6, 0), 10), ("ammo_crate", (15.0, 4.9, 0), -8)],
         (6, 15, 6), (6.5, 0, 1.4), 26)
    shot("ground_props.png",
         [("ammo_crate", (0, 0, 0), 20), ("fuel_drum", (0.9, 0.2, 0), 0), ("toolbox", (-0.8, 0.3, 0), -20),
          ("extinguisher", (-0.3, 0.9, 0), 0), ("wheel_chocks", (0.5, -0.9, 0), 160)],
         (1.6, 3.4, 1.6), (0.1, 0, 0.3), 35)


if OPT["build"]:
    main_build()
if OPT["render"]:
    render_previews()
