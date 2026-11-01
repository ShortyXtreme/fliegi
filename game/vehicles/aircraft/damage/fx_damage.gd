class_name DamageFx
extends Node3D
## Schadenseffekte am Flugzeug (Paket 11): Ölrauch (grau) am Motor, Brand (schwarzer Rauch
## + Flammen) je brennender Zone, Treibstoffleck (heller Nebel) am Tank. Liest jeden Frame
## nur den DamageModel-Zustand (läuft auch auf Clients aus from_array()). Partikel in
## Weltkoordinaten, damit sie als Spur hinter dem Flugzeug stehen bleiben.

const Z := DamageModel.Zone

var damage: DamageModel
## Zone -> {"smoke": GPUParticles3D, "flame": GPUParticles3D}
var fire := {}
var oil: GPUParticles3D
var leak := {}


## anchor_of(zone) liefert die lokale Position (Flugzeug-Koordinaten) einer Zone.
func setup(d: DamageModel) -> void:
	damage = d
	name = "DamageFx"
	oil = _add(make_smoke(false), _anchor(Z.ENGINE) + Vector3(0, 0.3, 0.6))
	for z in [Z.ENGINE, Z.FUEL_L, Z.FUEL_R, Z.WING_L, Z.WING_R, Z.TAIL, Z.COCKPIT]:
		fire[z] = {"smoke": _add(make_smoke(true), _anchor(z)), "flame": _add(make_flame(), _anchor(z))}
	for z in [Z.FUEL_L, Z.FUEL_R]:
		leak[z] = _add(make_vapor(), _anchor(z) + Vector3(0, -0.15, 0.4))


func _anchor(zone: int) -> Vector3:
	var h := damage.hitboxes if damage != null else null
	if h != null:
		for k in h.box_count():
			if h.zones[k] == zone and h.damage_mul[k] >= 1.0:
				return h.centers[k]
	return Vector3.ZERO


func _add(p: GPUParticles3D, pos: Vector3) -> GPUParticles3D:
	p.position = pos
	p.emitting = false
	add_child(p)
	return p


func _process(_dt: float) -> void:
	if damage == null:
		return
	oil.emitting = damage.oil_leaking() and damage.outcome != DamageModel.Outcome.CRASHED
	for z in fire:
		var on := damage.is_burning(z)
		fire[z].smoke.emitting = on
		fire[z].flame.emitting = on
	leak[Z.FUEL_L].emitting = damage.fuel.leak_lps[0] > 0.0 and damage.fuel.liters[0] > 0.0
	leak[Z.FUEL_R].emitting = damage.fuel.leak_lps[1] > 0.0 and damage.fuel.liters[1] > 0.0


## Anzahl aktiver Emitter (Tests, Debug).
func active_count() -> int:
	var n := 0
	for c in get_children():
		if c is GPUParticles3D and c.emitting:
			n += 1
	return n


# --- Bausteine ----------------------------------------------------------------

static func _particles(amount: int, life: float, col: Color, size: float, vel: Vector2,
		grav: Vector3, scale_max: float, additive := false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 25.0
	m.initial_velocity_min = vel.x
	m.initial_velocity_max = vel.y
	m.gravity = grav
	m.scale_min = 1.0
	m.scale_max = scale_max
	m.damping_min = 0.5
	m.damping_max = 1.5
	var ramp := Gradient.new()
	ramp.set_color(0, col)
	ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	m.color_ramp = gt
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.0))
	var st := CurveTexture.new()
	st.curve = sc
	m.scale_curve = st
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.render_priority = 1
	q.material = mat
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-400, -400, -400), Vector3(800, 800, 800))
	return p


static var _dot: GradientTexture2D


## Weicher runder Partikel (radialer Verlauf), einmal erzeugt.
static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.5, Color(1, 1, 1, 0.6))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 64
		_dot.height = 64
	return _dot


## Rauch: dark = Brand (schwarz), sonst Öl (grau).
static func make_smoke(dark: bool) -> GPUParticles3D:
	var c := Color(0.05, 0.05, 0.05, 0.85) if dark else Color(0.5, 0.5, 0.5, 0.55)
	return _particles(96 if dark else 64, 4.0 if dark else 3.0, c, 1.6, Vector2(0.5, 2.0),
		Vector3(0, 0.8, 0), 4.0 if dark else 3.0)


static func make_flame() -> GPUParticles3D:
	return _particles(64, 0.4, Color(1.0, 0.45, 0.08, 1.0), 1.3, Vector2(0.5, 1.5),
		Vector3.ZERO, 1.6, true)


static func make_vapor() -> GPUParticles3D:
	return _particles(48, 1.6, Color(0.9, 0.92, 0.95, 0.35), 0.8, Vector2(0.2, 0.8),
		Vector3.ZERO, 3.0)
