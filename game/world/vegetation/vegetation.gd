class_name Vegetation
extends Node3D
## M3.7: Vegetation um die Kamera – Bäume, Büsche, Hecken (MultiMesh je Zelle à 256 m, im
## Hintergrund erzeugt von VegetationGen) und Gras-Büschel (GPU, grass.gdshader).
## Nur mit Optik (TerrainWorld.build_visuals); headless gibt es keine Vegetation.
##
## Detailstufen je Instanz (tree.gdshader): LOD0 bis NEAR_R um einen Bezugspunkt (die CPU wählt
## die Instanzen aus, neu ab 25 m Kamera-Weg), LOD1 bis LOD_R, LOD2 bis zur Sichtweite.
## Kollision: einfache Zylinder (Stamm + Krone) für Bäume in Zellen bis COLLIDE_R um die
## Kamera (Layers.WORLD) – tief fliegende Flugzeuge zerschellen daran. Büsche ohne Kollision.
## Platzflächen, Roll-/Fahrwege und die An-/Abflugschneisen bleiben frei (VegetationGen.keepout).
##
## Einstellung "Vegetation" (GameSettings): Aus / Niedrig / Mittel / Hoch, Standard Mittel;
## im Selbsttest aus (Software-Darstellung, Laufzeit wie bisher).

const LEVELS := ["aus", "niedrig", "mittel", "hoch"]
const LABELS := ["Aus", "Niedrig", "Mittel", "Hoch"]
## Je Stufe: [Baum-Sichtweite m, Gras-Radius m, Gras-Raster m]
const PARAMS := [[0.0, 0.0, 0.0], [1300.0, 24.0, 0.8], [2200.0, 42.0, 0.6], [3200.0, 64.0, 0.5]]
const LOD_R := 380.0
const NEAR_R := 110.0
const NEAR_MOVE := 25.0
const NEAR_MAX_AGL := 260.0
const COLLIDE_R := 700.0
const TREE_RADIUS := 0.45
const MODEL := "res://assets/ground/vegetation.glb"
const MAX_TASKS := 2
const CELL := VegetationGen.CELL

## Aktive Stufe (Index in LEVELS); override_level >= 0 (Screenshots) hat Vorrang vor der Einstellung.
static var level := 2
static var override_level := -1

var tw: TerrainWorld
var gen: VegetationGen
var meshes := []          # je Art [lod0, lod1, lod2]
var mats: Array[ShaderMaterial] = []
var cells := {}           # Vector2i -> {node, data, mmi1: [], mmi2: [], body}
var pending := {}         # Vector2i -> Task-ID
var near_mmis: Array[MultiMeshInstance3D] = []
var near_center := Vector3(INF, 0, INF)   # Gelände-Koordinaten
var grass: MultiMeshInstance3D
var grass_mat: ShaderMaterial
var af_masks: Array[ImageTexture] = []
var _results := {}
var _mutex := Mutex.new()
var _shapes := {}
var _tick := 0.0
var _lvl := -1
var _busy := true


static func set_level(l: int) -> void:
	if override_level >= 0:
		l = override_level
	if Selbsttest.requested():
		l = 0
	level = clampi(l, 0, LEVELS.size() - 1)
	var st := Engine.get_main_loop() as SceneTree
	if st != null:
		st.call_group("vegetation", "_apply_level")


func setup(t: TerrainWorld) -> void:
	tw = t


func _ready() -> void:
	name = "Vegetation"
	add_to_group("vegetation")
	var l := override_level
	if l < 0:
		l = LEVELS.find(String(GameSettings.get_value("vegetation")))
		if l < 0:
			l = 2
	if Selbsttest.requested():
		l = 0
	level = l
	gen = VegetationGen.create(tw)
	_load_meshes()
	for m in 3:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://world/vegetation/tree.gdshader")
		sm.set_shader_parameter("mode", m)
		sm.set_shader_parameter("lod_r", LOD_R)
		mats.append(sm)
	for s in VegetationGen.SPECIES.size():
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Nah_" + VegetationGen.SPECIES[s]
		mmi.material_override = mats[0]
		mmi.multimesh = _mm(meshes[s][0])
		tw.terrain_root.add_child(mmi)
		near_mmis.append(mmi)
	for i in tw.airfield_count():
		af_masks.append(ImageTexture.create_from_image(airfield_mask(tw.airfield_layout(i))))
	_apply_level()


func _exit_tree() -> void:
	for k in pending:
		if pending[k] >= 0:
			WorkerThreadPool.wait_for_task_completion(pending[k])
	pending.clear()


func _load_meshes() -> void:
	var sc: Node = (load(MODEL) as PackedScene).instantiate()
	for s in VegetationGen.SPECIES:
		var l := []
		for lod in 3:
			var mi := sc.find_child("%s_%d" % [s, lod], true, false) as MeshInstance3D
			l.append(mi.mesh if mi else BoxMesh.new())
		meshes.append(l)
	sc.free()


func _mm(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	return mm


## Stufe übernehmen: alles abbauen, Gras neu, Gelände-Shader (Waldboden-Radius).
func _apply_level() -> void:
	if _lvl == level:
		return
	_lvl = level
	for k in cells.keys():
		_free_cell(k)
	near_center = Vector3(INF, 0, INF)
	for m in near_mmis:
		m.multimesh.instance_count = 0
	var p: Array = PARAMS[level]
	mats[2].set_shader_parameter("far_r", p[0])
	tw.set_tree_radius(p[0] * 0.9)
	if grass:
		grass.queue_free()
		grass = null
	if p[1] > 0.0:
		_build_grass(p[1], p[2])


## Alle Zellen in Sichtweite um die Kamera sofort erzeugen (blockierend, parallel) – für
## Screenshots und den Spielstart.
func warm_up() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or level == 0:
		return
	var p := cam.global_position - tw.origin()
	var r: float = PARAMS[level][0]
	var n := int(ceil(gen.size / CELL))
	var k := int(ceil(r / CELL)) + 1
	var ci := int(floor((p.x + gen.half) / CELL))
	var cj := int(floor((p.z + gen.half) / CELL))
	var keys: Array[Vector2i] = []
	for j in range(maxi(cj - k, 0), mini(cj + k + 1, n)):
		for i in range(maxi(ci - k, 0), mini(ci + k + 1, n)):
			var key := Vector2i(i, j)
			if _cell_dist(key, p).x < r and not cells.has(key) and not pending.has(key):
				keys.append(key)
	var gid := WorkerThreadPool.add_group_task(func(i: int): _task(keys[i]), keys.size(), -1, true, "Vegetation")
	WorkerThreadPool.wait_for_group_task_completion(gid)
	for key in keys:
		pending[key] = -1
	_collect()
	_tick = 0.0


## Alle Zellen in Sichtweite fertig (für Screenshots/Tests).
func settled() -> bool:
	return not _busy or level == 0


func tree_radius() -> float:
	return PARAMS[level][0]


func cell_count() -> int:
	return cells.size()


func instance_count() -> int:
	var n := 0
	for k in cells:
		for c in cells[k].data.counts:
			n += c
	return n


# --- Laufzeit ----------------------------------------------------------------------------------

func _process(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or tw == null:
		return
	var o := tw.origin()
	var p := cam.global_position - o
	var gh := gen.height(p.x, p.z)
	var agl := p.y - gh
	_update_grass(p, agl, o)
	mats[1].set_shader_parameter("near_center", near_center + o)
	_tick -= dt
	if _tick > 0.0:
		return
	_tick = 0.2
	var r: float = PARAMS[level][0]
	_collect()
	if r <= 0.0:
		return
	# fehlende Zellen anstoßen (nächste zuerst), entfernte abbauen
	var n := int(ceil(gen.size / CELL))
	var ci := int(floor((p.x + gen.half) / CELL))
	var cj := int(floor((p.z + gen.half) / CELL))
	var k := int(ceil(r / CELL)) + 1
	var want := []
	for j in range(maxi(cj - k, 0), mini(cj + k + 1, n)):
		for i in range(maxi(ci - k, 0), mini(ci + k + 1, n)):
			var key := Vector2i(i, j)
			var d := _cell_dist(key, p)
			if d.x < r and not cells.has(key) and not pending.has(key):
				want.append([d.x, key])
	want.sort_custom(func(a, b): return a[0] < b[0])
	_busy = not want.is_empty() or not pending.is_empty()
	for w in want:
		if pending.size() >= MAX_TASKS:
			break
		var key: Vector2i = w[1]
		pending[key] = WorkerThreadPool.add_task(_task.bind(key), false, "Vegetation")
	for key in cells.keys():
		var d := _cell_dist(key, p)
		if d.x > r + CELL * 0.5:
			_free_cell(key)
		else:
			_update_cell(key, d, r)
	_update_near(p, agl)


func _task(key: Vector2i) -> void:
	var res := gen.build_cell(key.x, key.y)
	_mutex.lock()
	_results[key] = res
	_mutex.unlock()


func _collect() -> void:
	for key in pending.keys():
		var tid: int = pending[key]
		if tid < 0 or WorkerThreadPool.is_task_completed(tid):
			if tid >= 0:
				WorkerThreadPool.wait_for_task_completion(tid)
			pending.erase(key)
			_mutex.lock()
			var res: Dictionary = _results.get(key, {})
			_results.erase(key)
			_mutex.unlock()
			if not res.is_empty() and _lvl > 0:
				var node := Node3D.new()
				node.name = "Zelle_%d_%d" % [key.x, key.y]
				node.position = Vector3(key.x * CELL - gen.half, 0, key.y * CELL - gen.half)
				tw.terrain_root.add_child(node)
				cells[key] = {"node": node, "data": res, "mmi1": [], "mmi2": [], "body": null}


## (kleinster, größter) Abstand der Zelle zum Punkt (Gelände-Koordinaten, mit Höhe)
func _cell_dist(key: Vector2i, p: Vector3) -> Vector2:
	var x0 := key.x * CELL - gen.half
	var z0 := key.y * CELL - gen.half
	var dx := maxf(maxf(x0 - p.x, p.x - x0 - CELL), 0.0)
	var dz := maxf(maxf(z0 - p.z, p.z - z0 - CELL), 0.0)
	var fx := maxf(absf(p.x - x0), absf(p.x - x0 - CELL))
	var fz := maxf(absf(p.z - z0), absf(p.z - z0 - CELL))
	var dy := maxf(p.y - gen.height(x0 + CELL * 0.5, z0 + CELL * 0.5) - 20.0, 0.0)
	return Vector2(Vector3(dx, dy, dz).length(), Vector3(fx, dy, fz).length())


func _update_cell(key: Vector2i, d: Vector2, _r: float) -> void:
	var c: Dictionary = cells[key]
	_ensure_mmis(c, "mmi1", 1, d.x < LOD_R + 30.0)
	_ensure_mmis(c, "mmi2", 2, d.y > LOD_R - 30.0)
	var want_body := d.x < COLLIDE_R
	if want_body and c.body == null:
		c.body = _make_body(c.data.col)
		c.node.add_child(c.body)
	elif not want_body and c.body != null:
		c.body.queue_free()
		c.body = null


func _ensure_mmis(c: Dictionary, key: String, lod: int, want: bool) -> void:
	var l: Array = c[key]
	if want and l.is_empty():
		for s in VegetationGen.SPECIES.size():
			var cnt: int = c.data.counts[s]
			if cnt == 0:
				continue
			var mm := _mm(meshes[s][lod])
			mm.instance_count = cnt
			mm.buffer = c.data.bufs[s]
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = mats[lod]
			if lod == 2 or s == VegetationGen.BUSCH:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			c.node.add_child(mmi)
			l.append(mmi)
	elif not want and not l.is_empty():
		for m in l:
			m.queue_free()
		l.clear()


func _make_body(col: PackedFloat32Array) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = "Baeume"
	b.collision_layer = Layers.WORLD
	b.collision_mask = 0
	for i in range(0, col.size(), 4):
		var h := snappedf(col[i + 3] * 0.9, 2.0)
		if not _shapes.has(h):
			var cs := CylinderShape3D.new()
			cs.radius = TREE_RADIUS
			cs.height = h
			_shapes[h] = cs
		var ow := b.create_shape_owner(b)
		b.shape_owner_add_shape(ow, _shapes[h])
		b.shape_owner_set_transform(ow, Transform3D(Basis(), Vector3(col[i], col[i + 1] + h * 0.5 - 0.3, col[i + 2])))
	return b


func _free_cell(key: Vector2i) -> void:
	var c: Dictionary = cells[key]
	c.node.queue_free()
	cells.erase(key)


## Nah-Instanzen (LOD0) um den Bezugspunkt neu auswählen.
func _update_near(p: Vector3, agl: float) -> void:
	if agl > NEAR_MAX_AGL or level == 0:
		if near_center.x != INF:
			near_center = Vector3(INF, 0, INF)
			mats[1].set_shader_parameter("near_r", 0.0)
			for m in near_mmis:
				m.multimesh.instance_count = 0
		return
	if Vector2(p.x - near_center.x, p.z - near_center.z).length() < NEAR_MOVE:
		return
	near_center = Vector3(p.x, 0, p.z)
	var arrs := []
	for s in VegetationGen.SPECIES.size():
		arrs.append(PackedFloat32Array())
	var r2 := NEAR_R * NEAR_R
	for key in cells:
		var d := _cell_dist(key, Vector3(p.x, -1.0e6, p.z))
		if d.x > NEAR_R:
			continue
		var x0: float = key.x * CELL - gen.half
		var z0: float = key.y * CELL - gen.half
		var data: Dictionary = cells[key].data
		for s in VegetationGen.SPECIES.size():
			var b: PackedFloat32Array = data.bufs[s]
			var out: PackedFloat32Array = arrs[s]
			for i in range(0, b.size(), VegetationGen.FLOATS):
				var dx: float = b[i + 3] + x0 - p.x
				var dz: float = b[i + 11] + z0 - p.z
				if dx * dx + dz * dz < r2:
					var inst := b.slice(i, i + VegetationGen.FLOATS)
					inst[3] += x0
					inst[11] += z0
					out.append_array(inst)
			arrs[s] = out
	for s in VegetationGen.SPECIES.size():
		var a: PackedFloat32Array = arrs[s]
		var mm := near_mmis[s].multimesh
		mm.instance_count = a.size() / VegetationGen.FLOATS
		if mm.instance_count > 0:
			mm.buffer = a
		if s == VegetationGen.BUSCH:
			near_mmis[s].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mats[1].set_shader_parameter("near_r", NEAR_R)


# --- Gras --------------------------------------------------------------------------------------

func _build_grass(radius: float, grid: float) -> void:
	var n := int(radius * 2.0 / grid)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _clump_mesh()
	mm.instance_count = n * n
	var buf := PackedFloat32Array()
	buf.resize(n * n * 12)
	var k := 0
	for j in n:
		for i in n:
			buf[k] = 1.0
			buf[k + 3] = (i - n * 0.5) * grid
			buf[k + 5] = 1.0
			buf[k + 10] = 1.0
			buf[k + 11] = (j - n * 0.5) * grid
			k += 12
	mm.buffer = buf
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = load("res://world/vegetation/grass.gdshader")
	var tex: Array = tw.terrain_textures()
	grass_mat.set_shader_parameter("heightmap", tex[0])
	grass_mat.set_shader_parameter("mask_tex", tex[1])
	grass_mat.set_shader_parameter("noise_tex", tex[2])
	grass_mat.set_shader_parameter("warp_lo", tex[6])
	grass_mat.set_shader_parameter("warp_mid", tex[7])
	grass_mat.set_shader_parameter("spacing", tw.data.spacing())
	grass_mat.set_shader_parameter("half_size", gen.half)
	grass_mat.set_shader_parameter("samples", tw.data.samples)
	grass_mat.set_shader_parameter("grid", grid)
	grass_mat.set_shader_parameter("radius", radius)
	grass_mat.set_shader_parameter("af_half", AF_HALF)
	grass = MultiMeshInstance3D.new()
	grass.name = "Gras"
	grass.multimesh = mm
	grass.material_override = grass_mat
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.custom_aabb = AABB(Vector3(-radius - 2.0, -200.0, -radius - 2.0), Vector3(radius * 2.0 + 4.0, 1400.0, radius * 2.0 + 4.0))
	tw.terrain_root.add_child(grass)


func _update_grass(p: Vector3, agl: float, o: Vector3) -> void:
	if grass == null:
		return
	var radius: float = PARAMS[level][1]
	var grid: float = PARAMS[level][2]
	grass.visible = agl < radius + 40.0
	if not grass.visible:
		return
	grass.position = Vector3(snappedf(p.x, grid), 0, snappedf(p.z, grid))
	grass_mat.set_shader_parameter("terrain_origin", o)
	# nächster Platz für die Platzmaske
	var best := -1
	var bd := INF
	for i in tw.airfield_count():
		var c: Vector3 = tw.airfield(i).center
		var d := Vector2(c.x - p.x, c.z - p.z).length()
		if d < bd:
			bd = d
			best = i
	if best >= 0:
		grass_mat.set_shader_parameter("af_mask", af_masks[best])
		grass_mat.set_shader_parameter("af_center", tw.airfield(best).center + o)


## Büschel aus 8 Halmen (je 3 Segmente, Spitze), UV.y = Höhe 0..1, Höhe 1 m (Shader skaliert).
static func _clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for b in 8:
		var a := rng.randf() * TAU
		var off := Vector3(rng.randf_range(-0.22, 0.22), 0, rng.randf_range(-0.22, 0.22))
		var side := Vector3(cos(a), 0, sin(a))
		var fwd := Vector3(-side.z, 0, side.x)
		var bend := rng.randf_range(0.1, 0.3)
		var hgt := rng.randf_range(0.7, 1.0)
		var w := 0.045
		var rows := []
		for k in 4:
			var t := k / 3.0
			var c := off + Vector3(0, t * hgt, 0) + fwd * bend * t * t
			var ww := w * (1.0 - t * 0.85)
			rows.append([c - side * ww, c + side * ww, t])
		var nrm := fwd
		for k in 3:
			var r0: Array = rows[k]
			var r1: Array = rows[k + 1]
			var quad := [[r0[0], r0[2]], [r0[1], r0[2]], [r1[1], r1[2]], [r0[0], r0[2]], [r1[1], r1[2]], [r1[0], r1[2]]]
			if k == 2:   # Spitze als Dreieck
				var tip: Vector3 = (r1[0] + r1[1]) * 0.5
				quad = [[r0[0], r0[2]], [r0[1], r0[2]], [tip, 1.0]]
			for q in quad:
				st.set_normal(nrm)
				st.set_uv(Vector2(0.5, q[1]))
				st.add_vertex(q[0])
	return st.commit()


# --- Platzmaske --------------------------------------------------------------------------------

## Halbgröße der Platzmaske (x, z) in m, Auflösung 1 m.
const AF_HALF := Vector2(200.0, 820.0)


## Platzmaske (RG8, 400 × 1640 px, lokal zur Pistenmitte): R = Grashöhe (1 = Wiese),
## G = Abnutzung. Piste kurz, Aufsetzzonen und Mittelbahn platt gefahren, Rollwege,
## Abstellplätze, Gebäude und Fahrwege der Fahrzeuge (Halle, Lager, Bunker, Plätze) grasfrei
## bzw. fast. Kanten weich (verkleinert und wieder vergrößert).
static func airfield_mask(l: AirfieldLayout) -> Image:
	var w := int(AF_HALF.x * 2.0)
	var h := int(AF_HALF.y * 2.0)
	var img := Image.create(w, h, false, Image.FORMAT_RG8)
	img.fill(Color(1, 0, 0))
	var rw := l.runway_width
	var s0 := l.runway_start.z
	var s1 := l.runway_end.z
	# Piste: kurz gemäht, leicht abgenutzt
	_rect(img, 0, (s0 + s1) * 0.5, rw * 0.5, (s0 - s1) * 0.5 + 20.0, 0.38, 0.12)
	# Mittelbahn (Startlauf) und Aufsetzzonen: platt gefahrene Bahnen, Rand weicher
	_rect(img, 0, (s0 + s1) * 0.5, 9.0, (s0 - s1) * 0.5 - 40.0, 0.3, 0.45)
	for zone in [[s0 - 30.0, s0 - 340.0], [s1 + 30.0, s1 + 340.0]]:
		var zc: float = (zone[0] + zone[1]) * 0.5
		var hz: float = absf(zone[0] - zone[1]) * 0.5
		_rect(img, 0, zc, 13.0, hz + 20.0, 0.28, 0.55)
		_rect(img, 0, zc, 8.0, hz, 0.16, 0.85)
		for sx in [-1.0, 1.0]:
			_rect(img, sx * 1.9, zc, 1.3, hz - 30.0, 0.06, 1.0)   # Radspuren
	# Rollwege (12 m, fast grasfrei, Mitte ohne)
	for k in range(0, l.taxi_edges.size() - 1, 2):
		_line(img, l.taxi_nodes[l.taxi_edges[k]], l.taxi_nodes[l.taxi_edges[k + 1]], 7.5, 0.18, 0.9)
		_line(img, l.taxi_nodes[l.taxi_edges[k]], l.taxi_nodes[l.taxi_edges[k + 1]], 4.0, 0.0, 1.0)
	# Fahrwege der Fahrzeuge: Abstellplätze, Halle, Lager, Bunker, Fahrzeug-Plätze
	var hubs := [l.fuel_depot, l.ammo_bunker, l.hangar, l.crew_spawn]
	for v in l.vehicle_spawns:
		hubs.append(v)
	for i in hubs.size():
		for j in range(i + 1, hubs.size()):
			_line(img, hubs[i], hubs[j], 4.0, 0.12, 0.8)
	for pp in l.parking_positions:
		_line(img, l.crew_spawn, pp, 4.0, 0.12, 0.8)
		_line(img, l.fuel_depot, pp, 4.0, 0.12, 0.8)
		_rect(img, pp.x, pp.z, 14.0, 16.0, 0.0, 1.0)   # Abstellplatz
	# Gebäude und Lager (mit Vorplatz)
	for k in 3:
		_rect(img, l.hangar.x, l.hangar.z - 48.0 * k, 24.0, 22.0, 0.0, 1.0)
	_rect(img, l.fuel_depot.x, l.fuel_depot.z, 22.0, 22.0, 0.0, 1.0)
	_rect(img, l.ammo_bunker.x, l.ammo_bunker.z, 18.0, 18.0, 0.0, 1.0)
	for b in AirfieldDressing.building_positions(l):
		_rect(img, b.x, b.z, 12.0, 10.0, 0.0, 1.0)
	for v in l.vehicle_spawns:
		_rect(img, v.x, v.z, 8.0, 8.0, 0.0, 1.0)
	# weiche Kanten
	img.resize(w / 3, h / 3, Image.INTERPOLATE_BILINEAR)
	img.resize(w, h, Image.INTERPOLATE_CUBIC)
	return img


static func _rect(img: Image, cx: float, cz: float, hx: float, hz: float, r: float, g: float) -> void:
	var x0 := int(cx - hx + AF_HALF.x)
	var z0 := int(cz - hz + AF_HALF.y)
	var rc := Rect2i(x0, z0, int(hx * 2.0), int(hz * 2.0)).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if rc.size.x > 0 and rc.size.y > 0:
		img.fill_rect(rc, Color(r, g, 0))


static func _line(img: Image, a: Vector3, b: Vector3, hw: float, r: float, g: float) -> void:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var n := maxi(int(d.length()), 1)
	for i in n + 1:
		var p := Vector2(a.x, a.z) + d * (float(i) / n)
		_rect(img, p.x, p.y, hw, hw, r, g)
