class_name Wreck
extends RigidBody3D
## Wrack (Paket 6, M3.5 physikalisch): übernimmt beim Neustart die Darstellung, Lage und
## Bewegung des abgeschossenen Flugzeugs. Ist es noch in der Luft, stürzt es weiter (Luftreibung,
## Rauchspur) bis zum Aufschlag (Explosion, Krater, Rauchsäule über CrashFx) und bleibt liegen.
## Nach lifetime (MatchRules.wreck_lifetime ab Absturz) sinkt es in FADE_TIME s in den Boden.
## Höchstens MAX_ACTIVE gleichzeitig (ältestes wird zuerst ausgeblendet). Layer WRECK.
## Headless ohne Darstellung (Physik und Lebensdauer laufen).

const MAX_ACTIVE := 6
const FADE_TIME := 3.0
## Ab dieser Höhe über Grund gilt das Wrack beim Erzeugen als fallend.
const AIRBORNE_AGL := 4.0

static var active: Array = []

signal impacted(position: Vector3)

var lifetime := 75.0
var age := 0.0
var cause: int = CombatEvents.Cause.UNKNOWN
var burning := false
## true = liegt am Boden (Aufschlag erfolgt oder als liegendes Wrack erzeugt).
var landed := false
var drag_k := 4.0
var _fade := -1.0
var _settle := -1.0
var _trail: GPUParticles3D
var _flame: GPUParticles3D
var _model: Node3D


## Kompatibel zu M2: liegendes Wrack an xf (ohne Flugzeugdarstellung).
static func spawn_at(parent: Node, xf: Transform3D, life: float, is_burning := false,
		vel := Vector3.ZERO, ang := Vector3.ZERO, model: Node3D = null) -> Wreck:
	var w := Wreck.new()
	w.name = "Wreck"
	w.lifetime = life
	w.burning = is_burning
	w.mass = 1800.0
	w.collision_layer = Layers.WRECK
	w.collision_mask = Layers.WORLD
	w.continuous_cd = true
	w.contact_monitor = true
	w.max_contacts_reported = 2
	w.angular_damp = 0.3
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.05
	w.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(5.0, 1.4, 7.5)
	cs.shape = box
	w.add_child(cs)
	w._model = model
	if model != null:
		w.add_child(model)
	parent.add_child(w)
	w.global_transform = xf
	var agl := xf.origin.y - WorldGround.height_at(xf.origin.x, xf.origin.z)
	w.landed = agl < AIRBORNE_AGL and vel.length() < 15.0
	if w.landed:
		w.freeze = true
	else:
		w.linear_velocity = vel
		w.angular_velocity = ang
	w.body_entered.connect(w._on_body_entered)
	if DisplayServer.get_name() != "headless":
		w._build_visual()
	active.append(w)
	_enforce_limit()
	return w


## M3.5: Wrack aus einem abgeschossenen Flugzeug (Darstellung samt abgetrennter Teile,
## Geschwindigkeit, Brand). Das Flugzeug selbst wird danach vom SpawnManager neu gesetzt.
static func spawn_from_aircraft(a: Node3D, life: float, is_burning := false) -> Wreck:
	var model: Node3D = null
	var vis = a.get("visual")
	if vis is AircraftVisual and (vis as AircraftVisual).model_root != null:
		var mr := (vis as AircraftVisual).model_root
		model = mr.duplicate() as Node3D
		model.transform = a.global_transform.affine_inverse() * mr.global_transform
		for n in model.find_children("prop_disc", "", true, false):
			(n as Node3D).visible = false
		for n in model.find_children("prop_blades", "", true, false):
			(n as Node3D).visible = true
	var vel: Vector3 = a.linear_velocity if a is RigidBody3D else Vector3.ZERO
	var ang: Vector3 = a.angular_velocity if a is RigidBody3D else Vector3.ZERO
	var d = a.get("damage")
	if d is DamageModel and (d as DamageModel).outcome == DamageModel.Outcome.CRASHED:
		vel = Vector3.ZERO
		ang = Vector3.ZERO
	var w := spawn_at(a.get_parent(), a.global_transform, life, is_burning, vel, ang, model)
	if d is DamageModel:
		w.cause = (d as DamageModel).destroy_cause
	return w


static func _enforce_limit() -> void:
	active = active.filter(func(x): return is_instance_valid(x) and not x.is_queued_for_deletion() and x._fade < 0.0)
	while active.size() > MAX_ACTIVE:
		var old: Wreck = active.pop_front()
		old.start_fade()


static func active_count() -> int:
	_enforce_limit()
	return active.size()


func _exit_tree() -> void:
	active.erase(self)


func _build_visual() -> void:
	if _model == null:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(4.0, 0.9, 7.0)
		m.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.08, 0.08, 0.07)
		mat.roughness = 1.0
		m.material_override = mat
		add_child(m)
	if not landed:
		_trail = DamageFx.make_smoke(true)
		_trail.emitting = true
		_trail.amount_ratio = 1.0 if burning else 0.6
		add_child(_trail)
		if burning:
			_flame = DamageFx.make_flame()
			_flame.emitting = true
			add_child(_flame)
	else:
		_char()
		var smoke := DamageFx.make_smoke(true)
		smoke.position = Vector3(0, 1, 0)
		smoke.emitting = true
		smoke.amount_ratio = 1.0 if burning else 0.4
		smoke.name = "GroundSmoke"
		add_child(smoke)


## Verkohlt: dunkle Überlagerung auf allen Teilen.
func _char() -> void:
	if _model == null:
		return
	var ov := StandardMaterial3D.new()
	ov.albedo_color = Color(0.02, 0.02, 0.02, 0.6)
	ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ov.roughness = 1.0
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_overlay = ov


func start_fade() -> void:
	if _fade < 0.0:
		_fade = 0.0
		set_deferred("freeze", true)
		if _trail != null:
			_trail.emitting = false


func _on_body_entered(_b: Node) -> void:
	if not landed:
		_land()


func _land() -> void:
	landed = true
	var pos := global_position
	CrashFx.impact(get_parent(), pos, burning, maxf(lifetime - age, 5.0))
	impacted.emit(pos)
	linear_damp = 3.0
	angular_damp = 4.0
	_settle = 0.0
	if _trail != null:
		_trail.emitting = false
	if _flame != null:
		_flame.emitting = false
	if DisplayServer.get_name() != "headless":
		_char()


func _physics_process(dt: float) -> void:
	age += dt
	if _fade >= 0.0:
		_fade += dt
		global_position.y -= dt * 1.0
		if _fade >= FADE_TIME:
			queue_free()
		return
	if age >= lifetime - FADE_TIME:
		start_fade()
		return
	if freeze:
		return
	var h := WorldGround.height_at(global_position.x, global_position.z)
	if not landed:
		var v := linear_velocity
		var s := v.length()
		if s > 0.1:
			apply_central_force(-v * s * drag_k)
		# Sicherung: Bodenhöhe ohne Kollisionskachel
		if global_position.y - h < 1.8 and linear_velocity.y <= 0.0:
			_land()
	elif _settle >= 0.0:
		_settle += dt
		if _settle > 4.0 or (linear_velocity.length() < 0.3 and _settle > 1.0):
			set_deferred("freeze", true)
	if global_position.y < h - 1.5:
		global_position.y = h
		set_deferred("freeze", true)
