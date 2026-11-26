class_name AirfieldDressing
extends RefCounted
## M3.4: Platz-Ausstattung im Stil B (sparsam: prozedurale Meshes, MultiMesh, Rauschtexturen zur
## Laufzeit – keine neuen Bilddateien). Alles lokal zum Platzknoten (Mitte der Piste, y = 0 =
## Platzhöhe; die Platzfläche 1.560 × 340 m ist eben).
##   Graspiste 1.300 × 60 m mit gemähtem/abgefahrenem Mittelstreifen und Radspuren,
##   Randmarken (weiße Steine alle 50 m), Schwellen (Steinreihe, rot-weiße Eckflaggen), Lande-T,
##   zwei Windsäcke (Windsock, animiert), Rollwege und Abstellfläche aus dem Rollweg-Graph,
##   Platzrand (Hecke West/Nord/Süd, Holzzaun Ost), Flugleitung mit Funkmast, Holzschuppen, Fässer.
## Gebäude (Flugleitung, Schuppen) haben Kollision (auch headless), der Rest ist nur Optik.

const HEDGE_X := Vector2(-165.0, 150.0)   ## West- und Ostrand (x)
const HEDGE_Z := 770.0                     ## Nord-/Südrand (±z)
const TOWER_POS := Vector3(-90.0, 0.0, 70.0)   ## relativ zur Schwelle (x absolut, z ab Schwelle)
const SHED_POS := Vector3(-145.0, 0.0, -160.0)

static var _mats := {}


static func mat(key: String, c: Color, rough := 0.95) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


static func noise_mat(c0: Color, c1: Color, freq: float, uv: Vector3, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	var nn := FastNoiseLite.new()
	nn.frequency = freq
	nt.noise = nn
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	nt.color_ramp = g
	m.albedo_texture = nt
	m.uv1_scale = uv
	m.roughness = 1.0
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, alpha)
		m.render_priority = 1
	return m


## Positionen (lokal) der Gebäude mit Kollision – auch für Tests (Abstand zu Rollwegen).
static func building_positions(l: AirfieldLayout) -> Array:
	var sz := l.runway_start.z
	return [Vector3(TOWER_POS.x, 0, sz + TOWER_POS.z), Vector3(SHED_POS.x, 0, sz + SHED_POS.z)]


## Platz ausstatten. visuals = false: nur Kollisionen der Gebäude.
static func build(node: Node3D, l: AirfieldLayout, visuals: bool) -> void:
	var sz := l.runway_start.z
	var tower := Vector3(TOWER_POS.x, 0, sz + TOWER_POS.z)
	var shed := Vector3(SHED_POS.x, 0, sz + SHED_POS.z)
	_collider(node, tower + Vector3(0, 3.5, 0), Vector3(8, 7, 6))
	_collider(node, shed + Vector3(0, 2.2, 0), Vector3(10, 4.4, 6))
	if not visuals:
		return
	_runway(node, l)
	_taxiways(node, l)
	_markers(node, l)
	_ground_detail(node, l)
	_boundary(node)
	_tower(node, tower)
	_shed(node, shed)
	_barrels(node, l.fuel_depot + Vector3(-18, 0, 30))
	_barrels(node, shed + Vector3(8, 0, 2))
	for z in [sz - 220.0, -sz + 160.0]:
		var ws := Windsock.new()
		ws.position = Vector3(l.runway_width * 0.5 + 22.0, 0, z)
		node.add_child(ws)


static func _collider(node: Node3D, center: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.name = "Gebaeude"
	b.collision_layer = Layers.WORLD
	b.collision_mask = 0
	b.position = center
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	node.add_child(b)


static func _mi(node: Node3D, mesh: Mesh, m: Material, pos: Vector3, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	return mi


static func _plane(w: float, len: float) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(w, len)
	return p


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


# --- Piste ---------------------------------------------------------------------------------

static func _runway(node: Node3D, l: AirfieldLayout) -> void:
	var len := l.runway_length() + 40.0
	var w := l.runway_width
	var mid_z := (l.runway_start.z + l.runway_end.z) * 0.5
	# Grundfläche: gemähtes Gras, Mählanen (abwechselnd heller, 10 m breit)
	var base := _mi(node, _plane(w, len), noise_mat(Color(0.15, 0.22, 0.07), Color(0.24, 0.30, 0.11), 0.03,
		Vector3(2.0, 40.0, 1.0)), Vector3(0, 0.05, mid_z), false)
	base.name = "Runway"
	var lane := noise_mat(Color(0.30, 0.36, 0.15), Color(0.36, 0.40, 0.2), 0.02, Vector3(1.0, 30.0, 1.0), 0.3)
	var nl := int(w / 10.0)
	for k in nl:
		if k % 2 == 0:
			_mi(node, _plane(w / nl, len), lane, Vector3(-w * 0.5 + (k + 0.5) * w / nl, 0.055, mid_z), false)
	# abgefahrener Mittelstreifen (lehmig, halbtransparent) und zwei Radspuren
	var worn := noise_mat(Color(0.30, 0.27, 0.15), Color(0.42, 0.37, 0.22), 0.05, Vector3(1.0, 60.0, 1.0), 0.65)
	_mi(node, _plane(w * 0.25, len - 60.0), worn, Vector3(0, 0.07, mid_z), false).name = "RunwayWorn"
	var track := noise_mat(Color(0.28, 0.23, 0.13), Color(0.38, 0.32, 0.2), 0.08, Vector3(1.0, 80.0, 1.0), 0.7)
	for sx in [-1.0, 1.0]:
		_mi(node, _plane(1.6, len - 120.0), track, Vector3(sx * 1.9, 0.09, mid_z), false)


## Rollwege als ein Mesh (Streifen je Kante, 12 m breit) + Abstellfläche.
static func _taxiways(node: Node3D, l: AirfieldLayout) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 6.0
	for k in range(0, l.taxi_edges.size() - 1, 2):
		var a := l.taxi_nodes[l.taxi_edges[k]]
		var b := l.taxi_nodes[l.taxi_edges[k + 1]]
		var d := Vector3(b.x - a.x, 0, b.z - a.z)
		if d.length() < 0.5:
			continue
		var n := Vector3(-d.z, 0, d.x).normalized() * hw
		var e := d.normalized() * hw * 0.8   # Überlappung an den Knoten
		var pa := a - e
		var pb := b + e
		var quad := [pa - n, pa + n, pb + n, pb - n]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, (d.length() + 2.0 * hw) / 12.0), Vector2(0, (d.length() + 2.0 * hw) / 12.0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uvs[idx])
			st.set_normal(Vector3.UP)
			var q: Vector3 = quad[idx]
			st.add_vertex(Vector3(q.x, 0.06, q.z))
	var m := noise_mat(Color(0.24, 0.26, 0.11), Color(0.36, 0.34, 0.19), 0.06, Vector3(1, 1, 1), 0.6)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := _mi(node, st.commit(), m, Vector3.ZERO, false)
	mi.name = "Taxiways"
	# Abstellfläche: abgefahrenes Gras unter den Plätzen
	if l.parking_count() > 0:
		var zmin := INF
		var zmax := -INF
		var x := 0.0
		for p in l.parking_positions:
			zmin = minf(zmin, p.z)
			zmax = maxf(zmax, p.z)
			x += p.x / l.parking_count()
		var apron := _mi(node, _plane(26.0, zmax - zmin + 30.0), m, Vector3(x, 0.055, (zmin + zmax) * 0.5), false)
		apron.name = "Apron"


static func _multi(node: Node3D, mesh: Mesh, m: Material, xfs: Array, colors: Array = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if not colors.is_empty():
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	node.add_child(mmi)
	return mmi


## Randsteine alle 50 m, Schwellen-Steinreihen, rot-weiße Eckflaggen, Lande-T.
static func _markers(node: Node3D, l: AirfieldLayout) -> void:
	var w := l.runway_width
	var s0 := l.runway_start.z
	var s1 := l.runway_end.z
	var stones := []
	var n := int(round((s0 - s1) / 50.0))
	for i in n + 1:
		var z := s0 - (s0 - s1) * i / float(n)
		for sx in [-1.0, 1.0]:
			stones.append(Transform3D(Basis(), Vector3(sx * (w * 0.5 + 1.0), 0.18, z)))
	# Schwellen: Reihe quer über die Piste (Lücke in der Mitte frei für die Radspuren)
	for z in [s0 + 3.0, s1 - 3.0]:
		for k in 10:
			var x := -w * 0.5 + 3.0 + k * (w - 6.0) / 9.0
			if absf(x) > 4.0:
				stones.append(Transform3D(Basis().scaled(Vector3(1.4, 1, 1.6)), Vector3(x, 0.18, z)))
	var white := mat("weiss", Color(0.93, 0.93, 0.9))
	_multi(node, _box(Vector3(1.6, 0.35, 0.7)), white, stones).name = "RunwayMarkers"
	# Eckflaggen (Stab + Fahne): Fahne rot-weiß als zwei Hälften
	var poles := []
	var red_f := []
	var white_f := []
	for z in [s0 + 3.0, s1 - 3.0]:
		for sx in [-1.0, 1.0]:
			var p := Vector3(sx * (w * 0.5 + 4.0), 0, z)
			poles.append(Transform3D(Basis(), p + Vector3(0, 1.5, 0)))
			red_f.append(Transform3D(Basis(), p + Vector3(0, 2.7, 0.35)))
			white_f.append(Transform3D(Basis(), p + Vector3(0, 2.7, 1.05)))
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04
	pm.bottom_radius = 0.05
	pm.height = 3.0
	pm.radial_segments = 6
	_multi(node, pm, white, poles)
	var fm := _box(Vector3(0.03, 0.6, 0.7))
	_multi(node, fm, mat("rot", Color(0.8, 0.16, 0.12)), red_f)
	_multi(node, fm, white, white_f)
	# Lande-T (weißes Tuch) östlich der Schwelle, Querbalken zur Landerichtung
	var t := Node3D.new()
	t.name = "LandeT"
	t.position = Vector3(w * 0.5 + 18.0, 0.08, s0 - 70.0)
	node.add_child(t)
	_mi(t, _box(Vector3(12.0, 0.06, 2.0)), white, Vector3(0, 0, -5.0), false)
	_mi(t, _box(Vector3(2.0, 0.06, 12.0)), white, Vector3(0, 0, 1.0), false)


# --- M3.6: Bodendetail (nur Optik, keine Kollision, keine Änderung an Layout/Navigation) ------

static var _blob_tex: GradientTexture2D


## Weicher runder Fleck (64 px, radial, Alpha nach außen 0) – Grundlage für alle Flecken.
static func _blob() -> GradientTexture2D:
	if _blob_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.55, Color(1, 1, 1, 0.75))
		_blob_tex = GradientTexture2D.new()
		_blob_tex.gradient = g
		_blob_tex.fill = GradientTexture2D.FILL_RADIAL
		_blob_tex.fill_from = Vector2(0.5, 0.5)
		_blob_tex.fill_to = Vector2(0.5, 0.0)
		_blob_tex.width = 64
		_blob_tex.height = 64
	return _blob_tex


static func _blob_mat(prio: int, rough := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _blob()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = rough
	m.render_priority = prio
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Flache Fleck-Instanz: Größe (x quer, z längs), Drehung um die Hochachse, Höhe y.
static func _flat(p: Vector3, sx: float, sz: float, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sx, 1, sz)), p)


## Grasfarb-Flecken auf der Piste, Reifenabrieb in den Aufsetzzonen, Ölflecken am Vorfeld,
## kleine Wimpel zwischen den Randsteinen.
static func _ground_detail(node: Node3D, l: AirfieldLayout) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1939
	var w := l.runway_width
	var s0 := l.runway_start.z
	var s1 := l.runway_end.z
	var len := s0 - s1
	var quad := _plane(1.0, 1.0)
	# 1) Farbvariation: große, weiche Flecken heller/dunkler/gelblicher Grüntöne
	var px := []
	var pc := []
	for i in int(len / 18.0):
		var z := rng.randf_range(s1 - 10.0, s0 + 10.0)
		var x := rng.randf_range(-w * 0.5 + 4.0, w * 0.5 - 4.0)
		var s := rng.randf_range(10.0, 28.0)
		px.append(_flat(Vector3(x, 0.06, z), s, s * rng.randf_range(1.2, 2.6), rng.randf_range(-0.3, 0.3)))
		var tones := [Color(0.08, 0.14, 0.04), Color(0.34, 0.40, 0.14), Color(0.44, 0.40, 0.18), Color(0.13, 0.22, 0.05)]
		var c: Color = tones[rng.randi() % tones.size()]
		c.a = rng.randf_range(0.3, 0.5)
		pc.append(c)
	_multi(node, quad, _blob_mat(0), px, pc).name = "RunwayPatches"
	# 2) Reifenabrieb: lange dunkle Striche an den Radspuren in beiden Aufsetzzonen
	var tx := []
	var tc := []
	for zone in [[s0 - 40.0, s0 - 260.0], [s1 + 40.0, s1 + 260.0]]:
		for i in 110:
			var z := rng.randf_range(zone[1], zone[0])
			var track := (1.0 if rng.randf() < 0.5 else -1.0) * 1.9
			var x := track + rng.randf_range(-0.5, 0.5) if rng.randf() < 0.75 else rng.randf_range(-7.0, 7.0)
			# Dichte zur Schwelle hin höher: Länge und Deckkraft nach Abstand
			var near := 1.0 - absf(z - zone[0]) / 220.0
			tx.append(_flat(Vector3(x, 0.1, z), rng.randf_range(0.4, 0.8), rng.randf_range(5.0, 16.0),
				rng.randf_range(-0.025, 0.025)))
			tc.append(Color(0.10, 0.08, 0.05, lerpf(0.3, 0.65, near) * rng.randf_range(0.7, 1.0)))
	_multi(node, quad, _blob_mat(2), tx, tc).name = "TireMarks"
	# 3) Ölflecken auf dem Vorfeld (Abstellplätze, Tanklager), leicht glänzend
	var ox := []
	var oc := []
	var spots := Array(l.parking_positions)
	spots.append(l.fuel_depot + Vector3(-18, 0, 30))
	for p in spots:
		for k in 3:
			var o := Vector3(rng.randf_range(-3.0, 3.0), 0, rng.randf_range(-4.0, 2.0))
			var s := rng.randf_range(0.8, 2.2)
			ox.append(_flat(Vector3(p.x + o.x, 0.075, p.z + o.z), s, s * rng.randf_range(0.8, 1.5), rng.randf() * TAU))
			oc.append(Color(0.07, 0.05, 0.03, rng.randf_range(0.45, 0.75)))
	_multi(node, quad, _blob_mat(2, 0.55), ox, oc).name = "OilStains"
	# 4) Wimpel (gelb, dreieckig angedeutet) mittig zwischen den Randsteinen, alle 100 m
	var wp := []
	var wf := []
	var n := int(round(len / 100.0))
	for i in n:
		var z := s0 - len * (i + 0.5) / float(n)
		for sx in [-1.0, 1.0]:
			var p := Vector3(sx * (w * 0.5 + 2.5), 0, z)
			wp.append(Transform3D(Basis(), p + Vector3(0, 0.6, 0)))
			wf.append(p + Vector3(0, 1.05, 0.22))
	var pm := CylinderMesh.new()
	pm.top_radius = 0.025
	pm.bottom_radius = 0.03
	pm.height = 1.2
	pm.radial_segments = 5
	_multi(node, pm, mat("weiss", Color(0.93, 0.93, 0.9)), wp).name = "EdgePennantPoles"
	var pen := PrismMesh.new()
	pen.size = Vector3(0.3, 0.45, 0.02)
	# Dreieck senkrecht stellen (dünn in x), Spitze nach +z (Wind aus Norden)
	var pen_b := Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI * 0.5)
	for i in wf.size():
		wf[i] = Transform3D(pen_b, wf[i])
	_multi(node, pen, mat("gelb", Color(0.92, 0.72, 0.12)), wf).name = "EdgePennants"


# --- Platzrand -----------------------------------------------------------------------------

## Hecke (West, Nord, Süd) als MultiMesh-Abschnitte, Holzzaun (Ost) aus Pfosten und Latten.
static func _boundary(node: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1938
	var seg := 12.0
	var xfs := []
	var cols := []
	var lines := [[Vector2(HEDGE_X.x, -HEDGE_Z), Vector2(HEDGE_X.x, HEDGE_Z)],
		[Vector2(HEDGE_X.x, HEDGE_Z), Vector2(HEDGE_X.y, HEDGE_Z)],
		[Vector2(HEDGE_X.x, -HEDGE_Z), Vector2(HEDGE_X.y, -HEDGE_Z)]]
	for ln in lines:
		var a: Vector2 = ln[0]
		var b: Vector2 = ln[1]
		var cnt := int(a.distance_to(b) / seg)
		var dir := (b - a).normalized()
		var yaw := atan2(dir.x, dir.y)
		for k in cnt:
			if rng.randf() < 0.06:
				continue   # Lücken
			var c := a + dir * (k + 0.5) * seg
			var h := rng.randf_range(1.5, 2.6)
			var bs := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(rng.randf_range(2.0, 3.0), h, seg * rng.randf_range(1.0, 1.15)))
			xfs.append(Transform3D(bs, Vector3(c.x, h * 0.5 - 0.1, c.y)))
			cols.append(Color(0.16, 0.24, 0.09).lerp(Color(0.24, 0.31, 0.12), rng.randf()))
	var hm := mat("hecke", Color(1, 1, 1))
	hm.vertex_color_use_as_albedo = true
	_multi(node, _box(Vector3.ONE), hm, xfs, cols).name = "Hecke"
	# Holzzaun Ost: Pfosten alle 4 m, zwei Latten je Feld
	var posts := []
	var rails := []
	var z := -HEDGE_Z
	while z < HEDGE_Z:
		posts.append(Transform3D(Basis(), Vector3(HEDGE_X.y, 0.6, z)))
		for y in [0.5, 1.0]:
			rails.append(Transform3D(Basis(), Vector3(HEDGE_X.y, y, z + 2.0)))
		z += 4.0
	var wood := mat("holz", Color(0.36, 0.27, 0.18))
	_multi(node, _box(Vector3(0.14, 1.2, 0.14)), wood, posts).name = "Zaun"
	_multi(node, _box(Vector3(0.05, 0.1, 4.0)), wood, rails)


# --- Gebäude und Kleinkram -----------------------------------------------------------------

static func _roof(node: Node3D, pos: Vector3, w: float, d: float, h: float, m: Material) -> void:
	var pr := PrismMesh.new()
	pr.size = Vector3(w, h, d)
	_mi(node, pr, m, pos + Vector3(0, h * 0.5, 0))


## Flugleitung: zweigeschossiges Holzhaus mit Fensterband und Satteldach, Funkmast daneben.
static func _tower(node: Node3D, p: Vector3) -> void:
	var g := Node3D.new()
	g.name = "Flugleitung"
	g.position = p
	node.add_child(g)
	_mi(g, _box(Vector3(8, 6, 6)), mat("putz", Color(0.78, 0.74, 0.64)), Vector3(0, 3, 0))
	_mi(g, _box(Vector3(8.1, 1.0, 6.1)), mat("fenster", Color(0.12, 0.14, 0.16), 0.3), Vector3(0, 4.6, 0))
	_mi(g, _box(Vector3(1.2, 2.2, 0.1)), mat("holz", Color(0.36, 0.27, 0.18)), Vector3(1.5, 1.1, 3.02))
	_roof(g, Vector3(0, 6, 0), 8.8, 6.8, 2.2, mat("dach", Color(0.35, 0.22, 0.17)))
	# Funkmast: Rohrmast mit Querträger und Antennendraht zum Haus
	var mast := CylinderMesh.new()
	mast.top_radius = 0.09
	mast.bottom_radius = 0.16
	mast.height = 22.0
	mast.radial_segments = 6
	var steel := mat("stahl", Color(0.32, 0.33, 0.33), 0.6)
	_mi(g, mast, steel, Vector3(-14, 11, 12))
	_mi(g, _box(Vector3(3.0, 0.1, 0.1)), steel, Vector3(-14, 21.5, 12))
	var wire := _box(Vector3(0.03, 0.03, 1.0))
	var a := Vector3(-14, 21.4, 12)
	var b := Vector3(0, 7.0, 0)
	var wi := _mi(g, wire, steel, (a + b) * 0.5, false)
	wi.basis = Basis.looking_at(b - a, Vector3.UP).scaled(Vector3(1, 1, a.distance_to(b)))


static func _shed(node: Node3D, p: Vector3) -> void:
	var g := Node3D.new()
	g.name = "Schuppen"
	g.position = p
	node.add_child(g)
	var wood := mat("bretter", Color(0.33, 0.24, 0.16))
	_mi(g, _box(Vector3(10, 3.2, 6)), wood, Vector3(0, 1.6, 0))
	_mi(g, _box(Vector3(3.0, 2.6, 0.1)), mat("holz_dunkel", Color(0.22, 0.16, 0.11)), Vector3(0, 1.3, 3.02))
	_roof(g, Vector3(0, 3.2, 0), 10.6, 6.6, 1.4, mat("teerpappe", Color(0.18, 0.18, 0.19)))


static func _barrels(node: Node3D, c: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(c.x * 13.0 + c.z))
	var xfs := []
	for i in 4:
		for j in 3:
			if rng.randf() < 0.2:
				continue
			xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c + Vector3(i * 0.75, 0.45, j * 0.75)))
	# zwei liegende Fässer
	xfs.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(-1.4, 0.3, 0.5)))
	xfs.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(-1.4, 0.3, 1.2)))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 0.9
	cm.radial_segments = 10
	_multi(node, cm, mat("fass", Color(0.24, 0.3, 0.2), 0.7), xfs).name = "Faesser"
