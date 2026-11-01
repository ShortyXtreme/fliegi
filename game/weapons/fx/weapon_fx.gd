class_name WeaponFx
extends Node3D
## Wurzel aller Waffen-Effekte (Agent E, Paket 10):
##  - Leuchtspuren: eine MultiMeshInstance3D für alle Spurgeschosse (keine Node je Geschoss),
##    liest ProjectileSystem.current über die Lese-Schnittstelle (tracer_slots, position …).
##  - Mündungsfeuer: Pool aus höchstens 8 OmniLights + Blitz-Billboards (MultiMesh).
##  - Einschläge: Pools aus GPUParticles3D, Funken am Flugzeug, Staub am Boden.
## Hört nur auf CombatEvents.shot_fired und ProjectileSystem.impact; ändert nie Spielzustand.
## Headless (Server/Tests) bleibt alles aus; build() baut die Knoten auch dort (Tests).

const TRACER_SHADER := preload("res://weapons/fx/tracer.gdshader")
const MAX_TRACERS := 1024
const MAX_LIGHTS := 8
const SPARK_POOL := 16
const DUST_POOL := 16
const FLASH_TIME := 0.06
const FLASH_MAX_DIST := 1500.0
const TRACER_COLOR := Color(1.0, 0.62, 0.25)

var enabled := true
## Optional fest vorgeben (Tests); sonst ProjectileSystem.current.
var projectiles: ProjectileSystem
var tracers: MultiMeshInstance3D
var lights: Array[OmniLight3D] = []
var sparks: Array[GPUParticles3D] = []
var dust: Array[GPUParticles3D] = []
## Statistik für Tests/Debug.
var tracer_count := 0
var flashes_started := 0
var impacts_started := 0

var _built := false
var _flash_mm: MultiMeshInstance3D
var _light_t := PackedFloat32Array()
var _light_src: Array = []        # [shooter, lokale Position]
var _light_next := 0
var _spark_next := 0
var _dust_next := 0
var _spark_follow: Array = []     # [Ziel, lokaler Punkt, Restzeit] je Funken-Emitter
var _bus: CombatEvents
var _ps_connected: ProjectileSystem


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	set_process(enabled)
	if enabled:
		build()


## Baut alle Effekt-Knoten (einmalig). Headless nur für Tests aufrufen.
func build() -> void:
	if _built:
		return
	_built = true
	_build_tracers()
	_build_flashes()
	for i in SPARK_POOL:
		sparks.append(_make_emitter(true))
		_spark_follow.append([null, Vector3.ZERO, 0.0])
	for i in DUST_POOL:
		dust.append(_make_emitter(false))


func _ps() -> ProjectileSystem:
	if projectiles != null and is_instance_valid(projectiles):
		return projectiles
	return ProjectileSystem.current


func _process(dt: float) -> void:
	if not _built:
		return
	_connect_sources()
	update_tracers()
	_update_flashes(dt)
	_update_sparks(dt)


func _connect_sources() -> void:
	var b := CombatEvents.bus()
	if b != _bus:
		_bus = b
		b.shot_fired.connect(on_shot_fired)
	var ps := _ps()
	if ps != _ps_connected:
		if _ps_connected != null and is_instance_valid(_ps_connected) \
				and _ps_connected.impact.is_connected(on_impact):
			_ps_connected.impact.disconnect(on_impact)
		_ps_connected = ps
		if ps != null:
			ps.impact.connect(on_impact)


# --- Leuchtspuren ---------------------------------------------------------------

static func _quad_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 0, 1), Vector3(-0.5, 0, 1)]
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[k])
		st.add_vertex(v[k])
	return st.commit()


func _build_tracers() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _quad_mesh()
	mm.instance_count = MAX_TRACERS
	mm.visible_instance_count = 0
	tracers = MultiMeshInstance3D.new()
	tracers.name = "Tracers"
	tracers.multimesh = mm
	var mat := ShaderMaterial.new()
	mat.shader = TRACER_SHADER
	tracers.material_override = mat
	tracers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tracers.custom_aabb = AABB(Vector3(-1e5, -1e4, -1e5), Vector3(2e5, 4e4, 2e5))
	tracers.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(tracers)


## Transform einer Leuchtspur: origin = Kopf, Spalte z = Kopf → Schwanz.
## Länge ~ 40 ms Flugweg (6–34 m), frische Geschosse nicht länger als ihr Weg seit der Mündung.
static func tracer_transform(head: Vector3, vel: Vector3, age: float) -> Transform3D:
	var sp := vel.length()
	var dir := vel / sp if sp > 1e-3 else Vector3.FORWARD
	var length := minf(clampf(sp * 0.04, 6.0, 34.0), sp * age + 1.0)
	var z := -dir * length
	var x := dir.cross(Vector3.UP)
	if x.length_squared() < 1e-6:
		x = dir.cross(Vector3.RIGHT)
	x = x.normalized()
	var y := x.cross(dir).normalized()
	return Transform3D(Basis(x, y, z), head)


func update_tracers() -> void:
	var ps := _ps()
	var mm := tracers.multimesh
	if ps == null:
		mm.visible_instance_count = 0
		tracer_count = 0
		return
	var slots := ps.tracer_slots()
	var n := mini(slots.size(), MAX_TRACERS)
	var frac := Engine.get_physics_interpolation_fraction() / float(Engine.physics_ticks_per_second)
	for k in n:
		var i := slots[k]
		var v := ps.velocity(i)
		var age := ps.age(i)
		mm.set_instance_transform(k, tracer_transform(ps.position(i) + v * frac, v, age + frac))
		var w := ps.weapon_of(i)
		var life := w.lifetime() if w != null else 3.0
		var a := clampf((life - age) / (life * 0.25), 0.0, 1.0)
		mm.set_instance_color(k, Color(TRACER_COLOR, a))
	mm.visible_instance_count = n
	tracer_count = n


# --- Mündungsfeuer ---------------------------------------------------------------

static func _radial_texture(inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


static func _additive_material(tex: Texture2D, billboard: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = billboard
	m.billboard_keep_scale = true
	m.no_depth_test = false
	m.disable_fog = true
	return m


func _build_flashes() -> void:
	_light_t.resize(MAX_LIGHTS)
	_light_t.fill(0.0)
	for i in MAX_LIGHTS:
		var l := OmniLight3D.new()
		l.name = "MuzzleLight%d" % i
		l.light_color = Color(1.0, 0.75, 0.4)
		l.omni_range = 6.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		lights.append(l)
		_light_src.append([null, Vector3.ZERO])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	mm.instance_count = MAX_LIGHTS
	mm.visible_instance_count = MAX_LIGHTS
	for i in MAX_LIGHTS:
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	_flash_mm = MultiMeshInstance3D.new()
	_flash_mm.name = "MuzzleFlashes"
	_flash_mm.multimesh = mm
	_flash_mm.material_override = _additive_material(
			_radial_texture(Color(1, 0.95, 0.8, 1), Color(1, 0.5, 0.1, 0)),
			BaseMaterial3D.BILLBOARD_ENABLED)
	_flash_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash_mm.custom_aabb = AABB(Vector3(-1e5, -1e4, -1e5), Vector3(2e5, 4e4, 2e5))
	_flash_mm.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_flash_mm)


func on_shot_fired(shooter: Node, gun_index: int, _shot_id: int) -> void:
	if not _built or shooter == null or not (shooter is Node3D):
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and cam.global_position.distance_to(shooter.global_position) > FLASH_MAX_DIST:
		return
	var local := Vector3.ZERO
	var w = shooter.get("weapons")
	if w != null:
		var ms: Array = w.mounts()
		if gun_index >= 0 and gun_index < ms.size():
			local = ms[gun_index].position + Vector3(0, 0, -0.6)
	var k := _light_next
	_light_next = (_light_next + 1) % MAX_LIGHTS
	_light_t[k] = FLASH_TIME
	_light_src[k] = [shooter, local]
	flashes_started += 1


func active_lights() -> int:
	var n := 0
	for l in lights:
		if l.visible:
			n += 1
	return n


func _update_flashes(dt: float) -> void:
	var mm := _flash_mm.multimesh
	for k in MAX_LIGHTS:
		var src: Array = _light_src[k]
		var s = src[0]
		var t := _light_t[k]
		_light_t[k] = t - minf(dt, FLASH_TIME * 0.5)   # langsame Bilder: Blitz trotzdem sichtbar
		if t <= 0.0 or s == null or not is_instance_valid(s):
			lights[k].visible = false
			mm.set_instance_transform(k, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			_light_t[k] = 0.0
			continue
		var f := clampf(t / FLASH_TIME, 0.0, 1.0)
		var xf: Transform3D = (s as Node3D).get_global_transform_interpolated()
		var p: Vector3 = xf * (src[1] as Vector3)
		lights[k].visible = true
		lights[k].global_position = p
		lights[k].light_energy = 3.0 * f
		var sc := (0.7 + randf() * 0.5) * (0.5 + 0.5 * f)
		mm.set_instance_transform(k, Transform3D(Basis(Vector3.FORWARD, randf() * TAU).scaled(
				Vector3(sc, sc, sc)), p))
		mm.set_instance_color(k, Color(1, 1, 1, f))


# --- Einschläge ------------------------------------------------------------------

func _make_emitter(spark: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.amount = 24 if spark else 16
	p.lifetime = 0.45 if spark else 1.4
	p.local_coords = spark
	p.visibility_aabb = AABB(Vector3(-15, -15, -15), Vector3(30, 30, 30))
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1) if spark else Vector3(0, 1, 0)
	var ramp := Gradient.new()
	if spark:
		pm.spread = 55.0
		pm.initial_velocity_min = 12.0
		pm.initial_velocity_max = 38.0
		pm.gravity = Vector3(0, -9.8, 0)
		pm.damping_min = 8.0
		pm.damping_max = 14.0
		pm.scale_min = 0.25
		pm.scale_max = 0.6
		ramp.set_color(0, Color(1, 0.95, 0.75, 1))
		ramp.set_color(1, Color(1, 0.35, 0.05, 0))
		ramp.add_point(0.4, Color(1, 0.7, 0.25, 1))
	else:
		pm.spread = 28.0
		pm.initial_velocity_min = 3.0
		pm.initial_velocity_max = 9.0
		pm.gravity = Vector3(0, -3.0, 0)
		pm.damping_min = 2.0
		pm.damping_max = 4.0
		pm.scale_min = 4.0
		pm.scale_max = 7.0
		var sc := Curve.new()
		sc.max_value = 2.0
		sc.add_point(Vector2(0, 0.5))
		sc.add_point(Vector2(1, 1.5))
		var sct := CurveTexture.new()
		sct.curve = sc
		pm.scale_curve = sct
		ramp.set_color(0, Color(0.8, 0.72, 0.58, 0.95))
		ramp.set_color(1, Color(0.75, 0.7, 0.62, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(1, 1) if spark else Vector2(2, 2)
	var m: StandardMaterial3D
	if spark:
		m = _additive_material(_radial_texture(Color(1, 1, 1, 1), Color(1, 1, 1, 0)),
				BaseMaterial3D.BILLBOARD_PARTICLES)
	else:
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _radial_texture(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## ProjectileSystem.impact: Funken bei Flugzeugtreffern, Staub bei Boden/Welt.
func on_impact(_slot: int, pos: Vector3, vel: Vector3, kind: int, target: Node, _zone: int) -> void:
	if not _built:
		return
	var back := -vel.normalized() if vel.length_squared() > 1e-4 else Vector3.UP
	if kind == ProjectileSystem.Impact.TARGET:
		var k := _spark_next
		_spark_next = (_spark_next + 1) % SPARK_POOL
		var p := sparks[k]
		var local := pos
		if target is Node3D:
			local = (target as Node3D).global_transform.affine_inverse() * pos
		_spark_follow[k] = [target if target is Node3D else null, local, p.lifetime]
		# −Z des Emitters zeigt zurück zum Schützen (Funken spritzen entgegen der Flugbahn)
		var up := Vector3.UP if absf(back.y) < 0.95 else Vector3.RIGHT
		p.global_transform = Transform3D(Basis.looking_at(back, up), pos)
		p.restart()
		impacts_started += 1
	elif kind == ProjectileSystem.Impact.GROUND or kind == ProjectileSystem.Impact.WORLD:
		var p := dust[_dust_next]
		_dust_next = (_dust_next + 1) % DUST_POOL
		p.global_transform = Transform3D(Basis(), pos + Vector3.UP * 0.2)
		p.restart()
		impacts_started += 1


func _update_sparks(dt: float) -> void:
	for k in SPARK_POOL:
		var f: Array = _spark_follow[k]
		if f[2] <= 0.0:
			continue
		f[2] -= dt
		var t = f[0]
		if t != null and is_instance_valid(t):
			var xf: Transform3D = (t as Node3D).get_global_transform_interpolated()
			sparks[k].global_position = xf * (f[1] as Vector3)


## Floating Origin: WeaponFx bleibt im Szenen-Ursprung. Leuchtspuren werden jeden Frame
## aus den (bereits verschobenen) Geschosspositionen neu gebaut; Blitze/Funken sind
## kurzlebig und springen höchstens einen Frame.
func shift_origin(_delta: Vector3) -> void:
	pass
