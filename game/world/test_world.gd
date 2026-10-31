class_name TestWorld
extends Node3D
## Test-Gelände: große Ebene, Graspiste, Himmel, Sonne, Orientierungspunkte.
## Komplett im Code aufgebaut. Piste verläuft entlang -Z, Startpunkt bei RUNWAY_START.

const GROUND_SIZE := 24000.0
const RUNWAY_LENGTH := 900.0
const RUNWAY_WIDTH := 40.0
const RUNWAY_START := Vector3(0, 0, 400)    # Schwelle Süd, gestartet wird Richtung -Z
const RUNWAY_DIR := Vector3(0, 0, -1)

var sun: DirectionalLight3D


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_runway()
	_build_landmarks()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.75)
	sky_mat.sky_horizon_color = Color(0.66, 0.76, 0.86)
	sky_mat.ground_bottom_color = Color(0.25, 0.3, 0.22)
	sky_mat.ground_horizon_color = Color(0.6, 0.68, 0.7)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.76, 0.86)
	env.fog_density = 0.00006
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	add_child(sun)


static func _noise_texture(freq: float, c1: Color, c2: Color) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = n
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	tex.color_ramp = g
	return tex


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.8
	body.physics_material_override = pm
	add_child(body)

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _noise_texture(0.012, Color(0.16, 0.26, 0.09), Color(0.27, 0.36, 0.14))
	mat.uv1_scale = Vector3(GROUND_SIZE / 60.0, GROUND_SIZE / 60.0, 1)
	mat.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	# Großes Feldmuster (Äcker) für Geschwindigkeitsgefühl in der Höhe
	var fields := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	fields.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_texture = _noise_texture(0.05, Color(0.4, 0.33, 0.18, 0.0), Color(0.45, 0.38, 0.2, 0.6))
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	fmat.uv1_scale = Vector3(6, 6, 1)
	fmat.roughness = 1.0
	fields.material_override = fmat
	fields.position.y = 0.03
	fields.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(fields)


func _build_runway() -> void:
	var center := RUNWAY_START + RUNWAY_DIR * (RUNWAY_LENGTH * 0.5 - 20.0)
	var strip := MeshInstance3D.new()
	strip.name = "Runway"
	var pm := PlaneMesh.new()
	pm.size = Vector2(RUNWAY_WIDTH, RUNWAY_LENGTH)
	strip.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _noise_texture(0.08, Color(0.3, 0.4, 0.15), Color(0.38, 0.47, 0.2))
	mat.uv1_scale = Vector3(2, 40, 1)
	strip.material_override = mat
	strip.position = center + Vector3.UP * 0.05
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)
	# Pistenmarker: weiße Blöcke an den Rändern alle 50 m
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.92)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.2, 0.15)
	var marker := BoxMesh.new()
	marker.size = Vector3(1.6, 0.35, 0.6)
	var n := int(RUNWAY_LENGTH / 50.0)
	for i in n + 1:
		for sx in [-1.0, 1.0]:
			var m := MeshInstance3D.new()
			m.mesh = marker
			m.material_override = red if i == 0 or i == n else white
			m.position = RUNWAY_START + RUNWAY_DIR * (i * 50.0 - 20.0) + Vector3(sx * (RUNWAY_WIDTH * 0.5 + 1.0), 0.17, 0)
			add_child(m)
	# Windsack-Mast
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08; cm.bottom_radius = 0.1; cm.height = 6.0
	pole.mesh = cm
	pole.material_override = white
	pole.position = RUNWAY_START + Vector3(-32, 3, -60)
	add_child(pole)
	var sock := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.15; sm.bottom_radius = 0.4; sm.height = 2.2
	sock.mesh = sm
	var om := StandardMaterial3D.new()
	om.albedo_color = Color(1.0, 0.5, 0.1)
	sock.material_override = om
	sock.position = pole.position + Vector3(0.0, 2.6, 1.1)
	sock.rotation_degrees = Vector3(90, 0, 0)
	add_child(sock)


func _static_box(pos: Vector3, size: Vector3, mat: Material, rot_y := 0.0) -> void:
	var b := StaticBody3D.new()
	b.position = pos + Vector3.UP * size.y * 0.5
	b.rotation.y = rot_y
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	b.add_child(mi)
	add_child(b)


func _build_landmarks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1915
	# Hangar-Blöcke neben der Piste
	var hangar_mat := StandardMaterial3D.new()
	hangar_mat.albedo_color = Color(0.55, 0.52, 0.45)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.35, 0.3, 0.28)
	for i in 3:
		_static_box(RUNWAY_START + Vector3(-60, 0, -80 - i * 45), Vector3(22, 8, 30), hangar_mat)
		_static_box(RUNWAY_START + Vector3(-60, 8, -80 - i * 45), Vector3(23, 1, 31), roof_mat)
	_static_box(RUNWAY_START + Vector3(-50, 0, 40), Vector3(6, 14, 6), hangar_mat)  # Turm

	# Bäume (MultiMesh, nur optisch) in Gruppen
	var tree_mesh := CylinderMesh.new()
	tree_mesh.top_radius = 0.0
	tree_mesh.bottom_radius = 3.0
	tree_mesh.height = 11.0
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.13, 0.3, 0.12)
	tree_mesh.material = tm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tree_mesh
	var xforms: Array[Transform3D] = []
	for g in 70:
		var c := Vector3(rng.randf_range(-6000, 6000), 0, rng.randf_range(-6000, 6000))
		if absf(c.x) < 120 and c.z > -700 and c.z < 600:
			continue
		for k in rng.randi_range(8, 30):
			var p := c + Vector3(rng.randf_range(-120, 120), 0, rng.randf_range(-120, 120))
			var s := rng.randf_range(0.7, 1.5)
			xforms.append(Transform3D(Basis.from_scale(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), p + Vector3.UP * 5.5 * s))
	# Baumreihe entlang der Piste (gut für Geschwindigkeitsgefühl beim Rollen)
	for i in 30:
		xforms.append(Transform3D(Basis.IDENTITY, RUNWAY_START + Vector3(70, 5.5, 60 - i * 35)))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Trees"
	mmi.multimesh = mm
	add_child(mmi)

	# Hügel (mit Kollision)
	var hill_mat := StandardMaterial3D.new()
	hill_mat.albedo_color = Color(0.2, 0.28, 0.12)
	for i in 14:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(2500, 8000)
		var r := rng.randf_range(250, 700)
		var h := rng.randf_range(80, 320)
		var hm := CylinderMesh.new()
		hm.top_radius = r * 0.15
		hm.bottom_radius = r
		hm.height = h
		hm.radial_segments = 20
		hm.material = hill_mat
		var b := StaticBody3D.new()
		b.position = Vector3(cos(ang) * dist, h * 0.5, sin(ang) * dist)
		var mi := MeshInstance3D.new()
		mi.mesh = hm
		b.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.shape = hm.create_convex_shape()
		b.add_child(cs)
		add_child(b)

	# Pylone als Rundkurs-Markierung (rot-weiß, 40 m hoch)
	for i in 6:
		var ang := i * TAU / 6.0
		var p := Vector3(cos(ang) * 1500, 0, sin(ang) * 1500 - 200)
		_static_box(p, Vector3(4, 40, 4), hangar_mat if i % 2 == 0 else roof_mat)


## Startpunkt-Transform für ein Flugzeug auf der Piste (Index für Versatz).
func runway_spawn(index: int = 0) -> Vector3:
	return RUNWAY_START + RUNWAY_DIR * (10.0 + index * 40.0) + Vector3(index * 12.0, 0, 0)
