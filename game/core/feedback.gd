class_name Feedback
extends CanvasLayer
## Feedback-Taste für Tester (F8, am Controller View halten + Y; Aktion "feedback_save",
## umbelegbar unter Einstellungen › Tastenbelegung). Ein Knoten an der Baumwurzel, überlebt
## Szenenwechsel, läuft auch bei Pause (Hauptmenü, Pausenmenü, Flug, zu Fuß, Fahren, Funk).
##
## Ablauf beim Drücken (das Spiel läuft weiter):
##  1. Zustand festhalten (FeedbackReport.collect, Ringpuffer einfrieren), Bildschirmfoto in voller
##     Auflösung nach dem nächsten Frame ohne eigene Einblendung.
##  2. Eingabefeld „Was ist los? …“. Solange es offen ist, bekommt das Spiel keine Eingabe:
##     dieser Knoten liegt zuletzt im Baum (erhält _input zuerst) und verbraucht jedes Ereignis,
##     zusätzlich sind alle Spiel-Aktionen aus der InputMap genommen (gegen Abfragen per
##     Input.is_action_pressed). ui_*-Aktionen bleiben.
##  3. Ordner <Spielordner>/feedback/<Datum_Uhrzeit>_<Text>/ (sonst user://feedback) mit
##     screenshot.png (im WorkerThreadPool), bericht.md, log.txt, telemetrie.csv.
##  4. Bestätigung „Feedback gespeichert: feedback/…“ für TOAST_S Sekunden (nie im nächsten Foto).

const ACTION := &"feedback_save"
const DEFAULT_KEY := KEY_F8
const PROMPT := "Was ist los? (Enter = speichern, Esc = ohne Text)"
## Controller: View (Back) halten, dann Y.
const PAD_HOLD := JOY_BUTTON_BACK
const PAD_PRESS := JOY_BUTTON_Y
const PAD_SPEC := "View Y"
const PAD_TEXT := "View halten + Y"
const TOAST_S := 4.0
const MAX_TEXT := 400
const SLUG_LEN := 32

enum State { IDLE, CAPTURE, TYPING }

## Tests/Werkzeuge: fester Zielordner (leer = Spielordner bzw. user://feedback).
static var base_dir_override := ""
static var instance: Feedback = null

## Laufende Partie (Game) oder null (Hauptmenü).
var game: Node = null
var recorder := FeedbackRecorder.new()
## Beim Drücken eingefrorene Kopie (Telemetrie, Bildrate, Ereignisse).
var frozen: FeedbackRecorder = null
var state := State.IDLE
var text := ""
var image: Image = null
var sections: Array = []
var log_lines: Array = []
var paused_at_press := false
var paused_during := false
var game_time := 0.0
var last_dir := ""
var last_files := PackedStringArray()
var toast_text := ""
var toast_left := 0.0

var _match_start_ms := 0
var _press_ms := 0
var _press_game_t := 0.0
var _saved_actions := {}
var _png_tasks: Array[int] = []
var _last_us := 0
var _help_before := {}
var _job_steps := {}
var _combat_bus: Object = null
var _ground_bus: Object = null
var _panel: FeedbackPanel
var _toast: FeedbackToast


## Knoten anlegen (einmal je Prozess), Logger anmelden. Darf aus _ready eines Szenenknotens
## kommen (fügt sich verzögert an die Wurzel).
static func ensure(tree: SceneTree) -> Feedback:
	FeedbackLog.install()
	if instance != null and is_instance_valid(instance):
		return instance
	instance = Feedback.new()
	instance.name = "Feedback"
	tree.root.add_child.call_deferred(instance)
	return instance


## Neue Partie: Spielzeit von vorn, Ringpuffer leeren, an Signale und Busse hängen.
static func attach_game(g: Node) -> Feedback:
	var fb := ensure(g.get_tree())
	fb._attach(g)
	return fb


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = FeedbackPanel.new()
	_panel.fb = self
	_panel.visible = false
	add_child(_panel)
	_toast = FeedbackToast.new()
	_toast.fb = self
	_toast.visible = false
	add_child(_toast)


func _ready() -> void:
	_match_start_ms = Time.get_ticks_msec()
	_last_us = Time.get_ticks_usec()


func _exit_tree() -> void:
	if state == State.TYPING:
		_restore_actions()
	wait_png()
	if instance == self:
		instance = null


func match_real_s() -> float:
	return (_press_ms if state != State.IDLE else Time.get_ticks_msec()) * 0.001 - _match_start_ms * 0.001


# --- Partie und Ereignisse ------------------------------------------------------------------------

func _attach(g: Node) -> void:
	game = g
	recorder.clear()
	game_time = 0.0
	_match_start_ms = Time.get_ticks_msec()
	_job_steps.clear()
	event("Partie gestartet (%s)" % ("Tutorial" if g.has_method("is_tutorial") and g.is_tutorial() else "Freies Spiel"))
	var cb := CombatEvents.bus()
	if cb != _combat_bus:
		_combat_bus = cb
		cb.hit_confirmed.connect(_on_hit)
		cb.aircraft_damaged.connect(_on_damaged)
		cb.aircraft_destroyed.connect(func(v, k, cause):
			event("Abschuss: %s%s (%s)" % [_n(v), " durch " + _n(k) if k != null and k != v else "",
				KillFeed.CAUSE_TEXT.get(cause, str(cause))]))
		cb.pilot_ejected.connect(func(a, _p): event("Notausstieg: %s" % _n(a)))
		cb.pilot_rescued.connect(func(_p, r): event("Pilot gerettet durch %s" % _n(r)))
	var gb := GroundEvents.bus()
	if gb != _ground_bus:
		_ground_bus = gb
		gb.job_added.connect(func(id, kind, target): event("Auftrag %d neu: %s an %s" % [id, kind, _n(target)]))
		gb.job_progress.connect(func(id, step, _p, worker):
			if _job_steps.get(id, &"") != step:
				_job_steps[id] = step
				event("Auftrag %d: Schritt %s (%s)" % [id, step, _n(worker)]))
		gb.job_done.connect(func(id, target):
			_job_steps.erase(id)
			event("Auftrag %d fertig: %s" % [id, _n(target)]))
		gb.job_blocked.connect(func(id, reason): event("Auftrag %d blockiert: %s" % [id, reason]))
		gb.turnaround.connect(func(a, sec, helpers): event("Abfertigung fertig: %s in %.0f s, %d Helfer" % [_n(a), sec, helpers]))
		gb.seat_changed.connect(func(peer, from_s, to_s): event("Sitzwechsel Spieler %d: %s → %s" % [peer, _seat(from_s), _seat(to_s)]))
		gb.alarm_started.connect(func(sec): event("Alarmstart: %.0f s" % sec))
		gb.alarm_ended.connect(func(ok): event("Alarm vorbei: %s" % ("geschafft" if ok else "nicht geschafft")))
	var s = g.get("session")
	if s != null and s.has_signal("context_changed"):
		s.context_changed.connect(func(ctx): event("Kontext: %s" % InputBindings.CONTEXT_NAMES.get(ctx, str(ctx))))
	var a = g.get("player_aircraft")
	if a != null:
		var ec := EngineControl.find(a)
		if ec != null:
			ec.message.connect(func(t, warn): event("Motor: %s%s" % [t, " (Warnung)" if warn else ""]))
			ec.phase_changed.connect(func(p): event("Motor-Phase: %s" % EngineControl.PHASE_NAMES[clampi(p, 0, 4)]))
	var sm = g.get("spawn_manager")
	if sm != null:
		sm.respawned.connect(func(n): event("Neue Maschine: %s" % _n(n)))
	_hook_hud.call_deferred(g)


## HUD-Teile entstehen in Game._ready nach den Signalen oben; Funk und Meldungen danach anhängen.
func _hook_hud(g: Node) -> void:
	if g == null or not is_instance_valid(g):
		return
	var hud = g.get("hud")
	if hud == null:
		return
	var combat = hud.get("combat")
	if combat != null and combat.get("kill_feed") != null:
		combat.kill_feed.entry_added.connect(func(t): event("Meldung: " + t))
	var gh = hud.get("ground_hud")
	if gh != null:
		for ch in gh.channels:
			var c: RadioChannel = ch
			c.answered.connect(func(t): event("Funk %s: %s" % [c.name, t]))
		if gh.radio != null:
			gh.radio.command_chosen.connect(func(ch, cmd): event("Funk an %s: %s" % [ch.name, cmd.label]))


func _on_hit(shooter: Node, target: Node, zone: int, dmg: float) -> void:
	var me = game.get("player_aircraft") if game != null and is_instance_valid(game) else null
	if shooter == me and me != null:
		event("Treffer gelandet: %s, Zone %s, %.1f" % [_n(target), _zone(zone), dmg])


func _on_damaged(a: Node, zone: int, dmg: float, attacker: Node) -> void:
	var me = game.get("player_aircraft") if game != null and is_instance_valid(game) else null
	if a == me and me != null:
		event("Schaden erhalten: Zone %s, %.1f, von %s" % [_zone(zone), dmg, _n(attacker)])


## Spielereignis in den Ringpuffer (log.txt).
func event(t: String) -> void:
	recorder.add_event(game_time, t)


static func _zone(z: int) -> String:
	return DamageModel.ZONE_NAMES[z] if z >= 0 and z < DamageModel.ZONE_NAMES.size() else str(z)


static func _n(n) -> String:
	if n == null or not is_instance_valid(n):
		return "–"
	return HudContacts.display_name(n)


static func _seat(s) -> String:
	if s == null or not is_instance_valid(s):
		return "–"
	return "%s/%s" % [_n(s.vehicle) if s.vehicle != null else "–", s.name]


# --- Takt -------------------------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if get_tree().paused:
		return
	game_time += dt
	if game != null and is_instance_valid(game):
		var a = game.get("player_aircraft")
		if a != null and is_instance_valid(a) and a.is_inside_tree():
			recorder.tick_telemetry(dt, game_time, a)
	elif game != null:
		game = null


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	recorder.tick_fps((now - _last_us) * 1e-6)
	_last_us = now
	if state == State.TYPING and get_tree().paused:
		paused_during = true
	if toast_left > 0.0:
		toast_left -= _dt
		if toast_left <= 0.0:
			_toast.visible = false
	for i in range(_png_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_png_tasks[i]):
			WorkerThreadPool.wait_for_task_completion(_png_tasks[i])
			_png_tasks.remove_at(i)


## Auf alle laufenden PNG-Speicherungen warten (Tests, Beenden).
func wait_png() -> void:
	for id in _png_tasks:
		WorkerThreadPool.wait_for_task_completion(id)
	_png_tasks.clear()


# --- Eingabe ----------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if state == State.TYPING:
		_typing_input(event)
		get_viewport().set_input_as_handled()
		return
	if state == State.CAPTURE:
		if _is_trigger(event):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.button_index == PAD_HOLD and event.pressed:
		_help_before = _help_state()
	if _is_trigger(event) and not _rebind_capturing():
		get_viewport().set_input_as_handled()
		trigger(event is InputEventJoypadButton)


## F8 (Belegung) oder am Controller Y bei gehaltener View-Taste.
func _is_trigger(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index == PAD_PRESS and Input.is_joy_button_pressed(event.device, PAD_HOLD)
	return InputMap.has_action(ACTION) and event.is_action_pressed(ACTION, false, true) and not event.is_echo()


## Tastenbelegung wartet gerade auf eine Taste: F8 dort nicht abfangen.
func _rebind_capturing() -> bool:
	var sc := get_tree().current_scene
	var menus := [sc.get("menu") if sc != null else null, game.get("pause_menu") if game != null and is_instance_valid(game) else null]
	for m in menus:
		if m is GameMenu and is_instance_valid(m) and (m as GameMenu).capture != &"":
			return true
	return false


func _typing_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var k := event as InputEventKey
		match k.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				finish(true)
				return
			KEY_ESCAPE:
				finish(false)
				return
			KEY_BACKSPACE:
				text = text.substr(0, maxi(text.length() - 1, 0))
				return
		if k.unicode >= 32 and not k.ctrl_pressed and not k.meta_pressed and text.length() < MAX_TEXT:
			text += char(k.unicode)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			finish(true)
		elif event.button_index == JOY_BUTTON_B:
			finish(false)


## Alle Spiel-Aktionen aus der InputMap nehmen und lösen (Abfragen sehen nichts mehr).
func _suspend_actions() -> void:
	_saved_actions.clear()
	for a in InputMap.get_actions():
		if String(a).begins_with("ui_"):
			continue
		_saved_actions[a] = InputMap.action_get_events(a)
		InputMap.action_erase_events(a)
		Input.action_release(a)


func _restore_actions() -> void:
	for a in _saved_actions:
		if not InputMap.has_action(a):
			continue
		InputMap.action_erase_events(a)
		for e in _saved_actions[a]:
			InputMap.action_add_event(a, e)
	_saved_actions.clear()


## Sichtbarkeit der Hilfetafeln (View-Taste schaltet sie beim Drücken um; die Kombination
## View + Y stellt sie für das Foto zurück).
func _help_state() -> Dictionary:
	var out := {}
	var hud = game.get("hud") if game != null and is_instance_valid(game) else null
	if hud == null:
		return out
	for h in [hud.get("_help"), hud.ground_hud.get("help") if hud.get("ground_hud") != null else null]:
		if h != null and is_instance_valid(h):
			out[h] = (h as CanvasItem).visible
	return out


func _undo_pad_side_effects() -> void:
	for h in _help_before:
		if is_instance_valid(h):
			(h as CanvasItem).visible = _help_before[h]
	_help_before = {}
	var tut = game.get("tutorial") if game != null and is_instance_valid(game) else null
	if tut != null and is_instance_valid(tut) and tut.get("view_hold") != null:
		tut.view_hold = -2.0        # bis zum Loslassen gesperrt: kein Überspringen, keine Hilfe
		if tut.card != null and is_instance_valid(tut.card):
			tut.card.hold = 0.0


# --- Ablauf -------------------------------------------------------------------------------------------

## Feedback auslösen (Taste oder Test). Foto nach dem nächsten Frame, dann das Eingabefeld.
func trigger(from_pad := false) -> void:
	if state != State.IDLE:
		return
	state = State.CAPTURE
	_press_ms = Time.get_ticks_msec()
	_press_game_t = game_time
	paused_at_press = get_tree().paused
	paused_during = paused_at_press
	if from_pad:
		_undo_pad_side_effects()
	_toast.visible = false
	toast_left = 0.0
	_panel.visible = false
	frozen = recorder.freeze()
	frozen.add_event(game_time, "Feedback-Taste gedrückt")
	log_lines = FeedbackLog.instance.snapshot() if FeedbackLog.instance != null else []
	sections = FeedbackReport.collect(self)
	image = null
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var tex := get_viewport().get_texture()
		image = tex.get_image() if tex != null else null
	_open_input()


func _open_input() -> void:
	text = ""
	state = State.TYPING
	_suspend_actions()
	var p := get_parent()
	if p != null:
		p.move_child(self, -1)    # zuletzt im Baum = erhält _input zuerst
	_panel.visible = true


## Eingabe beenden und speichern (with_text false = Esc, ohne Text).
func finish(with_text: bool) -> String:
	if state != State.TYPING:
		return ""
	_panel.visible = false
	_restore_actions()
	if get_tree().paused:
		paused_during = true
	var dir := save(text if with_text else "")
	state = State.IDLE
	if dir != "":
		toast_text = "Feedback gespeichert: %s" % display_path(dir)
	else:
		toast_text = "Feedback konnte nicht gespeichert werden (siehe Log)"
	toast_left = TOAST_S
	_toast.visible = true
	return dir


# --- Speichern ----------------------------------------------------------------------------------------

## Zielordner: neben der .exe (exportiert, wenn beschreibbar), sonst user://feedback.
static func base_dir() -> String:
	if base_dir_override != "":
		return base_dir_override
	if OS.has_feature("template"):
		var d := OS.get_executable_path().get_base_dir().path_join("feedback")
		if _writable(d):
			return d
	return ProjectSettings.globalize_path("user://feedback")


static func _writable(d: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(d) != OK:
		return false
	var probe := d.path_join(".schreibtest")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.close()
	DirAccess.remove_absolute(probe)
	return true


## Anzeige: „feedback/<Ordner>/“ neben der .exe, sonst der volle Pfad.
static func display_path(dir: String) -> String:
	var exe_dir := OS.get_executable_path().get_base_dir()
	if OS.has_feature("template") and dir.begins_with(exe_dir):
		return dir.substr(exe_dir.length() + 1) + "/"
	return dir + "/"


## Kurzer Text für den Ordnernamen: Kleinbuchstaben, Umlaute ausgeschrieben, sonst „_“.
static func slug(t: String) -> String:
	var s := t.strip_edges().to_lower()
	for pair in [["ä", "ae"], ["ö", "oe"], ["ü", "ue"], ["ß", "ss"]]:
		s = s.replace(pair[0], pair[1])
	var out := ""
	for i in s.length():
		var c := s.unicode_at(i)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57)
		if ok:
			out += char(c)
		elif not out.ends_with("_") and out != "":
			out += "_"
		if out.length() >= SLUG_LEN:
			break
	out = out.trim_suffix("_")
	return out if out != "" else "ohne_text"


func save(t: String) -> String:
	var dt := Time.get_datetime_dict_from_system()
	var stamp := "%04d-%02d-%02d_%02d-%02d-%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	var base := base_dir()
	var dir := base.path_join(stamp + "_" + slug(t))
	var n := 2
	while DirAccess.dir_exists_absolute(dir):
		dir = base.path_join("%s_%s_%d" % [stamp, slug(t), n])
		n += 1
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		push_error("Feedback: Ordner %s nicht anlegbar" % dir)
		return ""
	var shot := "screenshot.png"
	var shot_note := shot
	if image != null and not image.is_empty():
		shot_note = "screenshot.png (%dx%d)" % [image.get_width(), image.get_height()]
		var img := image
		var path := dir.path_join(shot)
		_png_tasks.append(WorkerThreadPool.add_task(func(): img.save_png(path), false, "Feedback-PNG"))
	else:
		shot_note = "nicht verfügbar (%s)" % ("headless" if DisplayServer.get_name() == "headless" else "kein Bild")
	var meta := {
		"datum": "%04d-%02d-%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second],
		"ordner": display_path(dir), "screenshot": shot_note,
		"pause": "beim Drücken %s, während der Eingabe %s" % ["ja" if paused_at_press else "nein",
			"ja" if paused_during else "nein"],
	}
	last_files = PackedStringArray()
	_write(dir.path_join("bericht.md"), FeedbackReport.markdown(sections, t, meta))
	_write(dir.path_join("log.txt"), log_text(t))
	_write(dir.path_join("telemetrie.csv"), (frozen if frozen != null else recorder).telemetry_csv())
	recorder.add_event(game_time, "Feedback gespeichert: %s" % dir.get_file())
	last_dir = dir
	image = null
	print("Feedback gespeichert: %s" % dir)
	return dir


func _write(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Feedback: %s nicht schreibbar (%s)" % [path, error_string(FileAccess.get_open_error())])
		return
	f.store_string(content)
	f.close()
	last_files.append(path.get_file())


func log_text(t: String) -> String:
	var L := PackedStringArray()
	L.append("Flugkern %s – Feedback, Text: %s" % [Hud.VERSION, t if t != "" else "(ohne Text)"])
	L.append("Zeiten: Sekunden vor dem Tastendruck (−) bzw. Spielzeit der Partie")
	L.append("")
	L.append("== Godot-Log (letzte %.0f s: print, Fehler, Warnungen) ==" % FeedbackLog.WINDOW_S)
	if FeedbackLog.instance == null:
		L.append("(eigener Logger nicht aktiv)")
	for e in log_lines:
		L.append("[%7.1f s] %s" % [(int(e[0]) - _press_ms) / 1000.0, String(e[1])])
	if FeedbackLog.instance != null and FeedbackLog.instance.dropped > 0:
		L.append("(%d ältere Zeilen wegen Menge verworfen)" % FeedbackLog.instance.dropped)
	L.append("")
	L.append("== Spielereignisse (letzte %.0f s) ==" % FeedbackRecorder.WINDOW_S)
	var ev: Array = (frozen if frozen != null else recorder).recent_events()
	if ev.is_empty():
		L.append("(keine)")
	for e in ev:
		L.append("[%7.1f s | Spielzeit %s] %s" % [(int(e[0]) - _press_ms) / 1000.0,
			FeedbackReport._clock(float(e[1])), String(e[2])])
	return "\n".join(L) + "\n"


# --- Einblendungen ---------------------------------------------------------------------------------

class FeedbackPanel extends Control:
	var fb: Feedback
	var _blink := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(dt: float) -> void:
		if visible:
			_blink += dt
			queue_redraw()

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var s := HudStyle.ui_scale(vs)
		var w := 760.0
		var h := 118.0
		draw_set_transform(Vector2(vs.x * 0.5 - w * 0.5 * s, vs.y * 0.18), 0.0, Vector2(s, s))
		HudStyle.draw_panel(self, Rect2(0, 0, w, h))
		draw_rect(Rect2(1, 1, w - 2, h - 2), Color(HudStyle.BG, 0.6))
		HudStyle.heading(self, Vector2(22, 32), "Feedback", 15, HudStyle.ACCENT)
		HudStyle.text(self, Vector2(22 + HudStyle.text_width("FEEDBACK", 18, true) + 22, 32), Feedback.PROMPT, 16, HudStyle.LABEL)
		var box := Rect2(22, 50, w - 44, 46)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.35)
		sb.border_color = Color(HudStyle.ACCENT, 0.8)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		draw_style_box(sb, box)
		var t := fb.text if fb != null else ""
		var shown := t
		while shown.length() > 0 and HudStyle.text_width(shown, 19) > box.size.x - 30.0:
			shown = shown.substr(1)
		if shown.length() < t.length():
			shown = "…" + shown
		var tx := box.position.x + 12.0
		var tw := HudStyle.text(self, Vector2(tx, box.position.y + 30), shown, 19, HudStyle.VALUE)
		if fmod(_blink, 1.0) < 0.6:
			draw_rect(Rect2(tx + tw + 2, box.position.y + 11, 2, 25), HudStyle.ACCENT)
		draw_set_transform(Vector2.ZERO)


class FeedbackToast extends Control:
	var fb: Feedback

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(_dt: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		if fb == null:
			return
		var vs := get_viewport_rect().size
		var s := HudStyle.ui_scale(vs)
		var a := clampf(fb.toast_left / 0.5, 0.0, 1.0)
		var w := HudStyle.text_width(fb.toast_text, 16) + 44.0
		draw_set_transform(Vector2(vs.x * 0.5 - w * 0.5 * s, vs.y * 0.12), 0.0, Vector2(s, s))
		modulate.a = a
		HudStyle.draw_panel(self, Rect2(0, 0, w, 40))
		HudStyle.text(self, Vector2(22, 26), fb.toast_text, 16, HudStyle.VALUE)
		draw_set_transform(Vector2.ZERO)
