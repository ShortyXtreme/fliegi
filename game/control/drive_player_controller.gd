class_name DrivePlayerController
extends Controller
## M3 (Paket 0a): Mensch am Steuer eines Bodenfahrzeugs (Kontext DRIVE). Liefert einen
## PilotIntent: throttle 0..1, brakes 0..1 (im Stand = rückwärts, wertet GroundVehicle aus),
## yaw = Lenkung (-1 links .. +1 rechts). Aussteigen: J / Steuerkreuz ← 1 s halten
## -> Signal exit_requested (PlayerSession -> SeatService.request_exit).

signal exit_requested
signal exit_hold_changed(progress: float)
signal camera_next_requested

var _intent := PilotIntent.new()
var _exit_t := 0.0
var exit_hold_progress := 0.0
var _exit_sent := false
## Paket 14: Handbremse getrennt von der Bremse (GroundVehicle fährt mit Handbremse nie
## rückwärts, nur „Bremse halten im Stand“ legt den Rückwärtsgang ein).
var handbrake := false


func _init() -> void:
	InputBindings.setup()
	peer_id = Authority.local_peer_id()


func _unhandled_input(event: InputEvent) -> void:
	if seat != null and event.is_action_pressed("camera_next"):
		camera_next_requested.emit()


func compute_intent(dt: float) -> PilotIntent:
	var i := _intent
	i.throttle = Input.get_action_strength("drive_throttle")
	handbrake = Input.is_action_pressed("drive_handbrake")
	i.brakes = maxf(Input.get_action_strength("drive_brake"), 1.0 if handbrake else 0.0)
	i.yaw = Input.get_axis("drive_steer_left", "drive_steer_right") \
		+ Input.get_axis("joy_drive_steer_left", "joy_drive_steer_right")
	i.fire_primary = false
	i.fire_secondary = false
	i.eject = false
	_update_exit(Input.is_action_pressed("eject_hold"), dt)
	return i.clamp_values()


func _update_exit(held: bool, dt: float) -> void:
	_exit_t = _exit_t + dt if held else 0.0
	if not held:
		_exit_sent = false
	var p := clampf(_exit_t / InputBindings.EXIT_HOLD_TIME, 0.0, 1.0)
	if p != exit_hold_progress:
		exit_hold_progress = p
		exit_hold_changed.emit(p)
	if p >= 1.0 and not _exit_sent:
		_exit_sent = true
		exit_requested.emit()
