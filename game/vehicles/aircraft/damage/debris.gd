class_name Debris
extends RigidBody3D
## M3.5: Abgetrenntes Teil (Flügel, Leitwerk) als eigener Körper. Fällt mit einfacher
## quadratischer Luftreibung (flatternde Platte, Endgeschwindigkeit ~20 m/s), bleibt am Boden
## liegen und wird nach LIFETIME ausgeblendet (sinkt in den Boden). Höchstens MAX_ACTIVE
## gleichzeitig – das älteste verschwindet zuerst. Kollidiert nur mit dem Boden (Layers.WORLD).
## Headless ohne Darstellung (nur Physik, für Tests).

const MAX_ACTIVE := 16
const LIFETIME := 75.0
const FADE_TIME := 3.0

static var active: Array = []

var lifetime := LIFETIME
var age := 0.0
## Luftreibung F = -drag_k · v · |v| (0,5 · ρ · Cw · A).
var drag_k := 2.0
## Name des Teils (wing_L, wing_R, tail).
var part := ""
var _fade := -1.0
var _smoke: GPUParticles3D


## size: Kollisionsbox (lokal), visual: bereits abgelöste Darstellung (wird Kind, Lage
## visual_xf relativ zum Körper) oder null.
static func spawn(parent: Node, xf: Transform3D, size: Vector3, mass_kg: float, vel: Vector3,
		ang: Vector3, visual: Node3D = null, visual_xf := Transform3D.IDENTITY, smoke := false,
		part_name := "") -> Debris:
	var d := Debris.new()
	d.name = "Debris"
	d.part = part_name
	d.mass = maxf(mass_kg, 1.0)
	d.collision_layer = 0
	d.collision_mask = Layers.WORLD
	d.continuous_cd = true
	d.angular_damp = 0.4
	d.drag_k = 0.5 * 1.2 * 1.0 * maxf(size.x * size.z, size.x * size.y)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.1
	d.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	d.add_child(cs)
	if visual != null:
		d.add_child(visual)
		visual.transform = visual_xf
	parent.add_child(d)
	d.global_transform = xf
	d.linear_velocity = vel
	d.angular_velocity = ang
	if smoke and DisplayServer.get_name() != "headless":
		d._smoke = DamageFx.make_smoke(true)
		d._smoke.emitting = true
		d.add_child(d._smoke)
	active.append(d)
	_enforce_limit()
	return d


static func _enforce_limit() -> void:
	active = active.filter(func(x): return is_instance_valid(x) and not x.is_queued_for_deletion() and x._fade < 0.0)
	while active.size() > MAX_ACTIVE:
		var old: Debris = active.pop_front()
		old.start_fade()


## Anzahl lebender (nicht ausblendender) Trümmerteile.
static func active_count() -> int:
	_enforce_limit()
	return active.size()


func start_fade() -> void:
	if _fade < 0.0:
		_fade = 0.0
		freeze = true
		if _smoke != null:
			_smoke.emitting = false


func _exit_tree() -> void:
	active.erase(self)


func _physics_process(dt: float) -> void:
	age += dt
	if _fade >= 0.0:
		_fade += dt
		global_position.y -= dt * 0.8
		if _fade >= FADE_TIME:
			queue_free()
		return
	if age >= lifetime - FADE_TIME:
		start_fade()
		return
	if freeze:
		return
	var v := linear_velocity
	var s := v.length()
	if s > 0.1:
		apply_central_force(-v * s * drag_k)
	# Rauch nach dem Liegenbleiben ausklingen lassen
	if _smoke != null and age > 20.0:
		_smoke.emitting = false
	# Sicherung: nicht durch den Boden fallen (Kacheln ohne Kollision in der Ferne)
	var h := WorldGround.height_at(global_position.x, global_position.z)
	if global_position.y < h - 1.0:
		global_position.y = h + 0.2
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		set_deferred("freeze", true)
