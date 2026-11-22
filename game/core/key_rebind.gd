class_name KeyRebind
extends RefCounted
## M3.5: Freie Tastenbelegung (Tastatur/Maus). Je Aktion wird die erste Tastatur-/Maus-Belegung
## („Haupttaste“) ersetzt; Controller-Belegung wird nur angezeigt. Gespeichert in user://flugkern.cfg,
## Abschnitt [tasten] (aktion = "key:<physical_keycode>" bzw. "mouse:<button>"); InputBindings.setup()
## lädt sie nach den Standardwerten. Konflikte: gleiche Taste in einem überlappenden Kontext
## (Funk-Kontexte überlappen mit Zu Fuß/Fahren, Kanal- und Befehlsliste nicht miteinander).

const SECTION := "tasten"

## Gruppen der Einstellungsseite: [Titel, [Aktionen]]. Nicht aufgeführte Aktionen mit Tastatur-
## Belegung hängt groups() je Kontext an.
const GROUPS := [
	["Fliegen", [&"kb_pitch_down", &"kb_pitch_up", &"kb_roll_left", &"kb_roll_right", &"kb_yaw_left",
		&"kb_yaw_right", &"throttle_up", &"throttle_down", &"engine_toggle", &"master_toggle", &"fuel_pump_toggle",
		&"magneto_toggle", &"starter_hold", &"flaps_cycle", &"gear_toggle",
		&"brakes", &"fire_primary", &"fire_secondary", &"zoom_hold", &"mouse_look", &"camera_next",
		&"eject_hold", &"assist_toggle", &"mouse_aim_toggle"]],
	["Boden", [&"crew_move_forward", &"crew_move_back", &"crew_move_left", &"crew_move_right", &"crew_sprint",
		&"crew_interact", &"crew_drop", &"crew_enter", &"crew_view_toggle", &"drive_throttle", &"drive_brake",
		&"drive_steer_left", &"drive_steer_right", &"drive_handbrake"]],
	["Funk", [&"crew_wheel", &"radio_channel_1", &"radio_channel_2", &"radio_channel_3", &"radio_channel_4",
		&"radio_cmd_1", &"radio_cmd_2", &"radio_cmd_3", &"radio_cmd_4", &"radio_back", &"radio_prev", &"radio_next"]],
	["Allgemein", [&"help_toggle", &"release_mouse", &"tutorial_skip", &"tutorial_quit"]],
]

const LABELS := {
	&"kb_pitch_down": "Nase runter", &"kb_pitch_up": "Nase hoch", &"kb_roll_left": "Rollen links",
	&"kb_roll_right": "Rollen rechts", &"kb_yaw_left": "Seitenruder links", &"kb_yaw_right": "Seitenruder rechts",
	&"throttle_up": "Gas mehr", &"throttle_down": "Gas weniger", &"engine_toggle": "Motor an/aus (Realistisch: Gemisch)",
	&"master_toggle": "Hauptschalter (Batterie)", &"fuel_pump_toggle": "Kraftstoffpumpe", &"magneto_toggle": "Zündung (Magnete)",
	&"starter_hold": "Anlasser (halten)",
	&"flaps_cycle": "Klappen", &"gear_toggle": "Fahrwerk", &"brakes": "Bremsen", &"fire_primary": "Feuer",
	&"fire_secondary": "Sekundärwaffe", &"zoom_hold": "Zielzoom (halten)", &"mouse_look": "Umsehen (halten)",
	&"camera_next": "Kamera", &"eject_hold": "Aussteigen / Notausstieg", &"assist_toggle": "Arcade / Realistisch",
	&"mouse_aim_toggle": "Maus-Zielsteuerung",
	&"crew_move_forward": "Gehen vor", &"crew_move_back": "Gehen zurück", &"crew_move_left": "Gehen links",
	&"crew_move_right": "Gehen rechts", &"crew_sprint": "Sprinten", &"crew_interact": "Interagieren",
	&"crew_drop": "Ablegen", &"crew_enter": "Einsteigen", &"crew_view_toggle": "Ego / Third-Person",
	&"drive_throttle": "Fahren: Gas", &"drive_brake": "Fahren: Bremse / rückwärts", &"drive_steer_left": "Fahren: links",
	&"drive_steer_right": "Fahren: rechts", &"drive_handbrake": "Fahren: Handbremse",
	&"crew_wheel": "Funkgerät öffnen / schließen", &"radio_channel_1": "Funk: Kanal 1", &"radio_channel_2": "Funk: Kanal 2",
	&"radio_channel_3": "Funk: Kanal 3", &"radio_channel_4": "Funk: Kanal 4", &"radio_cmd_1": "Funk: Befehl 1",
	&"radio_cmd_2": "Funk: Befehl 2", &"radio_cmd_3": "Funk: Befehl 3", &"radio_cmd_4": "Funk: Befehl 4",
	&"radio_back": "Funk: zurück", &"radio_prev": "Funk: Kanal zurück", &"radio_next": "Funk: Kanal weiter",
	&"help_toggle": "Hilfe", &"release_mouse": "Pausenmenü / Maus frei", &"tutorial_skip": "Tutorial: Schritt weiter",
	&"tutorial_quit": "Tutorial beenden", &"alarm_debug": "Alarmstart (Debug)", &"debug_toggle": "Debug",
	&"reset_runway": "Neustart Piste", &"reset_air": "Neustart Luft",
}

## Standard-Haupttasten (beim ersten setup() gemerkt): aktion -> InputEvent
static var _defaults := {}


static func label(action: StringName) -> String:
	return LABELS.get(action, String(action))


## Erste Tastatur-/Maus-Belegung der Aktion (oder null).
static func primary(action: StringName) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			return ev
	return null


static func pad_event(action: StringName) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			return ev
	return null


## Gruppen mit allen umbelegbaren Aktionen: [[Titel, [Aktionen]], …].
static func groups() -> Array:
	var out := []
	var listed := {}
	for g in GROUPS:
		var acts := (g[1] as Array).filter(func(a): return InputMap.has_action(a) and primary(a) != null)
		for a in acts:
			listed[a] = true
		out.append([g[0], acts])
	# übrige Tastatur-Aktionen (ohne ui_*) je Kontext anhängen
	for a in InputMap.get_actions():
		if String(a).begins_with("ui_") or listed.has(a) or primary(a) == null:
			continue
		var gi := 3
		if InputBindings.in_context(a, InputBindings.Context.FLIGHT) and not InputBindings.GLOBAL_ACTIONS.has(a):
			gi = 0
		elif InputBindings.in_context(a, InputBindings.Context.CREW) or InputBindings.in_context(a, InputBindings.Context.DRIVE):
			gi = 1
		(out[gi][1] as Array).append(a)
	return out


static func contexts_of(action: StringName) -> Array:
	var out := []
	for c in InputBindings.Context.values():
		if InputBindings.in_context(action, c):
			out.append(c)
	return out


static func _overlap(a: int, b: int) -> bool:
	if a == b:
		return true
	var C := InputBindings.Context
	var radio := [C.RADIO, C.RADIO_CMD]
	var ground := [C.CREW, C.DRIVE]
	return (radio.has(a) and ground.has(b)) or (radio.has(b) and ground.has(a))


static func same_event(x: InputEvent, y: InputEvent) -> bool:
	if x is InputEventKey and y is InputEventKey:
		var kx: int = x.physical_keycode if x.physical_keycode != 0 else x.keycode
		var ky: int = y.physical_keycode if y.physical_keycode != 0 else y.keycode
		return kx == ky
	if x is InputEventMouseButton and y is InputEventMouseButton:
		return x.button_index == y.button_index
	return false


## Aktionen, die ev in einem mit action überlappenden Kontext schon nutzen.
static func conflicts(action: StringName, ev: InputEvent) -> Array:
	var mine := contexts_of(action)
	var out := []
	for a in InputMap.get_actions():
		if a == action or String(a).begins_with("ui_"):
			continue
		var uses := false
		for e in InputMap.action_get_events(a):
			if same_event(e, ev):
				uses = true
		if not uses:
			continue
		for c in contexts_of(a):
			if mine.any(func(m): return _overlap(m, c)):
				out.append(a)
				break
	return out


static func _replace_primary(action: StringName, ev: InputEvent) -> void:
	var old := primary(action)
	if old != null:
		InputMap.action_erase_event(action, old)
	if ev != null:
		var evs := InputMap.action_get_events(action)
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, ev)
		for e in evs:
			InputMap.action_add_event(action, e)


## Belegen. swap = true: Konflikt-Aktionen bekommen die bisherige Taste von action (getauscht),
## sonst verlieren sie diese Taste. Speichert sofort.
static func assign(action: StringName, ev: InputEvent, swap := true, save_now := true) -> void:
	var old := primary(action)
	for c in conflicts(action, ev):
		for e in InputMap.action_get_events(c):
			if same_event(e, ev):
				InputMap.action_erase_event(c, e)
				if swap and old != null:
					_add_front(c, old.duplicate())
				_store(c)
	_replace_primary(action, _clean(ev))
	_store(action)
	if save_now:
		_flush()


static func _add_front(action: StringName, ev: InputEvent) -> void:
	var evs := InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, ev)
	for e in evs:
		InputMap.action_add_event(action, e)


## Nur Taste bzw. Maustaste übernehmen (ohne Zusatztasten/Zustand).
static func _clean(ev: InputEvent) -> InputEvent:
	if ev is InputEventKey:
		var k := InputEventKey.new()
		k.physical_keycode = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return k
	if ev is InputEventMouseButton:
		var m := InputEventMouseButton.new()
		m.button_index = ev.button_index
		return m
	return ev


static func encode(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return "key:%d" % (ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode)
	if ev is InputEventMouseButton:
		return "mouse:%d" % ev.button_index
	return ""


static func decode(s: String) -> InputEvent:
	var p := s.split(":")
	if p.size() != 2:
		return null
	if p[0] == "key":
		var k := InputEventKey.new()
		k.physical_keycode = int(p[1]) as Key
		return k
	if p[0] == "mouse":
		var m := InputEventMouseButton.new()
		m.button_index = int(p[1]) as MouseButton
		return m
	return null


static var _pending := {}


static func _store(action: StringName) -> void:
	var ev := primary(action)
	_pending[action] = encode(ev) if ev != null else ""


static func _flush() -> void:
	var c := ConfigFile.new()
	c.load(GameSettings.PATH)
	for a in _pending:
		c.set_value(SECTION, String(a), _pending[a])
	_pending.clear()
	c.save(GameSettings.PATH)


## Standardwerte merken (InputBindings.setup nach dem Anlegen).
static func remember_defaults() -> void:
	_defaults.clear()
	for a in InputMap.get_actions():
		var ev := primary(a)
		_defaults[a] = ev.duplicate() if ev != null else null


## Gespeicherte Belegung anwenden (InputBindings.setup).
static func load_saved(path := "") -> int:
	var c := ConfigFile.new()
	if c.load(path if path != "" else GameSettings.PATH) != OK or not c.has_section(SECTION):
		return 0
	var n := 0
	for k in c.get_section_keys(SECTION):
		var a := StringName(k)
		if not InputMap.has_action(a):
			continue
		var s := String(c.get_value(SECTION, k, ""))
		var old := primary(a)
		if s == "":
			if old != null:
				InputMap.action_erase_event(a, old)
			n += 1
			continue
		var ev := decode(s)
		if ev != null:
			_replace_primary(a, ev)
			n += 1
	return n


## Alle Haupttasten auf Standard zurück, gespeicherte Belegung löschen.
static func restore_defaults() -> void:
	for a in _defaults:
		if InputMap.has_action(a):
			_replace_primary(a, _defaults[a].duplicate() if _defaults[a] != null else null)
	var c := ConfigFile.new()
	c.load(GameSettings.PATH)
	if c.has_section(SECTION):
		c.erase_section(SECTION)
	c.save(GameSettings.PATH)


## Anzeige: „Tab · LB“ (Tastatur · Controller).
static func display(action: StringName) -> String:
	var k := primary(action)
	var p := pad_event(action)
	var s := KeyGlyphs.event_token(k) if k != null else "–"
	if p != null:
		s += "  ·  " + KeyGlyphs.event_token(p)
	return s
