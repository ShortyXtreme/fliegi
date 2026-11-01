class_name CrewPlayerController
extends Controller
## M3 Stub (Paket 0a, gehört Strang H / Paket 4): Mensch zu Fuß (Kontext CREW).
## Liefert einen CrewIntent aus den Aktionen crew_* (InputBindings) und Maus/rechtem Stick.
## Feste Signaturen: compute_crew_intent(dt), look_yaw/look_pitch, Signal view_toggle_requested.

signal view_toggle_requested

const MOUSE_SENS := 0.0025
const STICK_LOOK_RATE := 2.6

var look_yaw := 0.0
var look_pitch := 0.0
var _intent := CrewIntent.new()
var _view_prev := false
var _enter_prev := false
var _drop_prev := false


func _init() -> void:
	InputBindings.setup()
	peer_id = Authority.local_peer_id()


func _unhandled_input(event: InputEvent) -> void:
	if seat == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_yaw = wrapf(look_yaw - event.relative.x * MOUSE_SENS, -PI, PI)
		look_pitch = clampf(look_pitch - event.relative.y * MOUSE_SENS, -1.4, 1.4)


func compute_crew_intent(dt: float) -> CrewIntent:
	var i := _intent
	var mv := Vector2(
		Input.get_axis("crew_move_left", "crew_move_right") + Input.get_axis("joy_crew_move_left", "joy_crew_move_right"),
		Input.get_axis("crew_move_back", "crew_move_forward") + Input.get_axis("joy_crew_move_back", "joy_crew_move_forward"))
	i.move = mv.limit_length(1.0)
	var look := Vector2(Input.get_axis("look_right", "look_left"), Input.get_axis("look_down", "look_up"))
	look_yaw = wrapf(look_yaw + look.x * STICK_LOOK_RATE * dt, -PI, PI)
	look_pitch = clampf(look_pitch + look.y * STICK_LOOK_RATE * 0.6 * dt, -1.4, 1.4)
	i.look_yaw = look_yaw
	i.look_pitch = look_pitch
	i.sprint = Input.is_action_pressed("crew_sprint")
	i.interact = Input.is_action_pressed("crew_interact")
	i.wheel_open = Input.is_action_pressed("crew_wheel")
	var e := Input.is_action_pressed("crew_enter")
	i.enter = e and not _enter_prev
	_enter_prev = e
	var d := Input.is_action_pressed("crew_drop")
	i.drop = d and not _drop_prev
	_drop_prev = d
	var vt := Input.is_action_pressed("crew_view_toggle")
	i.view_toggle = vt and not _view_prev
	if i.view_toggle:
		view_toggle_requested.emit()
	_view_prev = vt
	return i.clamp_values()
