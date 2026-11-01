class_name CameraRig
extends Node3D
## Kameras: Verfolger (Standard), Cockpit, freie Orbit-Kamera. C/Y wechselt.
## Im Mouse-Aim-Modus folgt die Verfolgerkamera dem Maus-Zielpunkt (nicht der Nase),
## so wie in War Thunder / Nuclear Option.

enum Mode { CHASE, COCKPIT, ORBIT }
const MODE_NAMES := ["Verfolger", "Cockpit", "Orbit"]

var mode: Mode = Mode.CHASE
var target: Aircraft
var player: PlayerController
var camera: Camera3D
var orbit_yaw := 0.6
var orbit_pitch := -0.25
var orbit_dist := 22.0
var _chase_basis := Basis.IDENTITY
var _base_fov := 70.0
## Buffet-Rütteln (Vorwarnung vor dem Abriss): Stärke in Grad bei buffet = 1.
const SHAKE_DEG := 0.9
var _shake_t := 0.0
var _shake_amp := 0.0


func _ready() -> void:
	# Kamera wird pro Frame aus der interpolierten Flugzeuglage gesetzt -> selbst nicht interpolieren.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera = Camera3D.new()
	camera.far = 20000.0
	camera.near = 0.1
	camera.fov = 70.0
	add_child(camera)
	camera.current = true
	top_level = true


func next_mode() -> void:
	mode = ((mode + 1) % 3) as Mode
	if target and target.visual:
		target.visual.set_cockpit_view(mode == Mode.COCKPIT)


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.ORBIT:
		if event is InputEventMouseMotion and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
				or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
			orbit_yaw -= event.relative.x * 0.005
			orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.005, -1.4, 1.4)
	if event.is_action_pressed("zoom_in"):
		orbit_dist = maxf(orbit_dist * 0.9, 8.0)
	if event.is_action_pressed("zoom_out"):
		orbit_dist = minf(orbit_dist * 1.1, 200.0)


func _process(dt: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var xf := target.get_global_transform_interpolated()
	var look := player.look_offset if player else Vector2.ZERO
	# M2.1 Ziel-Zoom (Verfolger und Cockpit): Sichtfeld enger, Kamerafolge ruhiger
	var zm := player.zoom_mul() if player else 1.0
	match mode:
		Mode.CHASE:
			var aim := player.aim_dir if player and player.mouse_aim_active() else -xf.basis.z
			var up := xf.basis.y.lerp(Vector3.UP, 0.7).normalized()
			if player and player.mouse_aim_active():
				up = Vector3.UP
			var want := Basis.looking_at(aim, up)
			want = want * Basis(Vector3.UP, look.x) * Basis(Vector3.RIGHT, look.y)
			_chase_basis = _chase_basis.slerp(want.orthonormalized(), 1.0 - exp(-6.0 / zm * dt)).orthonormalized()
			var dist := 16.0 + target.telemetry().airspeed * 0.02
			global_transform = Transform3D(_chase_basis, xf.origin + _chase_basis * Vector3(0, 3.2 * zm, dist))
			_base_fov = lerpf(_base_fov, 70.0 + target.telemetry().airspeed * 0.04, 1.0 - exp(-2.0 * dt))
			camera.fov = ZoomRules.zoomed_fov(_base_fov, zm)
		Mode.COCKPIT:
			var b := xf.basis * Basis(Vector3.UP, look.x) * Basis(Vector3.RIGHT, look.y)
			global_transform = Transform3D(b, xf * target.data.cockpit_eye)
			camera.fov = ZoomRules.zoomed_fov(80.0, zm)
		Mode.ORBIT:
			var b := Basis(Vector3.UP, orbit_yaw) * Basis(Vector3.RIGHT, orbit_pitch)
			global_transform = Transform3D(b, xf.origin + b * Vector3(0, 0, orbit_dist))
			camera.fov = 65.0
	camera.near = 0.05 if mode == Mode.COCKPIT else 0.3
	# Buffet: proportional zur Telemetrie, 9–13 Hz, im Cockpit stärker
	var want := target.telemetry().buffet
	_shake_amp = lerpf(_shake_amp, want, 1.0 - exp(-10.0 * dt))
	_shake_t += dt
	if _shake_amp > 0.01:
		var a := deg_to_rad(SHAKE_DEG) * _shake_amp * (1.4 if mode == Mode.COCKPIT else 1.0)
		var sx := sin(_shake_t * TAU * 11.0) * 0.6 + sin(_shake_t * TAU * 17.3) * 0.4
		var sy := sin(_shake_t * TAU * 9.1 + 1.3) * 0.6 + sin(_shake_t * TAU * 13.7) * 0.4
		var b := global_transform.basis * Basis(Vector3.RIGHT, sx * a) * Basis(Vector3.UP, sy * a * 0.6)
		global_transform = Transform3D(b.orthonormalized(), global_position + b.y * sx * a * 0.4)
