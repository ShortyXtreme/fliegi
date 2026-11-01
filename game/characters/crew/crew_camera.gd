class_name CrewCamera
extends Node3D
## M3 (Paket 4, Strang H): Kamera der Figur bzw. des Fahrzeugs.
## Third-Person über die rechte Schulter (Standard, PO-Entscheidung 1), Ego auf C
## (crew_view_toggle; die Figur meldet view_toggle_requested). PlayerSession ruft
## follow(target) und schaltet über process_mode/current um.
## Figur: Blick aus look_yaw/look_pitch der Figur. Fahrzeug: Verfolger hinter dem Heck,
## C (camera_next des DrivePlayerControllers) wechselt Fahrersicht/Verfolger.
## Die Kamera bleibt über dem Gelände (WorldGround.height_at + GROUND_CLEAR).

enum Mode { THIRD, EGO }

const SHOULDER := Vector3(0.45, 1.7, 0.0)
const THIRD_DIST := 3.0
const VEHICLE_OFFSET := Vector3(0.0, 3.2, 8.5)
const VEHICLE_EYE := Vector3(-0.45, 2.0, -1.2)
const GROUND_CLEAR := 0.35
const SMOOTH := 14.0

var mode: Mode = Mode.THIRD
var target: Node3D = null
var camera: Camera3D
var _connected: Array = []


func _init() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 70.0
	camera.near = 0.05
	add_child(camera)


func follow(t: Node3D) -> void:
	_disconnect_all()
	target = t
	if t == null:
		return
	if t.has_signal("view_toggle_requested"):
		_connect(t, "view_toggle_requested")
	var ds = t.get("driver_seat")
	if ds is Seat and ds.controller != null and ds.controller.has_signal("camera_next_requested"):
		_connect(ds.controller, "camera_next_requested")
	if t.has_method("set_ego"):
		t.call("set_ego", mode == Mode.EGO)
	update_now()


func toggle_view() -> void:
	mode = Mode.EGO if mode == Mode.THIRD else Mode.THIRD
	if target != null and target.has_method("set_ego"):
		target.call("set_ego", mode == Mode.EGO)


func _connect(o: Object, sig: String) -> void:
	var cb := Callable(self, "toggle_view")
	if not o.is_connected(sig, cb):
		o.connect(sig, cb)
	_connected.append([o, sig])


func _disconnect_all() -> void:
	var cb := Callable(self, "toggle_view")
	for e in _connected:
		if is_instance_valid(e[0]) and e[0].is_connected(e[1], cb):
			e[0].disconnect(e[1], cb)
	_connected.clear()
	if target != null and is_instance_valid(target) and target.has_method("set_ego"):
		target.call("set_ego", false)


func _process(dt: float) -> void:
	_update(1.0 - exp(-SMOOTH * dt))


## Sofort an die Sollposition setzen (Tests, Sitzwechsel).
func update_now() -> void:
	_update(1.0)


## Sollpose der Kamera als Transform (ohne Glättung).
func desired_transform() -> Transform3D:
	if target == null or not is_instance_valid(target):
		return camera.global_transform
	if target is CrewCharacter:
		return _character_xf(target as CrewCharacter)
	return _vehicle_xf(target)


func _update(k: float) -> void:
	if target == null or not is_instance_valid(target) or not is_inside_tree():
		return
	var want := desired_transform()
	var cur := camera.global_transform
	var o := cur.origin.lerp(want.origin, k) if k < 1.0 else want.origin
	var b := cur.basis.orthonormalized().slerp(want.basis.orthonormalized(), k) if k < 1.0 else want.basis
	camera.global_transform = Transform3D(b, o)


func _character_xf(c: CrewCharacter) -> Transform3D:
	var yaw_b := Basis(Vector3.UP, c.look_yaw)
	var b := yaw_b * Basis(Vector3.RIGHT, c.look_pitch)
	if mode == Mode.EGO:
		var eye := c.global_position + Vector3.UP * CrewCharacter.EYE_HEIGHT + yaw_b * Vector3(0, 0, -0.12)
		return Transform3D(b, eye)
	var pivot := c.global_position + yaw_b * SHOULDER
	var pos := pivot + b * Vector3(0, 0, THIRD_DIST)
	pos.y = maxf(pos.y, WorldGround.height_at(pos.x, pos.z) + GROUND_CLEAR)
	return Transform3D(b, pos)


func _vehicle_xf(v: Node3D) -> Transform3D:
	var yaw := v.global_rotation.y
	var yaw_b := Basis(Vector3.UP, yaw)
	if mode == Mode.EGO:
		return Transform3D(v.global_transform.basis, v.global_transform * VEHICLE_EYE)
	var pos := v.global_position + yaw_b * VEHICLE_OFFSET
	pos.y = maxf(pos.y, WorldGround.height_at(pos.x, pos.z) + GROUND_CLEAR)
	var look := v.global_position + Vector3.UP * 1.5
	return Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)
