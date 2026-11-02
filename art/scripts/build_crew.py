# -*- coding: utf-8 -*-
"""
Figur "Mechaniker" fuer M3 (Stil B): low-poly, Overall, Muetze, Abnutzung; humanoides Skelett mit
den Knochennamen von Godot SkeletonProfileHumanoid; eigene prozedurale Animationen (kein Fremdmaterial).

Aufruf:  blender -b -P build_crew.py -- --build [--quick]     # Modell, Skin, Bake, Animationen, Export
         blender -b -P build_crew.py -- --render              # Kontroll-Renders einiger Posen

Ergebnis: art/models/crew/crew_mechanic.glb (+ Kopie game/assets/ground/), art/textures/crew/*,
          art/models/crew/crew_mechanic.json, art/previews/ground_crew_*.png

Konvention: Blender Z oben, Blick +Y, rechts +X  ->  glTF/Godot: Y oben, Blick -Z (wie CrewCharacter),
Ursprung zwischen den Fuessen am Boden. Ruhepose T-Pose. Animationen (30 fps, Namen = CrewCharacter.ANIM_NAMES
plus "lift"): idle, walk, run, carry, hose, lift, work, enter. Schleifen: alle ausser lift/enter.
Marker: hand_R, hand_L (an den Handknochen), carry (vor dem Koerper, wie CrewCharacter.carry_point).
"""
import bpy, bmesh, math, sys, os, json, time, shutil
from mathutils import Vector, Matrix, Quaternion, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
_argv_saved = sys.argv
sys.argv = [a for a in sys.argv if a not in ("--build", "--quick", "--render")]
import build_game_aircraft as BGA  # noqa: E402
sys.argv = _argv_saved
import build_airfield_props as BAP  # noqa: E402  (Materialien)
from build_game_aircraft import (NB, new_mat, col, loft, uv_unwrap, bake_group, pack_orm, save_image,  # noqa
                                 pbr_material, select_only, reset_scene, tri_count)

ART = BAP.ART
MODELS = os.path.join(ART, "models", "crew")
TEX = os.path.join(ART, "textures", "crew")
PREV = BAP.PREV
GAME = BAP.GAME
for d in (MODELS, TEX):
    os.makedirs(d, exist_ok=True)
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OPT = {"build": "--build" in argv, "render": "--render" in argv, "quick": "--quick" in argv}
BGA.SAMPLES = dict(color=1, normal=2, ao=4 if OPT["quick"] else 16)
FPS = 30

# ============================================================================
# Skelett (T-Pose, Blick +Y). Namen = Godot SkeletonProfileHumanoid
# ============================================================================
SH_Z, HIP_Z = 1.44, 0.93
BONES = [  # name, parent, head, tail
    ("Root", None, (0, 0, 0), (0, 0.15, 0)),
    ("Hips", "Root", (0, 0, 0.96), (0, 0, 1.06)),
    ("Spine", "Hips", (0, 0, 1.06), (0, 0, 1.18)),
    ("Chest", "Spine", (0, 0, 1.18), (0, 0, 1.30)),
    ("UpperChest", "Chest", (0, 0, 1.30), (0, 0, 1.45)),
    ("Neck", "UpperChest", (0, 0, 1.45), (0, 0.01, 1.56)),
    ("Head", "Neck", (0, 0.01, 1.56), (0, 0.01, 1.78)),
]
for S, sx in (("Left", -1), ("Right", 1)):
    BONES += [
        (S + "Shoulder", "UpperChest", (sx * 0.03, 0, 1.42), (sx * 0.17, 0, SH_Z)),
        (S + "UpperArm", S + "Shoulder", (sx * 0.17, 0, SH_Z), (sx * 0.45, 0, SH_Z)),
        (S + "LowerArm", S + "UpperArm", (sx * 0.45, 0, SH_Z), (sx * 0.71, 0, SH_Z)),
        (S + "Hand", S + "LowerArm", (sx * 0.71, 0, SH_Z), (sx * 0.81, 0, SH_Z)),
        (S + "UpperLeg", "Hips", (sx * 0.095, 0, HIP_Z), (sx * 0.095, 0.01, 0.50)),
        (S + "LowerLeg", S + "UpperLeg", (sx * 0.095, 0.01, 0.50), (sx * 0.095, -0.01, 0.09)),
        (S + "Foot", S + "LowerLeg", (sx * 0.095, -0.01, 0.09), (sx * 0.095, 0.12, 0.025)),
        (S + "Toes", S + "Foot", (sx * 0.095, 0.12, 0.025), (sx * 0.095, 0.20, 0.025)),
    ]
BH = {b[0]: (Vector(b[2]), Vector(b[3])) for b in BONES}


def build_armature():
    arm = bpy.data.armatures.new("crew_rig")
    ob = bpy.data.objects.new("crew_mechanic", arm)
    col().objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT')
    for nm, par, h, t in BONES:
        eb = arm.edit_bones.new(nm)
        eb.head, eb.tail = h, t
        if par:
            eb.parent = arm.edit_bones[par]
            eb.use_connect = (Vector(arm.edit_bones[par].tail) - Vector(h)).length < 1e-4 and nm != "Hips"
        # Rolle: lokale X-Achse moeglichst Welt-X (Beine/Wirbelsaeule) bzw. Welt-Z (Arme)
        eb.align_roll(Vector((0, 0, 1)) if ("Arm" in nm or "Hand" in nm or "Shoulder" in nm) else Vector((0, 1, 0)) if nm != "Root" else Vector((0, 0, 1)))
    bpy.ops.object.mode_set(mode='OBJECT')
    return ob


# ============================================================================
# Mesh (Teile mit erlaubten Knochen fuer die Gewichtung)
# ============================================================================
def ring_xy(cx, cy, z, rx, ry, n, ry_back=None):
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        yy = math.sin(a) * (ry if math.sin(a) >= 0 or ry_back is None else ry_back)
        pts.append((cx + rx * math.cos(a), cy + yy, z))
    return pts


def limb(p0, p1, radii, n=10, flat=1.0, axis_up=Vector((0, 0, 1))):
    """Rohr von p0 nach p1, radii = [(t, r), ...] entlang der Strecke."""
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0)
    L = d.length
    T = d.normalized()
    ref = axis_up if abs(T.dot(axis_up)) < 0.9 else Vector((0, 1, 0))
    N = T.cross(ref).normalized()
    B = T.cross(N)
    rings = []
    for t, r in radii:
        c = p0 + T * (L * t)
        rings.append([tuple(c + r * (math.cos(2 * math.pi * k / n) * N + flat * math.sin(2 * math.pi * k / n) * B)) for k in range(n)])
    return loft(rings, closed=True, cap_start=True, cap_end=True)


def ellip(c, r, nu=12, nv=8):
    V, F = [], []
    for j in range(1, nv):
        th = math.pi * j / nv
        for i in range(nu):
            ph = 2 * math.pi * i / nu
            V.append((c[0] + r[0] * math.sin(th) * math.cos(ph), c[1] + r[1] * math.sin(th) * math.sin(ph), c[2] + r[2] * math.cos(th)))
    top = len(V); V.append((c[0], c[1], c[2] + r[2]))
    bot = len(V); V.append((c[0], c[1], c[2] - r[2]))
    for j in range(nv - 2):
        for i in range(nu):
            a, b = j * nu + i, j * nu + (i + 1) % nu
            F.append((a, b, b + nu, a + nu))
    for i in range(nu):
        F.append((top, (i + 1) % nu, i))
        a = (nv - 2) * nu
        F.append((bot, a + i, a + (i + 1) % nu))
    return V, F


def boxg(c, s):
    return BAP.box_geo(c, s)


def build_body_parts():
    P = []  # (geo, matkey, bones)
    torso_b = ["Hips", "Spine", "Chest", "UpperChest", "Neck", "LeftShoulder", "RightShoulder", "LeftUpperLeg", "RightUpperLeg"]
    # Rumpf: Ringe (z, Halbbreite, Tiefe vorn, Tiefe hinten)
    prof = [(0.80, 0.11, 0.07, 0.08), (0.88, 0.165, 0.10, 0.11), (0.96, 0.175, 0.105, 0.12), (1.04, 0.165, 0.10, 0.11),
            (1.12, 0.160, 0.105, 0.105), (1.22, 0.170, 0.115, 0.105), (1.32, 0.185, 0.12, 0.11), (1.40, 0.19, 0.11, 0.10),
            (1.46, 0.16, 0.085, 0.085), (1.50, 0.09, 0.06, 0.06), (1.53, 0.055, 0.05, 0.05)]
    rings = [ring_xy(0, 0, z, rx, fy, 16, by) for z, rx, fy, by in prof]
    P.append((loft(rings, True, True, True), 'overall', torso_b))
    P.append((loft([ring_xy(0, 0, z, 0.172 * 1.03, 0.11, 16, 0.122) for z in (0.97, 1.02)], True, False, False), 'belt', ["Hips", "Spine"]))
    P.append((boxg((0.0, 0.112, 0.995), (0.06, 0.012, 0.045)), 'brass', ["Hips"]))
    for sx in (-1, 1):
        P.append((boxg((sx * 0.085, 0.112, 1.31), (0.10, 0.025, 0.11)), 'overall', ["Chest", "UpperChest"]))   # Brusttasche
        P.append((boxg((sx * 0.085, 0.124, 1.355), (0.105, 0.012, 0.03)), 'overall', ["UpperChest"]))
    # Kragen
    P.append((loft([ring_xy(0, 0, 1.47, 0.11, 0.09, 12), ring_xy(0, -0.01, 1.53, 0.095, 0.08, 12)], True, False, False), 'overall', ["UpperChest", "Neck"]))
    # Hals + Kopf
    P.append((BAP.cyl((0, 0.0, 1.46), (0, 0.01, 1.60), 0.052, 10), 'skin', ["Neck", "Head", "UpperChest"]))
    P.append((ellip((0, 0.015, 1.665), (0.083, 0.098, 0.11), 14, 9), 'skin', ["Head"]))
    P.append((([(0, 0.13, 1.66), (-0.016, 0.105, 1.635), (0.016, 0.105, 1.635), (0, 0.105, 1.69), (0, 0.098, 1.64)],
               [(0, 1, 2), (0, 3, 1), (0, 2, 3), (1, 4, 2), (1, 3, 4), (2, 4, 3)]), 'skin', ["Head"]))       # Nase
    for sx in (-1, 1):
        P.append((ellip((sx * 0.083, 0.01, 1.66), (0.012, 0.022, 0.03), 6, 4), 'skin', ["Head"]))          # Ohr
        P.append((ellip((sx * 0.032, 0.093, 1.685), (0.013, 0.006, 0.008), 6, 4), 'eye', ["Head"]))        # Auge
        P.append((boxg((sx * 0.033, 0.095, 1.705), (0.035, 0.008, 0.008)), 'hair', ["Head"]))             # Braue
    # Muetze: Krone, Band, Schirm
    P.append((loft([ring_xy(0, 0.0, 1.70, 0.092, 0.105, 16), ring_xy(0, 0.0, 1.765, 0.097, 0.11, 16),
                    ring_xy(0, -0.005, 1.795, 0.085, 0.10, 16)], True, False, True), 'cap', ["Head"]))
    P.append((loft([ring_xy(0, 0.0, 1.69, 0.094, 0.107, 16), ring_xy(0, 0.0, 1.715, 0.095, 0.108, 16)], True, False, False), 'capband', ["Head"]))
    vis = []
    for k in range(9):
        a = math.radians(-70 + 140 * k / 8)
        vis.append((0.10 * math.sin(a), 0.10 * math.cos(a) + 0.0, 1.705))
    outer = [(x * 1.0 + 0.0, y + 0.055 * math.cos(math.asin(max(-1, min(1, x / 0.1)))), z - 0.012) for x, y, z in vis]
    V = vis + outer + [(x, y, z - 0.008) for x, y, z in vis] + [(x, y, z - 0.008) for x, y, z in outer]
    F = []
    n = len(vis)
    for k in range(n - 1):
        F.append((k, k + 1, n + k + 1, n + k))
        F.append((2 * n + k, 3 * n + k, 3 * n + k + 1, 2 * n + k + 1))
        F.append((n + k, n + k + 1, 3 * n + k + 1, 3 * n + k))
    P.append(((V, F), 'visor', ["Head"]))
    P.append((boxg((0, -0.07, 1.67), (0.12, 0.03, 0.05)), 'hair', ["Head"]))                               # Nacken-Haar
    for S, sx in (("Left", -1), ("Right", 1)):
        arm_b = [S + "Shoulder", S + "UpperArm", S + "LowerArm", S + "Hand", "UpperChest"]
        # Arm (Aermel bis Handgelenk, Manschette)
        P.append((limb((sx * 0.12, 0, SH_Z - 0.01), (sx * 0.705, 0, SH_Z),
                       [(0, 0.075), (0.12, 0.068), (0.45, 0.055), (0.52, 0.052), (0.75, 0.046), (0.94, 0.042), (1.0, 0.040)], 10, 0.95,
                       Vector((0, 1, 0))), 'overall', arm_b))
        P.append((limb((sx * 0.66, 0, SH_Z), (sx * 0.705, 0, SH_Z), [(0, 0.046), (1, 0.046)], 10, 1.0, Vector((0, 1, 0))), 'overall', arm_b))
        # Hand: Handflaeche + Daumen (Faust leicht geoeffnet)
        P.append((limb((sx * 0.70, 0, SH_Z - 0.005), (sx * 0.835, 0, SH_Z - 0.012), [(0, 0.030), (0.3, 0.038), (0.8, 0.034), (1.0, 0.02)], 8, 0.55,
                       Vector((0, 0, 1))), 'skin', [S + "Hand", S + "LowerArm"]))
        P.append((limb((sx * 0.72, 0.03, SH_Z - 0.01), (sx * 0.775, 0.06, SH_Z - 0.02), [(0, 0.014), (1, 0.010)], 6), 'skin', [S + "Hand"]))
        # Bein (Hosenbein) + Stiefel
        leg_b = [S + "UpperLeg", S + "LowerLeg", "Hips", S + "Foot"]
        P.append((limb((sx * 0.095, 0, 0.98), (sx * 0.095, -0.005, 0.13),
                       [(0, 0.095), (0.10, 0.092), (0.35, 0.078), (0.52, 0.060), (0.58, 0.058), (0.80, 0.054), (0.95, 0.056), (1.0, 0.058)], 12, 1.0,
                       Vector((0, 1, 0))), 'overall', leg_b))
        P.append((boxg((sx * 0.17, 0.0, 0.72), (0.02, 0.12, 0.13)), 'overall', [S + "UpperLeg"]))          # Beintasche
        bp = [(-0.06, 0.0), (-0.04, 0.035), (0.04, 0.05), (0.13, 0.055), (0.19, 0.045), (0.215, 0.025)]
        rings = []
        for y, r in bp:
            hz = 0.075 if y < 0.06 else 0.075 - (y - 0.06) * 0.25
            rings.append([(sx * 0.095 + r * math.cos(2 * math.pi * k / 10), y, 0.0 + hz * (0.5 + 0.5 * math.sin(2 * math.pi * k / 10)) + (0.0)) for k in range(10)])
        P.append((loft(rings, True, True, True), 'boot', [S + "Foot", S + "Toes", S + "LowerLeg"]))
        P.append((limb((sx * 0.095, -0.01, 0.02), (sx * 0.095, -0.01, 0.17), [(0, 0.052), (1, 0.055)], 10), 'boot', [S + "LowerLeg", S + "Foot"]))
        P.append((boxg((sx * 0.095, 0.07, 0.006), (0.10, 0.30, 0.014)), 'sole', [S + "Foot", S + "Toes"]))
    return P


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def mechanic_mats():
    M = BAP.Mats()
    worn = lambda k, base, **kw: BAP.paint(k, base, chip=tuple(c * 0.6 for c in base), metal_chip=0.0, **kw)
    extra = {
        'overall': lambda: fabric('overall', (0.085, 0.10, 0.12)),
        'cap': lambda: fabric('cap', (0.07, 0.08, 0.09), dirt=0.2),
        'capband': lambda: BAP.simple('capband', (0.02, 0.02, 0.02), 0.5),
        'visor': lambda: BAP.simple('visor', (0.02, 0.02, 0.02), 0.25),
        'skin': lambda: skin_mat(),
        'eye': lambda: BAP.simple('eye', (0.02, 0.015, 0.012), 0.2),
        'hair': lambda: BAP.simple('hair', (0.06, 0.04, 0.025), 0.7),
        'belt': lambda: worn('belt', (0.09, 0.05, 0.025), dirt=0.0, rough=0.5, scale=4),
        'boot': lambda: worn('boot', (0.05, 0.032, 0.02), dirt=0.8, dirt_h=0.12, rough=0.45, scale=6),
        'sole': lambda: BAP.simple('sole', (0.02, 0.02, 0.02), 0.9),
    }
    M.DEF = dict(BAP.Mats.DEF, **extra)
    return M


def fabric(key, base, dirt=0.6):
    """Stoff: Webstruktur, verwaschene Flecken, Oelflecken, Schmutz an Knien/Schienbeinen."""
    m = new_mat("Bake_" + key)
    b = NB(m)
    p = b.principled()
    P = b.n("ShaderNodeTexCoord").outputs['Object']
    xyz = b.sep(P)
    v = b.noise(P, 4, 4, 0.5).outputs['Fac']
    c = b.mix(b.maprange(v, 0.3, 0.7), tuple(x * 0.8 for x in base), tuple(min(1, x * 1.35) for x in base))
    oil = b.noise(P, 7, 6, 0.65, 0.4).outputs['Fac']
    c = b.mix(b.maprange(oil, 0.66, 0.70, 0, 0.85), c, (0.015, 0.013, 0.01))
    dz = b.maprange(xyz[2], 0.05, 0.62, dirt, 0.0, smooth=True)
    dn = b.noise(P, 12, 5, 0.6).outputs['Fac']
    c = b.mix(b.math('MULTIPLY', dz, b.maprange(dn, 0.3, 0.7, 0.5, 1.2)), c, (0.16, 0.13, 0.09))
    # Knie
    knee = b.maprange(b.math('ABSOLUTE', b.math('SUBTRACT', xyz[2], 0.50)), 0.0, 0.07, 0.45 * dirt, 0.0)
    c = b.mix(b.math('MULTIPLY', knee, b.maprange(xyz[1], 0.0, 0.06)), c, (0.18, 0.15, 0.10))
    b.l(c, p.inputs['Base Color'])
    b.l(b.maprange(oil, 0.66, 0.70, 0.9, 0.55), p.inputs['Roughness'])
    bump = b.n("ShaderNodeBump")
    bump.inputs['Strength'].default_value = 0.35
    w1 = b.math('SINE', b.math('MULTIPLY', b.math('ADD', xyz[0], xyz[2]), 900))
    w2 = b.math('SINE', b.math('MULTIPLY', b.math('SUBTRACT', xyz[1], xyz[2]), 900))
    fold = b.noise(b.mapping(P, (3, 3, 9)), 1.0, 3, 0.5).outputs['Fac']
    b.l(b.math('ADD', b.math('MULTIPLY', b.math('ADD', w1, w2), 0.03), b.math('MULTIPLY', fold, 0.6)), bump.inputs['Height'])
    b.l(bump.outputs['Normal'], p.inputs['Normal'])
    return m


def skin_mat():
    m = new_mat("Bake_skin")
    b = NB(m)
    p = b.principled()
    P = b.n("ShaderNodeTexCoord").outputs['Object']
    xyz = b.sep(P)
    n = b.noise(P, 30, 4, 0.5).outputs['Fac']
    c = b.mix(b.maprange(n, 0.3, 0.7), (0.42, 0.25, 0.17), (0.55, 0.36, 0.26))
    # Bartschatten unten am Kopf, Russ an den Haenden
    beard = b.maprange(xyz[2], 1.58, 1.62, 0.35, 0.0)
    c = b.mix(b.math('MULTIPLY', beard, b.maprange(xyz[1], 0.03, 0.08)), c, (0.18, 0.13, 0.10))
    soot = b.maprange(b.math('ABSOLUTE', xyz[0]), 0.72, 0.82, 0.0, 0.5)
    c = b.mix(b.math('MULTIPLY', soot, b.maprange(n, 0.3, 0.8)), c, (0.08, 0.06, 0.05))
    b.l(c, p.inputs['Base Color'])
    p.inputs['Roughness'].default_value = 0.6
    return m


def build_mesh(arm):
    M = mechanic_mats()
    parts = build_body_parts()
    keys = []
    V, F, FM, VB = [], [], [], []
    for (v, f), mk, bones in parts:
        if mk not in keys:
            keys.append(mk)
        o_ = len(V)
        V += [tuple(map(float, p)) for p in v]
        VB += [bones] * len(v)
        for ff in f:
            F.append(tuple(i + o_ for i in ff))
            FM.append(keys.index(mk))
    me = bpy.data.meshes.new("crew_body")
    me.from_pydata(V, [], F)
    me.polygons.foreach_set("material_index", FM)
    for k in keys:
        me.materials.append(M[k])
    bm = bmesh.new()
    bm.from_mesh(me)
    ng = [f for f in bm.faces if len(f.verts) > 4]
    if ng:
        bmesh.ops.triangulate(bm, faces=ng)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    try:
        me.set_sharp_from_angle(angle=math.radians(50))
    except Exception:
        pass
    ob = bpy.data.objects.new("crew_body", me)
    col().objects.link(ob)
    ob.parent = arm
    # Gewichte: inverse Distanz^4 zu den erlaubten Knochensegmenten, max. 3 Einfluesse
    groups = {b[0]: ob.vertex_groups.new(name=b[0]) for b in BONES if b[0] != "Root"}
    for i, v in enumerate(me.vertices):
        p = v.co
        ws = []
        for bn in VB[i]:
            a, b_ = BH[bn]
            d = seg_dist(p, a, b_)
            ws.append((1.0 / (d * d + 0.0004) ** 2, bn))
        ws.sort(reverse=True)
        ws = ws[:3]
        s = sum(w for w, _ in ws)
        for w, bn in ws:
            if w / s > 0.02:
                groups[bn].add([i], w / s, 'REPLACE')
    mod = ob.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm
    return ob, M


# ============================================================================
# Animationen (prozedural). Rotationen relativ, in Armatur-Achsen der T-Pose am Elternknochen:
#   X = Nicken (Bein/Arm nach vorn = +X fuer haengende Glieder, Rumpf nach vorn = -X)
# ============================================================================
def R(axis, deg):
    return Quaternion(Vector(axis), math.radians(deg))


def arm_q(side, down=78.0, fwd=0.0, out=0.0, twist=0.0):
    """Oberarm: aus der T-Pose um 'down' senken, dann um 'fwd' nach vorn schwingen, 'out' seitlich."""
    sx = -1 if side == "Left" else 1
    q = R((0, 1, 0), sx * (down - out))            # senken (links -Y, rechts +Y)
    q = R((1, 0, 0), fwd) @ q                      # vor/zurueck
    q = R((0, 0, 1), sx * 0.0) @ q
    return R((sx, 0, 0), twist) @ q if twist else q


def elbow_q(side, flex):
    sx = -1 if side == "Left" else 1
    return R((0, 0, 1), sx * flex)                 # Unterarm nach vorn beugen


def leg_q(fwd=0.0, out=0.0, side="Left"):
    sx = -1 if side == "Left" else 1
    return R((1, 0, 0), fwd) @ R((0, 1, 0), -sx * out)


def knee_q(flex):
    return R((1, 0, 0), -flex)


def foot_q(up):
    return R((1, 0, 0), up)


def spine_q(fwd=0.0, side=0.0, twist=0.0):
    return R((0, 0, 1), twist) @ R((0, 1, 0), side) @ R((1, 0, 0), -fwd)


def base_pose():
    P = {}
    for S in ("Left", "Right"):
        P[S + "UpperArm"] = arm_q(S, 78, 2)
        P[S + "LowerArm"] = elbow_q(S, 12)
    return P


def gait(ph, stride=25.0, knee=55.0, arm=18.0, elbow=18.0, bob=0.025, lean=3.0, twist=5.0, run=False):
    """Geh-/Laufzyklus, ph in [0,1)."""
    P = base_pose()
    w = 2 * math.pi * ph
    for S, off in (("Left", 0.0), ("Right", math.pi)):
        s = math.sin(w + off)
        c = math.cos(w + off)
        # Kniebeugung: stark in der Schwungphase (s fallend -> Bein kommt nach vorn)
        swing = max(0.0, math.sin(w + off + math.pi * 0.5))
        kf = (8 if not run else 20) + knee * swing ** 1.5
        P[S + "UpperLeg"] = leg_q(stride * s + (8 if run else 0), side=S)
        P[S + "LowerLeg"] = knee_q(kf)
        P[S + "Foot"] = foot_q(-8 * c + (0.4 * kf if s > 0 else 0) * 0.3)
        P[S + "UpperArm"] = arm_q(S, 76 if not run else 70, -arm * s + (10 if run else 0))
        P[S + "LowerArm"] = elbow_q(S, elbow + (6 * max(0, -s)))
    P["Spine"] = spine_q(lean * 0.5, 0, twist * math.sin(w))
    P["Chest"] = spine_q(lean * 0.5, 0, -twist * 1.4 * math.sin(w))
    P["Neck"] = spine_q(-lean * 0.6, 0, twist * 0.4 * math.sin(w))
    P["Hips"] = spine_q(0, 2 * math.sin(w), -twist * 0.6 * math.sin(w))
    P["_hips"] = Vector((0.015 * math.sin(w), 0, -bob * 0.5 + bob * abs(math.cos(w)) - (0.03 if run else 0.0)))
    return P


def carry_arms(P, lift=0.0):
    for S in ("Left", "Right"):
        P[S + "UpperArm"] = arm_q(S, 64 - lift * 10, 30 + lift * 8, out=-8)
        P[S + "LowerArm"] = elbow_q(S, 72 - lift * 10)
        P[S + "Hand"] = R((1, 0, 0), 10) @ R((0, 1, 0), (1 if S == "Left" else -1) * 20)
    P["UpperChest"] = spine_q(-6, 0, 0)
    return P


def anim_idle(t, L):
    ph = t / L
    w = 2 * math.pi * ph
    P = base_pose()
    P["Chest"] = spine_q(1.5 * math.sin(w), 0, 0)
    P["UpperChest"] = spine_q(1.0 * math.sin(w), 0, 0)
    P["Head"] = spine_q(-2 + 2 * math.sin(w * 0.5), 0, 6 * math.sin(w * 0.5))
    P["Hips"] = spine_q(0, 1.5 * math.sin(w * 0.5), 0)
    P["_hips"] = Vector((0.012 * math.sin(w * 0.5), 0, -0.004 + 0.004 * math.cos(w)))
    for S, sx in (("Left", -1), ("Right", 1)):
        P[S + "UpperLeg"] = leg_q(0, 2 - sx * 1.5 * math.sin(w * 0.5), S)
        P[S + "LowerLeg"] = knee_q(3 + 2 * (0.5 + 0.5 * sx * math.sin(w * 0.5)))
        P[S + "UpperArm"] = arm_q(S, 78 + 1.5 * math.sin(w), 3)
    return P


def anim_walk(t, L):
    return gait(t / L)


def anim_run(t, L):
    return gait(t / L, stride=38, knee=95, arm=32, elbow=75, bob=0.05, lean=12, twist=8, run=True)


def anim_carry(t, L):
    P = gait(t / L, stride=18, knee=45, arm=0, elbow=0, bob=0.02, lean=-2, twist=2)
    return carry_arms(P)


def anim_hose(t, L):
    w = 2 * math.pi * t / L
    P = anim_idle(t, L)
    P["RightUpperArm"] = arm_q("Right", 62, 38 + 2 * math.sin(w), out=-6)
    P["RightLowerArm"] = elbow_q("Right", 70)
    P["LeftUpperArm"] = arm_q("Left", 70, 48 + 2 * math.sin(w), out=-22)
    P["LeftLowerArm"] = elbow_q("Left", 55)
    P["Spine"] = spine_q(4, 0, -10)
    P["Head"] = spine_q(-8, 0, 12 + 4 * math.sin(w))
    for S, f, o in (("Left", 10, 6), ("Right", -6, 6)):
        P[S + "UpperLeg"] = leg_q(f, o, S)
        P[S + "LowerLeg"] = knee_q(10)
    return P


def anim_lift(t, L):
    """Kiste anheben: in die Hocke, greifen, mit geradem Ruecken aufrichten -> Tragehaltung."""
    u = t / L
    down = math.sin(math.pi * min(1.0, u / 0.85)) if u < 0.425 else (1.0 if u < 0.5 else max(0.0, math.cos(math.pi * 0.5 * (u - 0.5) / 0.4)))
    down = max(0.0, min(1.0, down))
    P = base_pose()
    for S in ("Left", "Right"):
        P[S + "UpperLeg"] = leg_q(85 * down, 8 * down, S)
        P[S + "LowerLeg"] = knee_q(110 * down + 4)
        P[S + "Foot"] = foot_q(-25 * down)
    P["Spine"] = spine_q(25 * down, 0, 0)
    P["Chest"] = spine_q(10 * down, 0, 0)
    P["Neck"] = spine_q(-15 * down, 0, 0)
    P["_hips"] = Vector((0, -0.08 * down, -0.42 * down))
    grip = min(1.0, u / 0.4)
    carry = max(0.0, (u - 0.45) / 0.55)
    for S in ("Left", "Right"):
        a = arm_q(S, 70, 25, out=-10)
        b = arm_q(S, 64, 30, out=-8)
        P[S + "UpperArm"] = arm_q(S, 78, 2).slerp(a, grip).slerp(b, carry)
        P[S + "LowerArm"] = elbow_q(S, 12 + 10 * grip + 50 * carry)
    return P


def anim_work(t, L):
    """Arbeiten am Flugzeug: Haende vorn in Brust-/Kopfhoehe, rechte Hand mit Schraubbewegung."""
    w = 2 * math.pi * t / L
    P = base_pose()
    P["RightUpperArm"] = arm_q("Right", 40 + 6 * math.sin(w * 2), 55, out=-10)
    P["RightLowerArm"] = elbow_q("Right", 70 + 15 * math.sin(w * 2))
    P["RightHand"] = R((1, 0, 0), 25 * math.sin(w * 2))
    P["LeftUpperArm"] = arm_q("Left", 45, 60 + 3 * math.sin(w), out=-5)
    P["LeftLowerArm"] = elbow_q("Left", 50)
    P["Spine"] = spine_q(-3, 0, 5 * math.sin(w))
    P["Head"] = spine_q(8, 0, 5 * math.sin(w))
    for S, f in (("Left", 12), ("Right", -4)):
        P[S + "UpperLeg"] = leg_q(f, 5, S)
        P[S + "LowerLeg"] = knee_q(10)
    P["_hips"] = Vector((0.01 * math.sin(w), 0, -0.01))
    return P


def anim_enter(t, L):
    """Einsteigen: Hand an den Rahmen, rechter Fuss hoch auf den Fluegel, hochdruecken, Bein nachziehen."""
    u = t / L
    e = lambda a, b: max(0.0, min(1.0, (u - a) / (b - a)))  # noqa
    s = lambda x: x * x * (3 - 2 * x)  # noqa
    reach, step, push, follow = s(e(0.0, 0.3)), s(e(0.1, 0.45)), s(e(0.4, 0.8)), s(e(0.6, 1.0))
    P = base_pose()
    P["RightUpperArm"] = arm_q("Right", 78 - 70 * reach, 2 + 80 * reach)
    P["RightLowerArm"] = elbow_q("Right", 12 + 30 * reach - 25 * push)
    P["LeftUpperArm"] = arm_q("Left", 78 - 45 * reach, 2 + 70 * reach)
    P["LeftLowerArm"] = elbow_q("Left", 12 + 50 * reach - 30 * push)
    P["RightUpperLeg"] = leg_q(85 * step - 75 * push, 0, "Right")
    P["RightLowerLeg"] = knee_q(100 * step - 95 * push + 5)
    P["LeftUpperLeg"] = leg_q(-10 * push + 70 * follow * (1 - follow) * 4 * 0.5, 0, "Left")
    P["LeftLowerLeg"] = knee_q(15 * push + 60 * follow * (1 - follow) * 4 * 0.5)
    P["Spine"] = spine_q(20 * step * (1 - push) + 8, 0, -8 * reach)
    P["Neck"] = spine_q(-15 * reach, 0, 0)
    P["_hips"] = Vector((0, 0.15 * push, 0.45 * push - 0.06 * step * (1 - push)))
    return P


ANIMS = [  # name, Laenge (s), Schleife, Funktion
    ("idle", 2.4, True, anim_idle),
    ("walk", 1.0, True, anim_walk),       # 1,6 m/s -> 1,6 m je Zyklus
    ("run", 0.7, True, anim_run),         # 4,5 m/s -> 3,15 m je Zyklus
    ("carry", 1.1, True, anim_carry),
    ("hose", 2.4, True, anim_hose),
    ("lift", 1.6, False, anim_lift),
    ("work", 1.6, True, anim_work),
    ("enter", 1.2, False, anim_enter),
]


def apply_pose(arm, P):
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
        B = pb.bone.matrix_local.to_quaternion()
        q = P.get(pb.name)
        pb.rotation_quaternion = (B.inverted() @ q @ B) if q is not None else Quaternion()
        pb.location = Vector()
    hb = arm.pose.bones["Hips"]
    off = P.get("_hips")
    if off is not None:
        hb.location = hb.bone.matrix_local.to_3x3().inverted() @ off


def make_actions(arm):
    arm.animation_data_create()
    info = {}
    for name, L, loop, fn in ANIMS:
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm.animation_data.action = act
        n = int(round(L * FPS))
        step = 2
        frames = list(range(0, n + 1, step))
        if frames[-1] != n:
            frames.append(n)
        for f in frames:
            tt = (f % n) / FPS if loop else f / FPS
            apply_pose(arm, fn(tt, L))
            for pb in arm.pose.bones:
                pb.keyframe_insert("rotation_quaternion", frame=f + 1)
                if pb.name == "Hips":
                    pb.keyframe_insert("location", frame=f + 1)
        tr = arm.animation_data.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, 1, act)
        st.name = name
        tr.mute = True
        arm.animation_data.action = None
        info[name] = dict(seconds=L, loop=loop, frames=n + 1)
    apply_pose(arm, {})
    return info


# ============================================================================
def main_build():
    t0 = time.time()
    reset_scene()
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.render.bake.margin_type = 'EXTEND'
    scene.render.fps = FPS
    world = bpy.data.worlds.new("BakeWorld")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
    world.light_settings.distance = 0.15
    arm = build_armature()
    body, M = build_mesh(arm)
    size = 256 if OPT["quick"] else 1024
    body.modifiers["Armature"].show_render = False
    uv_unwrap([body], 0.004)
    res = bake_group([body], M, size, ['albedo', 'rough', 'metal', 'normal', 'ao'], "crew_mechanic")
    pa = {k: os.path.join(TEX, "crew_mechanic_%s.png" % k) for k in ('albedo', 'normal', 'orm')}
    save_image(res['albedo'], pa['albedo'])
    save_image(res['normal'], pa['normal'])
    pack_orm(res['ao'], res['rough'], res['metal'], pa['orm'])
    body.modifiers["Armature"].show_render = True
    mat = pbr_material("M_crew_mechanic", pa['albedo'], pa['normal'], pa['orm'])
    body.data.materials.clear()
    body.data.materials.append(mat)
    # Marker
    markers = {}

    def marker(name, pos, bone=None):
        e = bpy.data.objects.new(name, None)
        col().objects.link(e)
        e.empty_display_size = 0.08
        e.parent = arm
        if bone:
            e.parent_type = 'BONE'
            e.parent_bone = bone
            bpy.context.view_layer.update()
            e.matrix_world = Matrix.Translation(Vector(pos))
        else:
            e.location = pos
        markers[name] = dict(pos=BAP.C(Vector(pos)), bone=bone)
    marker("hand_R", (0.775, 0.0, SH_Z - 0.03), "RightHand")
    marker("hand_L", (-0.775, 0.0, SH_Z - 0.03), "LeftHand")
    marker("carry", (0.0, 0.42, 1.0))
    bpy.context.view_layer.update()
    info = make_actions(arm)
    tris = tri_count(body)
    out = os.path.join(MODELS, "crew_mechanic.glb")
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    for o in arm.children_recursive:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_apply=False, export_yup=True,
                              export_extras=True, export_cameras=False, export_lights=False, export_tangents=True,
                              export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True,
                              export_frame_range=False, export_anim_single_armature=True, export_def_bones=False,
                              export_optimize_animation_size=False)
    shutil.copy(out, os.path.join(GAME, "crew_mechanic.glb"))
    data = dict(model="crew_mechanic.glb", triangles=tris, texture_size=size,
                convention=dict(up="+Y", forward="-Z", origin="Boden zwischen den Fuessen", rest_pose="T-Pose",
                                skeleton="Godot SkeletonProfileHumanoid (ohne Finger/Augen/Kiefer)"),
                bones=[b[0] for b in BONES], animations=info, markers=markers,
                size_mb=round(os.path.getsize(out) / 1e6, 2))
    with open(os.path.join(MODELS, "crew_mechanic.json"), "w") as fh:
        json.dump(data, fh, indent=1, ensure_ascii=False)
    print("GLB", out, data["size_mb"], "MB,", tris, "Dreiecke,", len(info), "Animationen, %.1fs" % (time.time() - t0))


def render_poses():
    reset_scene()
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 24
    scene.render.resolution_x, scene.render.resolution_y = 640, 360
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
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    scene.collection.objects.link(sun)
    gm = BAP.ground_mat('pg', grass=(0.13, 0.16, 0.07), earth=(0.20, 0.17, 0.12), mix=0.7)
    bpy.ops.mesh.primitive_plane_add(size=60)
    bpy.context.active_object.data.materials.append(gm)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    poses = [("idle", 0.0), ("walk", 0.25), ("run", 0.2), ("carry", 0.3), ("lift", 0.5), ("hose", 0.0), ("work", 0.3), ("enter", 0.45)]
    for i, (an, frac) in enumerate(poses):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, "crew_mechanic.glb"))
        new = [o for o in bpy.data.objects if o not in before]
        armo = [o for o in new if o.type == 'ARMATURE'][0]
        root = [o for o in new if o.parent is None][0]
        root.rotation_mode = 'XYZ'
        root.location = ((i % 4) * 1.2 - 1.8, -(i // 4) * 1.6, 0)
        root.rotation_euler = (0, 0, math.radians(-35))
        act = bpy.data.actions.get(an)
        if armo.animation_data is None:
            armo.animation_data_create()
        armo.animation_data.action = act
        try:
            armo.animation_data.action_slot = act.slots[0]
        except Exception:
            pass
        for tr in list(armo.animation_data.nla_tracks):
            armo.animation_data.nla_tracks.remove(tr)
        f0, f1 = act.frame_range
        scene.frame_set(int(round(f0 + (f1 - f0) * frac)))
        bpy.context.view_layer.update()
        armo.animation_data.action = None   # Pose bleibt als Standbild stehen
    cam.location = (3.4, 6.2, 2.6)
    cam.data.lens = 36
    d = Vector((0.0, -0.9, 0.85)) - cam.location
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = os.path.join(PREV, "ground_crew_poses.png")
    bpy.ops.render.render(write_still=True)


if OPT["build"]:
    main_build()
if OPT["render"]:
    render_poses()
