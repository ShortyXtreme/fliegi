class_name GameMenu
extends CanvasLayer
## Haupt- und Pausenmenü (M3.2). Seiten: Start (Haupt bzw. Pause), Einstellungen, Steuerung
## (F1-Tafel, ◀ ▶ wechselt Flug / Zu Fuß / Fahren). Haupt: Tutorial, Freies Spiel, Einstellungen,
## Steuerung, Beenden. Pause: Fortsetzen, Steuerung, Einstellungen, Zum Hauptmenü, Beenden.
## Läuft auch bei angehaltenem Spiel (PROCESS_MODE_ALWAYS).

signal resume_requested
signal start_requested(tutorial: bool)
signal main_menu_requested
## M3.3: Pausenmenü-Eintrag „Tutorial beenden“ (nur bei laufendem Tutorial)
signal tutorial_quit_requested

enum Mode { MAIN, PAUSE }

const GAME_SCENE := "res://world/main.tscn"
const MENU_SCENE := "res://ui/menu/main_menu.tscn"
const SETTINGS_W := 720.0

var mode := Mode.MAIN
var page := "start"
var list: MenuList
var help: GroundHelp
var root: Control
## Spiel (für sofort wirksame Einstellungen im Pausenmenü).
var game: Node = null
## M3.5 Tastenbelegung: Aktion, die auf eine Taste wartet ("" = keine), offener Konflikt.
var capture: StringName = &""
var pending := {}
const KEYS_W := 820.0


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = HudStyle.theme()
	add_child(root)
	var title := MenuTitle.new()
	title.menu = self
	root.add_child(title)
	list = MenuList.new()
	list.activated.connect(_on_activated)
	list.option_changed.connect(_on_option)
	list.cancelled.connect(_on_cancel)
	root.add_child(list)
	help = GroundHelp.new()
	help.context = InputBindings.Context.FLIGHT
	root.add_child(help)
	show_page("start")


func show_page(p: String) -> void:
	page = p
	help.visible = p == "controls"
	list.visible = p != "controls"
	match p:
		"start":
			if mode == Mode.MAIN:
				list.set_items("Hauptmenü", [
					{"id": "tutorial", "label": "Tutorial", "note": tutorial_note()},
					{"id": "free", "label": "Freies Spiel", "note": "Luftkampf + Bodenbetrieb"},
					{"id": "settings", "label": "Einstellungen"},
					{"id": "controls", "label": "Steuerung"},
					{"id": "quit", "label": "Beenden"}])
			else:
				list.set_items("Pause", [
					{"id": "resume", "label": "Fortsetzen"}] + _tutorial_items() + [
					{"id": "controls", "label": "Steuerung"},
					{"id": "settings", "label": "Einstellungen"},
					{"id": "main_menu", "label": "Zum Hauptmenü"},
					{"id": "quit", "label": "Beenden"}])
		"settings":
			_settings_items(0)
		"keys":
			_keys_items(1)


func _settings_items(f: int) -> void:
	var its: Array = []
	for o in GameSettings.OPTIONS:
		var it := {"id": o[0], "label": o[2], "option": true, "value": GameSettings.label_of(o[0])}
		if GameSettings.is_slider(o[0]):
			it["slider"] = GameSettings.slider_frac(o[0])
		its.append(it)
	its.append({"id": "keys", "label": "Tastenbelegung", "note": "Tastatur/Maus umbelegen"})
	its.append({"id": "back", "label": "Zurück",
		"note": "KI und Bodenbetrieb ab dem nächsten Start" if mode == Mode.PAUSE else "gilt beim Spielstart"})
	# M3.4: breite Liste, Beschriftung links (feste Spalte), Regler/Werte rechts
	list.set_items("Einstellungen", its, f, SETTINGS_W, 44.0, 300.0)


## M3.5: Seite Tastenbelegung – Gruppen Fliegen / Boden / Funk / Allgemein, Taste · Controller.
func _keys_items(f: int) -> void:
	var its: Array = []
	if not pending.is_empty():
		var names := ", ".join((pending.conflicts as Array).map(func(a): return "„%s“" % KeyRebind.label(a)))
		its.append({"id": "", "label": "Konflikt: %s ist schon belegt" % KeyGlyphs.event_token(pending.event), "header": true})
		its.append({"id": "", "label": "für %s" % names, "header": true})
		its.append({"id": "swap", "label": "Tauschen", "note": "„%s“ bekommt %s" % [KeyRebind.label(pending.action),
			KeyGlyphs.event_token(pending.event)]})
		its.append({"id": "swap_cancel", "label": "Abbrechen", "note": "Belegung bleibt"})
		list.set_items("Tastenbelegung – Konflikt", its, 2, KEYS_W, 44.0, 420.0)
		return
	for g in KeyRebind.groups():
		if (g[1] as Array).is_empty():
			continue
		its.append({"id": "", "label": g[0], "header": true})
		for a in g[1]:
			var waiting: bool = a == capture
			its.append({"id": "key:" + String(a), "label": KeyRebind.label(a), "keybind": true, "waiting": waiting,
				"value": "Taste drücken … (Esc: abbrechen)" if waiting else KeyRebind.display(a)})
	its.append({"id": "keys_default", "label": "Standard wiederherstellen"})
	its.append({"id": "keys_back", "label": "Zurück", "note": "Controller-Belegung: nur Anzeige"})
	list.set_items("Tastenbelegung", its, f, KEYS_W, 44.0, 420.0)


## Neue Taste für capture (Tastatur oder Maus). Rückgabe: Ereignis verbraucht.
func capture_event(ev: InputEvent) -> bool:
	if capture == &"" or not ev.is_pressed() or ev.is_echo():
		return false
	if not (ev is InputEventKey or (ev is InputEventMouseButton and ev.button_index != MOUSE_BUTTON_WHEEL_UP
			and ev.button_index != MOUSE_BUTTON_WHEEL_DOWN)):
		return false
	var a := capture
	capture = &""
	list.active = true
	if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_ESCAPE and a != &"release_mouse":
		_keys_items(list.focus)
		return true
	var c := KeyRebind.conflicts(a, ev)
	if c.is_empty():
		KeyRebind.assign(a, ev)
		_keys_items(list.focus)
	else:
		pending = {"action": a, "event": KeyRebind._clean(ev), "conflicts": c, "focus": list.focus}
		_keys_items(2)
	return true


func _tutorial_items() -> Array:
	var t = game.get("tutorial") if game != null else null
	if t != null and is_instance_valid(t) and t.active:
		return [{"id": "tutorial_quit", "label": "Tutorial beenden", "note": "Fortschritt bleibt gespeichert"}]
	return []


static func tutorial_note() -> String:
	var c := Tutorial.load_progress()
	if bool(c.get_value("tutorial", "completed", false)):
		return "abgeschlossen ✓"
	if c.has_section_key("tutorial", "last_step"):
		return "zuletzt Schritt %d / %d" % [int(c.get_value("tutorial", "last_step", 0)) + 1, Tutorial.STEP_COUNT]
	return "empfohlen für den Einstieg"


func _on_activated(id: String) -> void:
	if id.begins_with("key:"):
		capture = StringName(id.substr(4))
		list.active = false
		_keys_items(list.focus)
		return
	match id:
		"tutorial": start_requested.emit(true)
		"free": start_requested.emit(false)
		"resume": resume_requested.emit()
		"settings": show_page("settings")
		"keys": show_page("keys")
		"keys_back":
			show_page("settings")
		"keys_default":
			KeyRebind.restore_defaults()
			_keys_items(list.focus)
		"swap", "swap_cancel":
			if id == "swap":
				KeyRebind.assign(pending.action, pending.event, true)
			var f: int = pending.get("focus", 1)
			pending = {}
			_keys_items(f)
		"controls": show_page("controls")
		"back": show_page("start")
		"main_menu": main_menu_requested.emit()
		"tutorial_quit": tutorial_quit_requested.emit()
		"quit": get_tree().quit()


func _on_option(id: String, d: int) -> void:
	GameSettings.cycle(id, d)
	GameSettings.apply_runtime(game)
	if GameSettings.option(id)[1] == "anzeige":
		GameSettings.apply_display()
	_settings_items(list.focus)


func _on_cancel() -> void:
	if page == "keys":
		if not pending.is_empty():
			pending = {}
			_keys_items(1)
		else:
			show_page("settings")
		return
	if page != "start":
		show_page("start")
	elif mode == Mode.PAUSE:
		resume_requested.emit()


## Steuerungs-Seite: ◀ ▶ wechselt den Kontext, Zurück/Esc/B schließt.
func _input(event: InputEvent) -> void:
	if page == "keys" and capture_event(event):
		get_viewport().set_input_as_handled()
		return
	if mode == Mode.PAUSE and page == "start" and event is InputEventJoypadButton \
			and event.is_action_pressed("release_mouse"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
		return
	if page != "controls" or not visible:
		return
	var ctxs := [InputBindings.Context.FLIGHT, InputBindings.Context.CREW, InputBindings.Context.DRIVE]
	var d := 0
	if event.is_action_pressed("ui_left"):
		d = -1
	elif event.is_action_pressed("ui_right"):
		d = 1
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") \
			or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		show_page("start")
		return
	if d != 0:
		get_viewport().set_input_as_handled()
		help.context = ctxs[posmod(ctxs.find(help.context) + d, 3)]


func _process(_dt: float) -> void:
	var vs := root.get_viewport_rect().size
	var s := HudStyle.ui_scale(vs)
	list.scale = Vector2(s, s)
	var tall := page == "settings" or page == "keys"
	var top := vs.y * (0.1 if tall else 0.36)
	# M3.4: so viele Zeilen, wie in die Höhe passen (Rest scrollt)
	list.set_max_rows(int(floor(((vs.y - top) / s - 60.0 - MenuList.HEAD) / list.row)) if tall else 0)
	list.position = Vector2(vs.x * 0.5 - list.w * 0.5 * s, top)
	if mode == Mode.MAIN:
		list.position.x = 110.0 * s
	list.queue_redraw()


class MenuTitle extends Control:
	var menu: GameMenu

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var s := HudStyle.ui_scale(vs)
		if menu.mode == GameMenu.Mode.PAUSE:
			draw_rect(Rect2(Vector2.ZERO, vs), Color(HudStyle.BG.darkened(0.5), 0.6))
		else:
			# Abdunkelung links für Lesbarkeit über dem Hintergrundbild
			var c0 := Color(HudStyle.BG, 0.7)
			var c1 := Color(HudStyle.BG, 0.0)
			draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(vs.x * 0.7, 0), Vector2(vs.x * 0.7, vs.y),
				Vector2(0, vs.y)]), PackedColorArray([c0, c1, c1, c0]))
		if menu.page != "start":
			return
		var x := 110.0 * s if menu.mode == GameMenu.Mode.MAIN else vs.x * 0.5 - 230.0 * s
		var y := vs.y * 0.36 - 40.0 * s
		var f := HudStyle.display(true, true)
		draw_set_transform(Vector2(x, y), 0.0, Vector2(s, s))
		draw_string(f, Vector2(4, 4), "FLUGKERN", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color(0, 0, 0, 0.5))
		draw_string(f, Vector2.ZERO, "FLUGKERN", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, HudStyle.VALUE)
		var w := f.get_string_size("FLUGKERN", HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
		HudStyle.heading(self, Vector2(6, -96), "Luftkampf · späte 1930er", 13, HudStyle.ACCENT)
		HudStyle.text(self, Vector2(w + 14, 0), Hud.VERSION, 18, HudStyle.ACCENT, true)
		draw_set_transform(Vector2.ZERO)
		HudStyle.text(self, Vector2(vs.x - 24 * s, vs.y - 24 * s),
				"Maus · Pfeile + Enter · Stick + A / B", 13 * s, HudStyle.DIM, false, 2)
