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
## Jede Taste/jeder Knopf gehört je Kontext höchstens einer Aktion (Test test_binding_conflicts).
##
## M3 (Paket 0a): Eingabe-Kontexte. Welcher gilt, entscheidet PlayerSession je nach
## besetztem Sitz (Flugzeug = FLIGHT, Figur = CREW, Fahrzeug = DRIVE). Dieselbe Taste darf
## in verschiedenen Kontexten verschiedene Aktionen haben, innerhalb eines Kontexts
## (inkl. GLOBAL) nie. Belegung:
##   FLIGHT wie M2. J / Steuerkreuz ← 1 s halten = am Boden im Stand Aussteigen
##          (PlayerController.exit_on_ground), in der Luft weiterhin Notausstieg.
##   CREW   WASD / linker Stick gehen, Maus / rechter Stick Blick, Shift / L3 Sprint,
##          E / A halten = Interagieren, G / B = Ablegen, F / Y = Einsteigen,
##          Tab / LB halten = Befehlsrad (Maus oder rechter Stick wählt), C / R3 = Ego/Third.
##   DRIVE  W / RT Gas, S / LT Bremse+Rückwärts, A D / linker Stick Lenkung, Leertaste / B
##          Handbremse, J / Steuerkreuz ← 1 s halten = Aussteigen (im Stand),
##          E / A = Interagieren (z. B. Schlauchtrommel), Tab / LB = Befehlsrad, C / Y = Kamera.
##   GLOBAL F1 / Back = Hilfe, Esc = Maus freigeben.

const STICK_DEADZONE := 0.15
const TRIGGER_DEADZONE := 0.08
## Abzug: ab diesem Weg gilt der Trigger als gedrückt.
const FIRE_TRIGGER_THRESHOLD := 0.35
## So lange muss "eject_hold" gehalten werden (s).
const EJECT_HOLD_TIME := 1.0


enum Context { FLIGHT, CREW, DRIVE }

## In allen Kontexten aktiv.
const GLOBAL_ACTIONS: Array[StringName] = [&"help_toggle", &"release_mouse", &"alarm_debug"]
## Aktionen je Kontext (ohne GLOBAL). Neue Aktionen MÜSSEN hier eingetragen werden
## (test_every_action_in_context).
const CONTEXT_ACTIONS := {
	Context.FLIGHT: [&"kb_pitch_down", &"kb_pitch_up", &"kb_roll_left", &"kb_roll_right",
		&"kb_yaw_left", &"kb_yaw_right", &"throttle_up", &"throttle_down", &"flaps_cycle",
		&"brakes", &"gear_toggle", &"camera_next", &"assist_toggle", &"mouse_aim_toggle",
		&"debug_toggle", &"reset_runway", &"reset_air", &"fire_primary", &"fire_secondary",
		&"eject_hold", &"zoom_hold", &"mouse_look", &"joy_pitch_down", &"joy_pitch_up",
		&"joy_roll_left", &"joy_roll_right", &"look_left", &"look_right", &"look_up",
		&"look_down", &"zoom_in", &"zoom_out"],
	Context.CREW: [&"crew_move_forward", &"crew_move_back", &"crew_move_left",
		&"crew_move_right", &"joy_crew_move_forward", &"joy_crew_move_back",
		&"joy_crew_move_left", &"joy_crew_move_right", &"crew_sprint", &"crew_interact",
		&"crew_drop", &"crew_enter", &"crew_wheel", &"crew_view_toggle", &"look_left",
		&"look_right", &"look_up", &"look_down"],
	Context.DRIVE: [&"drive_throttle", &"drive_brake", &"drive_steer_left",
		&"drive_steer_right", &"joy_drive_steer_left", &"joy_drive_steer_right",
		&"drive_handbrake", &"eject_hold", &"crew_interact", &"crew_wheel", &"camera_next",
		&"look_left", &"look_right", &"look_up", &"look_down"],
}
const CONTEXT_NAMES := {Context.FLIGHT: "Flug", Context.CREW: "Zu Fuß", Context.DRIVE: "Fahren"}
## Aussteigen im Stand (FLIGHT/DRIVE) nutzt dieselbe Haltezeit wie der Notausstieg.
const EXIT_HOLD_TIME := EJECT_HOLD_TIME


static var _done := false


## Alle Aktionen, die in Kontext ctx gelten (inkl. GLOBAL).
static func actions_for(ctx: int) -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(GLOBAL_ACTIONS)
	for a in CONTEXT_ACTIONS.get(ctx, []):
		if not out.has(a):
			out.append(a)
	return out


## Gehört die Aktion zum Kontext (oder ist global)?
static func in_context(action: StringName, ctx: int) -> bool:
	return GLOBAL_ACTIONS.has(action) or (CONTEXT_ACTIONS.get(ctx, []) as Array).has(action)


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
	_keys("alarm_debug", [KEY_F9])                       # M3: Alarmstart sofort (Debug)
	_keys("reset_runway", [KEY_R])
	_keys("reset_air", [KEY_T])
	_keys("release_mouse", [KEY_ESCAPE])
	# --- M2: Waffen und Notausstieg ---
	_keys("fire_primary", [KEY_SPACE])
	_keys("fire_secondary", [KEY_V])
	_keys("eject_hold", [KEY_J])
	# --- M2.1: Ziel-Zoom (halten) und Umsehen ---
	_keys("zoom_hold", [KEY_Z])
	_keys("mouse_look", [KEY_ALT])                       # Umsehen mit der Maus (war RMT)

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
	_button("zoom_hold", JOY_BUTTON_RIGHT_STICK)         # M2.1: R3 halten = Zoom (war Blick zurück)
	_button("debug_toggle", JOY_BUTTON_LEFT_STICK)       # M2.1: L3 = Treffer-Debug
	_button("debug_toggle", JOY_BUTTON_MISC1)            # M2.1: Share-Taste (Series X|S)

	# --- M3: Kontext CREW (zu Fuß) ---
	_keys("crew_move_forward", [KEY_W])
	_keys("crew_move_back", [KEY_S])
	_keys("crew_move_left", [KEY_A])
	_keys("crew_move_right", [KEY_D])
	_axis("joy_crew_move_forward", JOY_AXIS_LEFT_Y, -1.0, STICK_DEADZONE)
	_axis("joy_crew_move_back", JOY_AXIS_LEFT_Y, 1.0, STICK_DEADZONE)
	_axis("joy_crew_move_left", JOY_AXIS_LEFT_X, -1.0, STICK_DEADZONE)
	_axis("joy_crew_move_right", JOY_AXIS_LEFT_X, 1.0, STICK_DEADZONE)
	_keys("crew_sprint", [KEY_SHIFT])
	_button("crew_sprint", JOY_BUTTON_LEFT_STICK)
	_keys("crew_interact", [KEY_E])                      # halten
	_button("crew_interact", JOY_BUTTON_A)
	_keys("crew_drop", [KEY_G])
	_button("crew_drop", JOY_BUTTON_B)
	_keys("crew_enter", [KEY_F])
	_button("crew_enter", JOY_BUTTON_Y)
	_keys("crew_wheel", [KEY_TAB])                       # halten = Befehlsrad
	_button("crew_wheel", JOY_BUTTON_LEFT_SHOULDER)
	_keys("crew_view_toggle", [KEY_C])                   # Ego/Third
	_button("crew_view_toggle", JOY_BUTTON_RIGHT_STICK)
	# --- M3: Kontext DRIVE (Tankwagen, Munitionswagen) ---
	_keys("drive_throttle", [KEY_W])
	_axis("drive_throttle", JOY_AXIS_TRIGGER_RIGHT, 1.0, TRIGGER_DEADZONE)
	_keys("drive_brake", [KEY_S])                        # im Stand: rückwärts
	_axis("drive_brake", JOY_AXIS_TRIGGER_LEFT, 1.0, TRIGGER_DEADZONE)
	_keys("drive_steer_left", [KEY_A])
	_keys("drive_steer_right", [KEY_D])
	_axis("joy_drive_steer_left", JOY_AXIS_LEFT_X, -1.0, STICK_DEADZONE)
	_axis("joy_drive_steer_right", JOY_AXIS_LEFT_X, 1.0, STICK_DEADZONE)
	_keys("drive_handbrake", [KEY_SPACE])
	_button("drive_handbrake", JOY_BUTTON_B)
	# eject_hold (J / Steuerkreuz ←), crew_interact, crew_wheel, camera_next: siehe oben

	# --- Maus ---
	# LMT ist bewusst KEINE Aktion: erster Klick fängt die Maus, erst danach feuert sie
	# (PlayerController._unhandled_input).
	_mouse("zoom_hold", MOUSE_BUTTON_RIGHT)              # M2.1: RMT halten = Zoom
	_mouse("mouse_look", MOUSE_BUTTON_XBUTTON1)          # Maustaste 4 = Umsehen
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
