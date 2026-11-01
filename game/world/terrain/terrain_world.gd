class_name TerrainWorld
extends Node3D
## Höhenkarten-Gelände 40 × 40 km (Paket 12). Szene: world/terrain/terrain_world.tscn,
## geht aber auch mit TerrainWorld.new(). Schnittstelle wie TestWorld: runway_spawn(index),
## RUNWAY_DIR, dazu height_at(x, z), runway_start(), airfield_count(), targets().
## Meldet sich bei WorldGround als Höhen-Provider an (Geschosse, KI-Bodenschutz).
##
## Aufbau: 16 × 16 Kacheln à 2,5 km, je StaticBody3D (Layers.WORLD) mit HeightMapShape3D
## (129² Punkte, ~19,5 m) und drei Mesh-LODs (Schritt 1/4/16) mit Sichtweiten-Umschaltung.
## Alle Kacheln hängen unter dem Knoten "Terrain"; dessen globale Lage ist der Bezug für
## height_at (so bleibt height_at bei Floating-Origin-Verschiebungen richtig).
##
## height_at() rechnet mit derselben Dreiecksteilung wie die Physik (Jolt-Höhenfeld):
## je Zelle zwei Dreiecke mit der Diagonale (i+1, j)–(i, j+1). Auf den Gitterlinien ist das
## gleich der bilinearen Interpolation, innerhalb der Zelle weicht die Bilineare um wenige
## Zentimeter ab; gemessen gegen Raycasts < 1 mm (Test world/test_terrain).

const RUNWAY_DIR := Vector3(0, 0, -1)
const DATA_PATH := "res://world/terrain/data/terrain_main.res"
const RUNWAY_LENGTH := 900.0
const RUNWAY_WIDTH := 40.0
## Sichtweite: Ende des fernsten LODs; Nebel ist darauf abgestimmt.
const VIEW_DISTANCE := 19000.0
const LOD_STEPS := [1, 4, 16]
const LOD_RANGES := [[0.0, 3200.0], [3200.0, 9000.0], [9000.0, VIEW_DISTANCE]]

@export var data_path := DATA_PATH
## Optik bauen (Meshes, Himmel, Platz-Ausstattung). Headless standardmäßig aus.
@export var build_visuals := true
## Standard-Flugplatz für runway_spawn().
@export var default_airfield := 0

var data: TerrainData
var terrain_root: Node3D
var sun: DirectionalLight3D
var heights := PackedFloat32Array()

var _n := 0
var _sp := 1.0
var _inv_sp := 1.0
var _half := 0.0

static var _cache := {}   # Pfad -> {data, heights, shapes, tex}


func _init() -> void:
	if DisplayServer.get_name() == "headless":
		build_visuals = false


func _enter_tree() -> void:
	WorldGround.set_provider(self)
	if data == null:
		_load()


func _exit_tree() -> void:
	WorldGround.clear_provider(self)


func _ready() -> void:
	_build_tiles()
	_build_airfields()
	_build_targets()
	if build_visuals:
		_build_environment()


# --- Daten ------------------------------------------------------------------------

func _load() -> void:
	var c: Dictionary = _cache.get(data_path, {})
	if c.is_empty():
		var td: TerrainData = load(data_path)
		c = {"data": td, "heights": td.decode_heights(), "shapes": [], "tex": null}
		_cache[data_path] = c
	data = c.data
	heights = c.heights
	_n = data.samples
	_sp = data.spacing()
	_inv_sp = 1.0 / _sp
	_half = data.size_m * 0.5


func _cells() -> int:
	return (_n - 1) / data.tiles


func _tile_shape(tx: int, tz: int) -> HeightMapShape3D:
	var c: Dictionary = _cache[data_path]
	var shapes: Array = c.shapes
	if shapes.is_empty():
		shapes.resize(data.tiles * data.tiles)
	var k := tz * data.tiles + tx
	if shapes[k] == null:
		var cells := _cells()
		var w := cells + 1
		var md := PackedFloat32Array()
		for j in w:
			var row := (tz * cells + j) * _n + tx * cells
			md.append_array(heights.slice(row, row + w))
		var s := HeightMapShape3D.new()
		s.map_width = w
		s.map_depth = w
		s.map_data = md
		shapes[k] = s
	return shapes[k]


# --- Abfragen ---------------------------------------------------------------------

## Bezug der Gelände-Koordinaten in der Szene (verschiebt sich mit Floating Origin).
func origin() -> Vector3:
	return terrain_root.global_position if terrain_root and terrain_root.is_inside_tree() else Vector3.ZERO


## Bodenhöhe an Szenen-Koordinaten (x, z), identisch zum Physik-Höhenfeld.
func height_at(x: float, z: float) -> float:
	var o := origin()
	return height_at_terrain(x - o.x, z - o.z) + o.y


## Bodenhöhe in Gelände-Koordinaten (absolut, Kartenmitte = 0).
func height_at_terrain(x: float, z: float) -> float:
	var fx := clampf((x + _half) * _inv_sp, 0.0, _n - 1.0)
	var fz := clampf((z + _half) * _inv_sp, 0.0, _n - 1.0)
	var i := mini(int(fx), _n - 2)
	var j := mini(int(fz), _n - 2)
	var u := fx - i
	var v := fz - j
	var k := j * _n + i
	var h10 := heights[k + 1]
	var h01 := heights[k + _n]
	if u + v <= 1.0:
		var h00 := heights[k]
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	var h11 := heights[k + _n + 1]
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)


## Bilineare Höhe (glatt, z. B. für Kamera/Optik). Weicht innerhalb einer Zelle um
## wenige Zentimeter von height_at ab.
func height_at_bilinear(x: float, z: float) -> float:
	var o := origin()
	var fx := clampf((x - o.x + _half) * _inv_sp, 0.0, _n - 1.0)
	var fz := clampf((z - o.z + _half) * _inv_sp, 0.0, _n - 1.0)
	var i := mini(int(fx), _n - 2)
	var j := mini(int(fz), _n - 2)
	var u := fx - i
	var v := fz - j
	var k := j * _n + i
	var a := lerpf(heights[k], heights[k + 1], u)
	var b := lerpf(heights[k + _n], heights[k + _n + 1], u)
	return lerpf(a, b, v) + o.y


func normal_at(x: float, z: float) -> Vector3:
	var d := _sp
	return Vector3(height_at(x - d, z) - height_at(x + d, z), 2.0 * d, height_at(x, z - d) - height_at(x, z + d)).normalized()


func airfield_count() -> int:
	return data.airfields.size()


## Flugplatz-Daten {name, center (Gelände-Koord.), length, width, nation}.
func airfield(i: int) -> Dictionary:
	return data.airfields[i]


## Südliche Pistenschwelle in Szenen-Koordinaten (gestartet wird Richtung -Z).
func runway_start(airfield_index: int = -1) -> Vector3:
	if airfield_index < 0:
		airfield_index = default_airfield
	var c: Vector3 = data.airfields[airfield_index].center
	var p := c + Vector3(0, 0, RUNWAY_LENGTH * 0.5 - 20.0) + origin()
	p.y = height_at(p.x, p.z)
	return p


## Startpunkt auf der Piste (Index für Versatz), wie TestWorld.runway_spawn.
func runway_spawn(index: int = 0, airfield_index: int = -1) -> Vector3:
	var p := runway_start(airfield_index) + RUNWAY_DIR * (10.0 + index * 40.0) + Vector3(index * 12.0, 0, 0)
	p.y = height_at(p.x, p.z)
	return p


## Ziel-Marker (Daten aus der Ressource, Positionen in Gelände-Koordinaten).
func targets(type: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in data.targets:
		if type == "" or t.type == type:
			out.append(t)
	return out


func to_scene(terrain_pos: Vector3) -> Vector3:
	return terrain_pos + origin()


# --- Aufbau -----------------------------------------------------------------------

func _build_tiles() -> void:
	terrain_root = Node3D.new()
	terrain_root.name = "Terrain"
	add_child(terrain_root)
	var cells := _cells()
	var tile_m := cells * _sp
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	var mat: ShaderMaterial = _material() if build_visuals else null
	var meshes := []
	if build_visuals:
		for s in LOD_STEPS:
			meshes.append(_lod_mesh(cells, s))
	for tz in data.tiles:
		for tx in data.tiles:
			var body := StaticBody3D.new()
			body.name = "Tile_%d_%d" % [tx, tz]
			body.collision_layer = Layers.WORLD
			body.collision_mask = 0
			body.physics_material_override = pm
			body.position = Vector3(-_half + (tx + 0.5) * tile_m, 0, -_half + (tz + 0.5) * tile_m)
			var cs := CollisionShape3D.new()
			cs.shape = _tile_shape(tx, tz)
			cs.scale = Vector3(_sp, 1.0, _sp)
			body.add_child(cs)
			if build_visuals:
				var k := (tz * data.tiles + tx) * 2
				var mn := data.tile_minmax[k] - 45.0
				var mx := data.tile_minmax[k + 1] + 1.0
				var aabb := AABB(Vector3(-tile_m * 0.5, mn, -tile_m * 0.5), Vector3(tile_m, mx - mn, tile_m))
				for l in LOD_STEPS.size():
					var mi := MeshInstance3D.new()
					mi.name = "LOD%d" % l
					mi.mesh = meshes[l]
					mi.material_override = mat
					mi.custom_aabb = aabb
					mi.visibility_range_begin = LOD_RANGES[l][0]
					mi.visibility_range_end = LOD_RANGES[l][1]
					mi.visibility_range_begin_margin = 150.0 if l > 0 else 0.0
					mi.visibility_range_end_margin = 150.0 if l < LOD_STEPS.size() - 1 else 0.0
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if l > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					mi.set_instance_shader_parameter("tile_idx", Vector2(tx, tz))
					mi.set_instance_shader_parameter("lod_step", float(LOD_STEPS[l]))
					body.add_child(mi)
			terrain_root.add_child(body)


## Gitter-Mesh einer Kachel: VERTEX.xz = Gitterindex (0..cells), VERTEX.y = 1 für Schürze.
## Dreiecksteilung wie das Physik-Höhenfeld (Diagonale (i+1, j)–(i, j+1)).
static func _lod_mesh(cells: int, step: int) -> ArrayMesh:
	var n := cells / step
	var w := n + 1
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for j in w:
		for i in w:
			verts.append(Vector3(i * step, 0, j * step))
	for j in n:
		for i in n:
			var a := j * w + i
			var b := a + 1
			var c := a + w
			var d := c + 1
			# Dreiecke (a, b, c) und (b, d, c), Diagonale b–c wie Jolt
			idx.append_array([a, b, c, b, d, c])
	# Schürzen an den vier Rändern gegen Risse zwischen LODs
	var edges := [[], [], [], []]
	for k in w:
		edges[0].append(k)                  # z = 0
		edges[1].append((w - 1) * w + k)    # z = max
		edges[2].append(k * w)              # x = 0
		edges[3].append(k * w + w - 1)      # x = max
	for e in 4:
		var base := verts.size()
		for k in w:
			var v := verts[edges[e][k]]
			verts.append(Vector3(v.x, 1.0, v.z))
		for k in n:
			var t0: int = edges[e][k]
			var t1: int = edges[e][k + 1]
			var b0 := base + k
			var b1 := base + k + 1
			# beidseitig, damit die Orientierung egal ist
			idx.append_array([t0, t1, b1, t0, b1, b0, t0, b1, t1, t0, b0, b1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = idx
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _material() -> ShaderMaterial:
	var c: Dictionary = _cache[data_path]
	if c.tex == null:
		var himg := Image.create_from_data(_n, _n, false, Image.FORMAT_RF, heights.to_byte_array())
		var mimg := data.decode_mask()
		mimg.generate_mipmaps()
		var nn := FastNoiseLite.new()
		nn.seed = data.seed
		nn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nn.frequency = 4.0 / 512.0
		nn.fractal_octaves = 4
		var nimg := nn.get_seamless_image(512, 512)
		nimg.convert(Image.FORMAT_L8)
		nimg.generate_mipmaps()
		c.tex = [ImageTexture.create_from_image(himg), ImageTexture.create_from_image(mimg), ImageTexture.create_from_image(nimg)]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/terrain/terrain.gdshader")
	mat.set_shader_parameter("heightmap", c.tex[0])
	mat.set_shader_parameter("mask_tex", c.tex[1])
	mat.set_shader_parameter("noise_tex", c.tex[2])
	mat.set_shader_parameter("spacing", _sp)
	mat.set_shader_parameter("half_size", _half)
	mat.set_shader_parameter("samples", _n)
	mat.set_shader_parameter("tile_cells", _cells())
	return mat


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.24, 0.42, 0.72)
	sky_mat.sky_horizon_color = Color(0.68, 0.75, 0.82)
	sky_mat.ground_bottom_color = Color(0.3, 0.33, 0.3)
	sky_mat.ground_horizon_color = Color(0.68, 0.75, 0.82)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.75, 0.83)
	env.fog_density = 0.00011
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 800.0
	add_child(sun)


## Pisten, Markierungen, Hallen, Windsack (Hallen/Turm mit Kollision, Layers.WORLD).
func _build_airfields() -> void:
	for ai in data.airfields.size():
		var af: Dictionary = data.airfields[ai]
		var node := Node3D.new()
		node.name = "Airfield%d" % ai
		node.position = af.center
		terrain_root.add_child(node)
		var start := Vector3(0, 0, RUNWAY_LENGTH * 0.5 - 20.0)
		var mat_hangar := _mat(Color(0.55, 0.52, 0.45))
		var mat_roof := _mat(Color(0.33, 0.29, 0.27))
		for i in 3:
			_static_box(node, start + Vector3(-80, 0, -120 - i * 48), Vector3(24, 8, 30), mat_hangar)
			_static_box(node, start + Vector3(-80, 8, -120 - i * 48), Vector3(25, 1, 31), mat_roof)
		_static_box(node, start + Vector3(-70, 0, 30), Vector3(6, 14, 6), mat_hangar)
		if not build_visuals:
			continue
		var strip := MeshInstance3D.new()
		strip.name = "Runway"
		var pmesh := PlaneMesh.new()
		pmesh.size = Vector2(RUNWAY_WIDTH, RUNWAY_LENGTH)
		strip.mesh = pmesh
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.36, 0.45, 0.2)
		smat.roughness = 1.0
		strip.material_override = smat
		strip.position = Vector3(0, 0.06, 0)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(strip)
		var white := _mat(Color(0.95, 0.95, 0.92))
		var red := _mat(Color(0.85, 0.2, 0.15))
		var marker := BoxMesh.new()
		marker.size = Vector3(1.6, 0.35, 0.6)
		var cnt := int(RUNWAY_LENGTH / 50.0)
		for i in cnt + 1:
			for sx in [-1.0, 1.0]:
				var m := MeshInstance3D.new()
				m.mesh = marker
				m.material_override = red if i == 0 or i == cnt else white
				m.position = start + RUNWAY_DIR * (i * 50.0) + Vector3(sx * (RUNWAY_WIDTH * 0.5 + 1.0), 0.17, 0)
				node.add_child(m)
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.08
		cm.bottom_radius = 0.1
		cm.height = 6.0
		pole.mesh = cm
		pole.material_override = white
		pole.position = start + Vector3(-34, 3, -60)
		node.add_child(pole)
		var sock := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.15
		sm.bottom_radius = 0.4
		sm.height = 2.2
		sock.mesh = sm
		sock.material_override = _mat(Color(1.0, 0.5, 0.1))
		sock.position = pole.position + Vector3(0.0, 2.6, 1.1)
		sock.rotation_degrees = Vector3(90, 0, 0)
		node.add_child(sock)


## Ziel-Marker als Marker3D (Gruppe "terrain_targets", Metadaten type/name/radius/nation).
func _build_targets() -> void:
	var root := Node3D.new()
	root.name = "Targets"
	terrain_root.add_child(root)
	for t in data.targets:
		var m := Marker3D.new()
		m.name = String(t.name).validate_node_name()
		m.position = t.pos
		for key in ["type", "name", "radius", "nation"]:
			m.set_meta(key, t[key])
		m.add_to_group("terrain_targets")
		root.add_child(m)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _static_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = Layers.WORLD
	b.collision_mask = 0
	b.position = pos + Vector3.UP * size.y * 0.5
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	if build_visuals:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		b.add_child(mi)
	parent.add_child(b)
