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

var mode := Mode.MAIN
var page := "start"
var list: MenuList
var help: GroundHelp
var root: Control
## Spiel (für sofort wirksame Einstellungen im Pausenmenü).
var game: Node = null


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


func _settings_items(f: int) -> void:
	var its: Array = []
	for o in GameSettings.OPTIONS:
		its.append({"id": o[0], "label": o[2], "option": true, "value": GameSettings.label_of(o[0])})
	its.append({"id": "back", "label": "Zurück",
		"note": "KI und Bodenbetrieb ab dem nächsten Start" if mode == Mode.PAUSE else "gilt beim Spielstart"})
	list.set_items("Einstellungen", its, f)


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
		return "zuletzt Schritt %d / 7" % (int(c.get_value("tutorial", "last_step", 0)) + 1)
	return "empfohlen für den Einstieg"


func _on_activated(id: String) -> void:
	match id:
		"tutorial": start_requested.emit(true)
		"free": start_requested.emit(false)
		"resume": resume_requested.emit()
		"settings": show_page("settings")
		"controls": show_page("controls")
		"back": show_page("start")
		"main_menu": main_menu_requested.emit()
		"tutorial_quit": tutorial_quit_requested.emit()
		"quit": get_tree().quit()


func _on_option(id: String, d: int) -> void:
	GameSettings.cycle(id, d)
	GameSettings.apply_runtime(game)
	_settings_items(list.focus)


func _on_cancel() -> void:
	if page != "start":
		show_page("start")
	elif mode == Mode.PAUSE:
		resume_requested.emit()


## Steuerungs-Seite: ◀ ▶ wechselt den Kontext, Zurück/Esc/B schließt.
func _input(event: InputEvent) -> void:
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
	list.position = Vector2(vs.x * 0.5 - MenuList.W * 0.5 * s, vs.y * 0.36)
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
		if menu.page == "controls":
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
