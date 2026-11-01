class_name PlayerController
extends Controller
## Lokaler Mensch: Tastatur, Xbox-Gamepad, Maus. Erzeugt ausschließlich PilotIntents.
## Maus-Zielsteuerung (Mouse-Aim, Standard im Arcade-Modus): Die Maus bewegt einen
## Zielpunkt im Raum, der Autopilot-Helfer erzeugt daraus Knüppelwerte. Jede manuelle
## Eingabe (Tastatur/Stick) übersteuert den Mausflug sofort.

signal camera_next_requested
signal debug_toggle_requested
## M2.1: Shift+F3 – Kräfte-Debug (alter F3-Inhalt); F3 allein = Treffer-Debug.
signal debug_forces_requested
signal help_toggle_requested
signal reset_requested(in_air: bool)
## Fahrwerkshebel betätigt; accepted = false, wenn Einfahren am Boden verweigert wurde.
signal gear_toggled(down: bool, accepted: bool)
## Notausstieg-Taste (J / Steuerkreuz ←): progress 0..1 während des Haltens, 1 = ausgelöst.
signal eject_hold_changed(progress: float)

const KEY_RAMP := 4.0              # Tastatur-Rampe (Einheiten/s) -> weich statt digital
const THROTTLE_RATE := 0.6         # Gas pro Sekunde beim Halten
const FLAP_STEPS := [0.0, 0.5, 1.0]
const MOUSE_SENS := 0.0025
## Parkbremse löst sich ab dieser Gasstellung (oder mit B).
const PARK_RELEASE_THROTTLE := 0.1

var throttle := 0.0
var flap_index := 0
## Fahrwerkshebel: true = ausgefahren.
var gear_down := true
## Parkbremse: beim Start aktiv, löst sich bei Gas > 10 % oder Taste B.
var parking_brake := true
var assist_mode := FlightAssist.Mode.ARCADE
var mouse_aim_enabled := true
## Für Tests/Headless: Mouse-Aim aktiv, auch wenn die Maus nicht gefangen ist.
var force_mouse_aim := false
## Zielrichtung der Maus (Welt). Wird von Kamera/HUD gelesen.
var aim_dir := Vector3.FORWARD
## M2.1 Ziel-Zoom: 0..1 (weich überblendet), Vergrößerung bei voller Taste.
var zoom_amount := 0.0
var zoom_full_mul := 1.0
## Für Tests: Zoom-Taste simulieren (null = echte Eingabe).
var zoom_override = null
var look_offset := Vector2.ZERO     # Kamera-Umsehen (rechter Stick / Maus mit RMT)
var _kb := Vector3.ZERO             # geglättete Tastatur (pitch, roll, yaw)
var _intent := PilotIntent.new()
var _manual_override_t := 0.0
## LMT gedrückt und Maus gefangen (Feuer). Der Klick, der die Maus fängt, feuert nicht.
var _lmb_fire := false
var _lmb_swallow := false
## Haltezeit der Notausstieg-Taste (s); eject_hold_progress 0..1 für das HUD.
var _eject_t := 0.0
var eject_hold_progress := 0.0


func _init() -> void:
	InputBindings.setup()


func on_possess(s: Seat) -> void:
	super.on_possess(s)
	_reset_aim()


func mouse_aim_active() -> bool:
	return mouse_aim_enabled and assist_mode == FlightAssist.Mode.ARCADE \
		and (force_mouse_aim or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_on_left_mouse(event.pressed)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# M2.1: beim Zoomen Empfindlichkeit proportional verringern (ruhigeres Zielen)
		var rel: Vector2 = event.relative * mouse_sens()
		if Input.is_action_pressed("mouse_look") or not mouse_aim_active():
			look_offset.x = wrapf(look_offset.x - rel.x, -PI, PI)
			look_offset.y = clampf(look_offset.y - rel.y, -1.3, 1.3)
		else:
			_rotate_aim(rel)
	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_lmb_fire = false
	if event.is_action_pressed("flaps_cycle"):
		flap_index = (flap_index + 1) % FLAP_STEPS.size()
	if event.is_action_pressed("gear_toggle"):
		toggle_gear()
	if event.is_action_pressed("assist_toggle"):
		assist_mode = FlightAssist.Mode.REALISTIC if assist_mode == FlightAssist.Mode.ARCADE \
			else FlightAssist.Mode.ARCADE
		_reset_aim()
	if event.is_action_pressed("mouse_aim_toggle"):
		mouse_aim_enabled = not mouse_aim_enabled
		_reset_aim()
	if event.is_action_pressed("camera_next"):
		camera_next_requested.emit()
	if event.is_action_pressed("debug_toggle"):
		if event is InputEventKey and (event as InputEventKey).shift_pressed:
			debug_forces_requested.emit()
		else:
			debug_toggle_requested.emit()
	if event.is_action_pressed("help_toggle"):
		help_toggle_requested.emit()
	if event.is_action_pressed("zoom_hold"):
		look_offset = Vector2.ZERO   # Zoom schaut immer nach vorn (ersetzt R3 „Blick zurück“)
	if event.is_action_pressed("reset_runway"):
		reset_requested.emit(false)
	if event.is_action_pressed("reset_air"):
		reset_requested.emit(true)


## LMT: Ist die Maus nicht gefangen, fängt der Klick sie nur (und feuert nicht, bis
## losgelassen). Bei gefangener Maus feuert LMT, solange sie gedrückt ist.
func _on_left_mouse(pressed: bool) -> void:
	if pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_lmb_swallow = true
			_lmb_fire = false
		elif not _lmb_swallow:
			_lmb_fire = true
	else:
		_lmb_swallow = false
		_lmb_fire = false


## Aktuelle Vergrößerung (1 = kein Zoom).
func zoom_mul() -> float:
	return lerpf(1.0, zoom_full_mul, zoom_amount)


## Maus-Empfindlichkeit (rad je Pixel) inkl. Zoom.
func mouse_sens() -> float:
	return MOUSE_SENS / zoom_mul()


func zoom_held() -> bool:
	if zoom_override != null:
		return bool(zoom_override)
	return InputMap.has_action("zoom_hold") and Input.is_action_pressed("zoom_hold")


## Zoom je Frame nachführen (Modusregeln: ZoomRules).
func update_zoom(dt: float) -> void:
	var v := get_vehicle() as Aircraft
	var f := ZoomRules.factor(assist_mode, v.data if v != null else null)
	var held := zoom_held() and f > 1.0
	if held:
		zoom_full_mul = f
	zoom_amount = lerpf(zoom_amount, 1.0 if held else 0.0, 1.0 - exp(-dt / ZoomRules.BLEND_TIME))
	if zoom_amount < 0.001 and not held:
		zoom_amount = 0.0


func _process(dt: float) -> void:
	update_zoom(dt)


func _rotate_aim(rel: Vector2) -> void:
	var up := Vector3.UP
	var right := aim_dir.cross(up).normalized()
	aim_dir = aim_dir.rotated(up, -rel.x).normalized()
	var new_dir := aim_dir.rotated(right, -rel.y).normalized()
	if absf(new_dir.dot(up)) < 0.98:
		aim_dir = new_dir


func _reset_aim() -> void:
	var v := get_vehicle()
	if v:
		aim_dir = -v.global_transform.basis.z
		var a := v as Aircraft
		if a and a.telemetry().on_ground:
			# Am Boden zeigt die Nase ~12° hoch (Spornrad): Ziel auf leicht über Horizont legen.
			aim_dir.y = 0.0
			aim_dir = (aim_dir.normalized() + Vector3.UP * 0.1).normalized()


## Fahrwerkshebel umlegen. Am Boden (Gewicht auf den Rädern) wird Einfahren verweigert.
func toggle_gear() -> bool:
	var a := get_vehicle() as Aircraft
	if gear_down and a != null and a.flight.gear.has_weight_on_wheels():
		gear_toggled.emit(gear_down, false)
		return false
	gear_down = not gear_down
	gear_toggled.emit(gear_down, true)
	return true


func reset_state(t: float = 0.0, gear: bool = true) -> void:
	throttle = t
	flap_index = 0
	gear_down = gear
	parking_brake = t < PARK_RELEASE_THROTTLE
	_kb = Vector3.ZERO
	_eject_t = 0.0
	eject_hold_progress = 0.0
	_reset_aim()


func compute_intent(dt: float) -> PilotIntent:
	var i := _intent
	# Tastatur: digitale Tasten mit Rampe glätten
	var kb_target := Vector3(
		Input.get_action_strength("kb_pitch_up") - Input.get_action_strength("kb_pitch_down"),
		Input.get_action_strength("kb_roll_right") - Input.get_action_strength("kb_roll_left"),
		Input.get_action_strength("kb_yaw_right") - Input.get_action_strength("kb_yaw_left"))
	_kb = _kb.move_toward(kb_target, KEY_RAMP * dt)
	# Gamepad: Deadzone in der InputMap, hier weiche Kurve
	var joy := Vector3(
		InputBindings.soft_curve(Input.get_axis("joy_pitch_down", "joy_pitch_up")),
		InputBindings.soft_curve(Input.get_axis("joy_roll_left", "joy_roll_right")),
		0.0)   # M2: Seitenruder am Pad über LB/RB (kb_yaw_*, mit Rampe)
	var manual := _kb + joy
	var look := Vector2(Input.get_axis("look_right", "look_left"), Input.get_axis("look_down", "look_up"))
	if look.length() > 0.0:
		look_offset = look_offset.lerp(Vector2(look.x * 2.6, look.y * 1.2) / zoom_mul(), 1.0 - exp(-8.0 * dt))
	elif not Input.is_action_pressed("mouse_look") and not mouse_aim_active():
		look_offset = look_offset.lerp(Vector2.ZERO, 1.0 - exp(-3.0 * dt))

	var stick := manual
	var v := get_vehicle() as Aircraft
	if mouse_aim_active() and v != null:
		if manual.length() > 0.05:
			_manual_override_t = 0.4
		_manual_override_t -= dt
		if _manual_override_t > 0.0:
			_reset_aim()
		else:
			var b := v.global_transform.basis
			var s := Autopilot.steer_to_direction(b, aim_dir)
			var t := v.telemetry()
			if t.on_ground:
				# Am Boden: nicht nach vorn drücken (Spornrad -> Überschlag), Flügel waagerecht,
				# Richtung über Seitenruder/Heckrad zur Maus hin.
				s.x = clampf(s.x, -0.1, 1.0)
				s.y = clampf(b.x.y * 2.5, -1.0, 1.0)
				s.z = Autopilot.hold_heading(b, -t.angular_velocity_local.y, aim_dir)
			stick = Vector3(s.x, s.y, s.z if t.on_ground else 0.0) + Vector3(0, 0, manual.z)
		if not Input.is_action_pressed("mouse_look"):
			look_offset = look_offset.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * dt))
	elif v != null:
		aim_dir = -v.global_transform.basis.z

	throttle = clampf(throttle + (Input.get_action_strength("throttle_up")
		- Input.get_action_strength("throttle_down")) * THROTTLE_RATE * dt, 0.0, 1.0)
	i.pitch = stick.x
	i.roll = stick.y
	i.yaw = stick.z
	i.throttle = throttle
	i.flaps = FLAP_STEPS[flap_index]
	var b_key := Input.get_action_strength("brakes")
	if parking_brake and (throttle > PARK_RELEASE_THROTTLE or b_key > 0.5):
		parking_brake = false
	# M2.1: In der Luft gibt es keine Parkbremse (sonst blockierte Räder bei der Landung).
	if parking_brake and v != null and not v.telemetry().on_ground and v.telemetry().height_agl > 5.0:
		parking_brake = false
	i.brakes = maxf(b_key, 1.0 if parking_brake else 0.0)
	i.gear_down = gear_down
	i.assist_mode = assist_mode
	# --- M2: Waffen und Notausstieg ---
	var lmb_ok := _lmb_fire and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	i.fire_primary = Input.is_action_pressed("fire_primary") or lmb_ok
	i.fire_secondary = Input.is_action_pressed("fire_secondary")
	_update_eject_hold(Input.is_action_pressed("eject_hold"), dt)
	i.eject = _eject_t >= InputBindings.EJECT_HOLD_TIME
	return i.clamp_values()


func _update_eject_hold(held: bool, dt: float) -> void:
	_eject_t = _eject_t + dt if held else 0.0
	var p := clampf(_eject_t / InputBindings.EJECT_HOLD_TIME, 0.0, 1.0)
	if p != eject_hold_progress:
		eject_hold_progress = p
		eject_hold_changed.emit(p)
