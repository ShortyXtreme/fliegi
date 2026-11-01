class_name Parachute
extends Node3D
## Fallschirm-Platzhalter (M2, ohne Third-Person): sinkt mit fester Rate und Seitendrift
## zu Boden, verschwindet nach der Landung. survives = false: Ausstieg zu tief (Pilot tot).

const SINK_RATE := 5.5
const LINGER_TIME := 10.0

signal landed(parachute: Parachute)

var pilot: PilotRecord
var survives := true
var drift := Vector3.ZERO
var on_ground := false
var _linger := 0.0


static func spawn_from(a: Node3D, rec: PilotRecord, survives_jump: bool) -> Parachute:
	var p := Parachute.new()
	p.name = "Parachute"
	p.pilot = rec
	p.survives = survives_jump
	var v: Vector3 = a.linear_velocity if a is RigidBody3D else Vector3.ZERO
	p.drift = Vector3(v.x, 0.0, v.z).limit_length(8.0) * 0.3
	var parent := a.get_parent()
	if parent != null:
		parent.add_child(p)
		p.global_position = a.global_position + a.global_transform.basis.y * 2.0
		if not DisplayServer.get_name() == "headless":
			p._build_visual()
	if not survives_jump and rec != null:
		rec.on_killed()
	return p


func _build_visual() -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 3.0
	s.height = 3.0
	s.is_hemisphere = true
	m.mesh = s
	m.position = Vector3(0, 4, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.85)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	add_child(m)


func _physics_process(dt: float) -> void:
	if on_ground:
		_linger += dt
		if _linger >= LINGER_TIME:
			queue_free()
		return
	global_position += (drift + Vector3.DOWN * SINK_RATE) * dt
	var g := WorldGround.height_at(global_position.x, global_position.z)
	if global_position.y <= g:
		global_position.y = g
		on_ground = true
		landed.emit(self)
