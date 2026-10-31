class_name InputBindings
extends RefCounted
## Legt alle Eingabeaktionen im Code an (Tastatur, Maus, Xbox/XInput-Gamepad).
## So bleibt project.godot schlank und die Belegung ist an einer Stelle dokumentiert.
## Digitale Achsen-Aktionen beginnen mit "kb_" (Tastatur und Schultertasten, mit Rampe),
## Gamepad-Achsen mit "joy_" (Deadzone + Expo-Kurve).
##
## M2 (Paket 0, Entscheidung 1 vom 31.10.2026), Xbox-Layout:
##   RT = Feuer primär, LT = Feuer sekundär, LB/RB = Seitenruder (digital mit Rampe),
##   Steuerkreuz ↑/↓ = Gas mehr/weniger (halten), Steuerkreuz → = Fahrwerk,
##   Steuerkreuz ← 1 s halten = Notausstieg.
## Tastatur/Maus: Leertaste oder LMT (nur bei gefangener Maus) = Feuer, V oder MMT =
##   Sekundär, J 1 s halten = Notausstieg.
## Jede Taste/jeder Knopf gehört höchstens einer Aktion (Test test_binding_conflicts).

const STICK_DEADZONE := 0.15
const TRIGGER_DEADZONE := 0.08
## Abzug: ab diesem Weg gilt der Trigger als gedrückt.
const FIRE_TRIGGER_THRESHOLD := 0.35
## So lange muss "eject_hold" gehalten werden (s).
const EJECT_HOLD_TIME := 1.0


static var _done := false


static func setup() -> void:
	if _done:
		return
	_done = true
	# --- Tastatur: Flugsteuerung ---
	_keys("kb_pitch_down", [KEY_W, KEY_UP])      # Knüppel nach vorn = Nase runter
	_keys("kb_pitch_up", [KEY_S, KEY_DOWN])      # Knüppel ziehen = Nase hoch
	_keys("kb_roll_left", [KEY_A, KEY_LEFT])
	_keys("kb_roll_right", [KEY_D, KEY_RIGHT])
	_keys("kb_yaw_left", [KEY_Q])
	_keys("kb_yaw_right", [KEY_E])
	_keys("throttle_up", [KEY_SHIFT])
	_keys("throttle_down", [KEY_CTRL])
	_keys("flaps_cycle", [KEY_F])
	_keys("brakes", [KEY_B])
	_keys("gear_toggle", [KEY_G])
	_keys("camera_next", [KEY_C])
	_keys("assist_toggle", [KEY_X])
	_keys("mouse_aim_toggle", [KEY_M])
	_keys("help_toggle", [KEY_F1])
	_keys("debug_toggle", [KEY_F3])
	_keys("reset_runway", [KEY_R])
	_keys("reset_air", [KEY_T])
	_keys("release_mouse", [KEY_ESCAPE])
	# --- M2: Waffen und Notausstieg ---
	_keys("fire_primary", [KEY_SPACE])
	_keys("fire_secondary", [KEY_V])
	_keys("eject_hold", [KEY_J])

	# --- Gamepad (Xbox-Layout, SDL/XInput) ---
	_axis("joy_pitch_down", JOY_AXIS_LEFT_Y, -1.0, STICK_DEADZONE)  # Stick nach vorn
	_axis("joy_pitch_up", JOY_AXIS_LEFT_Y, 1.0, STICK_DEADZONE)
	_axis("joy_roll_left", JOY_AXIS_LEFT_X, -1.0, STICK_DEADZONE)
	_axis("joy_roll_right", JOY_AXIS_LEFT_X, 1.0, STICK_DEADZONE)
	_axis("fire_primary", JOY_AXIS_TRIGGER_RIGHT, 1.0, FIRE_TRIGGER_THRESHOLD)   # M2: RT
	_axis("fire_secondary", JOY_AXIS_TRIGGER_LEFT, 1.0, FIRE_TRIGGER_THRESHOLD)  # M2: LT
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0, STICK_DEADZONE)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0, STICK_DEADZONE)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0, STICK_DEADZONE)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0, STICK_DEADZONE)
	_button("kb_yaw_left", JOY_BUTTON_LEFT_SHOULDER)     # M2: LB/RB = Seitenruder
	_button("kb_yaw_right", JOY_BUTTON_RIGHT_SHOULDER)
	_button("throttle_up", JOY_BUTTON_DPAD_UP)
	_button("throttle_down", JOY_BUTTON_DPAD_DOWN)       # M2: war Fahrwerk (M1.1)
	_button("gear_toggle", JOY_BUTTON_DPAD_RIGHT)        # M2: Steuerkreuz rechts
	_button("eject_hold", JOY_BUTTON_DPAD_LEFT)          # M2: 1 s halten
	_button("flaps_cycle", JOY_BUTTON_A)
	_button("brakes", JOY_BUTTON_B)
	_button("camera_next", JOY_BUTTON_Y)
	_button("assist_toggle", JOY_BUTTON_X)
	_button("help_toggle", JOY_BUTTON_BACK)
	_button("reset_runway", JOY_BUTTON_START)
	_button("look_reset", JOY_BUTTON_RIGHT_STICK)

	# --- Maus ---
	# LMT ist bewusst KEINE Aktion: erster Klick fängt die Maus, erst danach feuert sie
	# (PlayerController._unhandled_input).
	_mouse("mouse_look", MOUSE_BUTTON_RIGHT)
	_mouse("fire_secondary", MOUSE_BUTTON_MIDDLE)
	_mouse("zoom_in", MOUSE_BUTTON_WHEEL_UP)
	_mouse("zoom_out", MOUSE_BUTTON_WHEEL_DOWN)


static func _ensure(action: StringName, deadzone: float = 0.2) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	else:
		InputMap.action_set_deadzone(action, deadzone)


static func _keys(action: StringName, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


static func _button(action: StringName, button: JoyButton) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	InputMap.action_add_event(action, ev)


static func _axis(action: StringName, axis: JoyAxis, dir: float, deadzone: float) -> void:
	_ensure(action, deadzone)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	ev.device = -1
	InputMap.action_add_event(action, ev)


static func _mouse(action: StringName, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


## Weiche Eingangskurve für Analogachsen (Wert ist bereits deadzone-bereinigt).
static func soft_curve(x: float, expo: float = 0.45) -> float:
	return (1.0 - expo) * x + expo * x * x * x
