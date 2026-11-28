extends TestSuite
## Feedback-Taste (core/feedback.gd): Ordner mit bericht.md (Pflichtfelder), log.txt, telemetrie.csv;
## headless ohne Bild sauber; Taste in der Belegung und umbelegbar; Eingabefeld sperrt das Spiel;
## Ringpuffer auf 60 s begrenzt.

var _dir := ""


func before_each() -> void:
	_dir = ProjectSettings.globalize_path("user://feedback_test")
	_rm(_dir)
	Feedback.base_dir_override = _dir


func after_each() -> void:
	Feedback.base_dir_override = ""
	_rm(_dir)


static func _rm(d: String) -> void:
	if not DirAccess.dir_exists_absolute(d):
		return
	var da := DirAccess.open(d)
	for f in da.get_files():
		DirAccess.remove_absolute(d.path_join(f))
	for sub in da.get_directories():
		_rm(d.path_join(sub))
	DirAccess.remove_absolute(d)


func _fb() -> Feedback:
	var fb := Feedback.ensure(get_tree())
	if not fb.is_inside_tree():
		await get_tree().process_frame
	return fb


static func _key(keycode: Key, uni := 0, physical: Key = KEY_NONE, pressed := true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = keycode
	e.physical_keycode = physical
	e.unicode = uni
	e.pressed = pressed
	return e


func _type(s: String) -> void:
	for i in s.length():
		Input.parse_input_event(_key(KEY_NONE, s.unicode_at(i)))
	await _step(2)


static func _read(p: String) -> String:
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


func test_feedback_saves_report() -> Array:
	InputBindings.setup()
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	await _step(40)
	var fb := await _fb()
	var attached := fb.game == g
	print("FEEDBACK-TESTMARKE im Log")
	var gear_before: bool = g.player_aircraft.telemetry().gear_down_cmd
	fb.trigger()
	await _step(1)
	var typing := fb.state == Feedback.State.TYPING and fb._panel.visible
	await _type("Motor stottert ")
	# Spieltasten während der Eingabe: W (Nase runter, abgefragt) und G (Fahrwerk, Ereignis)
	Input.parse_input_event(_key(KEY_W, "w".unicode_at(0), KEY_W))
	Input.parse_input_event(_key(KEY_G, "g".unicode_at(0), KEY_G))
	await _step(3)
	var blocked := not Input.is_action_pressed(&"kb_pitch_down") and InputMap.action_get_events(&"kb_pitch_down").is_empty() \
		and g.player_aircraft.telemetry().gear_down_cmd == gear_before and g.pause_menu == null
	var typed := fb.text
	Input.parse_input_event(_key(KEY_W, 0, KEY_W, false))
	Input.parse_input_event(_key(KEY_G, 0, KEY_G, false))
	Input.parse_input_event(_key(KEY_ENTER))
	await _step(2)
	fb.wait_png()
	var restored := not InputMap.action_get_events(&"kb_pitch_down").is_empty() and fb.state == Feedback.State.IDLE
	var dir := fb.last_dir
	var md := _read(dir.path_join("bericht.md"))
	var log := _read(dir.path_join("log.txt"))
	var csv := _read(dir.path_join("telemetrie.csv"))
	var need := ["Version", Hud.VERSION, "Datum", "Motor stottert wg", "**Kontext:** Flug", "**Szene:**",
		"**Steuerungsmodus:**", "**Realismusstufe:**", "## Einstellungen", "Vegetation:", "Wind:", "g-Effekte",
		"Funk-Klang:", "## Bildrate", "Mittel der letzten 60 s", "Minimum", "## Hardware", "Betriebssystem:",
		"Grafikkarte:", "Treiber:", "CPU:", "Auflösung:", "Spielzeit seit Partiestart", "## Spielerflugzeug",
		"Position:", "über NN", "über Grund", "IAS", "TAS", "Lage:", "g-Last:", "Motor: Gas", "Drehzahl",
		"Kühlmittel", "Treibstoff:", "Munition:", "Schadenszonen:", "Wind am Ort:", "## In der Nähe",
		"Spiel pausiert:** beim Drücken nein", "Screenshot:** nicht verfügbar (headless)"]
	var missing := need.filter(func(x): return not md.contains(x))
	var rows := csv.strip_edges().split("\n")
	var csv_ok := rows.size() >= 3 and rows[0].begins_with("zeit_s;x_m;y_m;z_m;hoehe_nn_m") \
		and rows[1].split(";").size() == FeedbackRecorder.NC
	var log_ok := log.contains("== Godot-Log") and log.contains("FEEDBACK-TESTMARKE") \
		and log.contains("== Spielereignisse") and log.contains("Partie gestartet") and log.contains("Feedback-Taste gedrückt")
	var name_ok := dir.get_file().ends_with("_motor_stottert_wg") and dir.begins_with(_dir)
	var no_png := not FileAccess.file_exists(dir.path_join("screenshot.png"))
	var toast := fb._toast.visible and fb.toast_text.begins_with("Feedback gespeichert: ")
	g.queue_free()
	await _step(2)
	var ok: bool = attached and typing and blocked and typed == "Motor stottert wg" and restored and missing.is_empty() \
		and csv_ok and log_ok and name_ok and no_png and toast
	return [ok, "Partie %s, Feld %s, gesperrt %s, Text „%s“, frei %s, fehlt %s, CSV %d Zeilen %s, Log %s, Ordner %s, ohne PNG %s, Hinweis %s" % [
		attached, typing, blocked, typed, restored, str(missing), rows.size(), csv_ok, log_ok, dir.get_file(), no_png, toast]]


func test_feedback_binding_and_pad() -> Array:
	InputBindings.setup()
	KeyRebind.restore_defaults()
	var global := InputBindings.GLOBAL_ACTIONS.has(Feedback.ACTION)
	var f8 := KeyGlyphs.token(Feedback.ACTION, false) == "F8"
	var listed := false
	for gr in KeyRebind.groups():
		if gr[0] == "Allgemein" and (gr[1] as Array).has(Feedback.ACTION):
			listed = true
	var shown := KeyRebind.display(Feedback.ACTION).contains(Feedback.PAD_TEXT)
	var tut_moved := KeyGlyphs.token(&"tutorial_skip", false) == "F6"
	# einmal je Hilfetafel, in allen drei Kontexten
	var once := true
	for ctx in [InputBindings.Context.FLIGHT, InputBindings.Context.CREW, InputBindings.Context.DRIVE]:
		var n := GroundHelp.help_rows(ctx).filter(func(r): return String(r[0]).begins_with("Feedback")).size()
		once = once and n == 1
	# umbelegen auf F10 (frei) und zurück
	var free := KeyRebind.conflicts(Feedback.ACTION, _key(KEY_NONE, 0, KEY_F10)).is_empty()
	KeyRebind.assign(Feedback.ACTION, _key(KEY_NONE, 0, KEY_F10))
	var rebound := KeyGlyphs.token(Feedback.ACTION, false) == "F10"
	var fb := await _fb()
	fb.game = null
	Input.parse_input_event(_key(KEY_F8, 0, KEY_F8))
	await _step(2)
	var old_ignored := fb.state == Feedback.State.IDLE
	Input.parse_input_event(_key(KEY_F8, 0, KEY_F8, false))
	KeyRebind.restore_defaults()
	var back := KeyGlyphs.token(Feedback.ACTION, false) == "F8"
	# Controller: View halten + Y
	var jb := func(b: JoyButton, p: bool) -> InputEventJoypadButton:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = p
		e.device = 0
		return e
	Input.parse_input_event(jb.call(JOY_BUTTON_BACK, true))
	await _step(1)
	Input.parse_input_event(jb.call(JOY_BUTTON_Y, true))
	await _step(2)
	var pad := fb.state == Feedback.State.TYPING
	Input.parse_input_event(jb.call(JOY_BUTTON_Y, false))
	Input.parse_input_event(jb.call(JOY_BUTTON_BACK, false))
	Input.parse_input_event(_key(KEY_ESCAPE))       # ohne Text
	await _step(2)
	fb.wait_png()
	var dir := fb.last_dir
	var md := _read(dir.path_join("bericht.md"))
	var no_game := dir.ends_with("_ohne_text") and md.contains("(ohne Text)") and md.contains("**Kontext:** ") \
		and not md.contains("## Spielerflugzeug") and FileAccess.file_exists(dir.path_join("log.txt")) \
		and FileAccess.file_exists(dir.path_join("telemetrie.csv")) and fb.state == Feedback.State.IDLE
	var ok := global and f8 and listed and shown and tut_moved and once and free and rebound and old_ignored and back \
		and pad and no_game
	return [ok, "global %s, F8 %s, Seite %s, Anzeige %s, Tutorial F6 %s, Hilfe 1× %s, F10 frei %s/%s, F8 alt aus %s, zurück %s, Pad %s, ohne Partie %s" % [
		global, f8, listed, shown, tut_moved, once, free, rebound, old_ignored, back, pad, no_game]]


func test_feedback_ring_limits() -> Array:
	var r := FeedbackRecorder.new()
	var a := _spawn(false, 800.0, 90.0, 0.7)
	await _step(2)
	var size0 := r.tele.size()
	# 70 s mit 60 Hz: 10 Hz Proben, höchstens 600 Zeilen (60 s)
	var t := 0.0
	var written := 0
	for i in 70 * 60:
		t += 1.0 / 60.0
		if r.tick_telemetry(1.0 / 60.0, t, a):
			written += 1
	var first := r.tele_row(0)[0]
	var last := r.tele_row(r.tele_count - 1)[0]
	var tele_ok := r.tele_count == FeedbackRecorder.TELE_ROWS and written >= 695 and written <= 701 \
		and last - first <= FeedbackRecorder.WINDOW_S and last - first > 59.0 and r.tele.size() == size0
	var csv_rows := r.telemetry_csv().strip_edges().split("\n").size()
	# Bildrate: 90 Sekunden-Takte → 60 Plätze
	for i in 90 * 30:
		r.tick_fps(1.0 / 30.0)
	var st := r.fps_stats()
	var fps_ok := r.fps_count == FeedbackRecorder.FPS_SLOTS and absf(st.x - 30.0) < 0.5 and st.y > 29.0
	# Ereignisse und Godot-Log: Einträge älter als 60 s fallen heraus
	var now := Time.get_ticks_msec()
	r.events.append([now - 61000, 0.0, "alt"])
	r.add_event(1.0, "neu")
	var ev_ok: bool = r.events.size() == 1 and r.events[0][2] == "neu"
	var lg := FeedbackLog.install()
	lg._mutex.lock()
	lg._lines.insert(0, [now - 61000, "uralt"])
	lg._mutex.unlock()
	print("RINGTEST-MARKE")
	var snap := lg.snapshot()
	var log_ok := snap.any(func(e): return String(e[1]).contains("RINGTEST-MARKE")) \
		and not snap.any(func(e): return e[1] == "uralt")
	var ok: bool = tele_ok and csv_rows == FeedbackRecorder.TELE_ROWS + 1 and fps_ok and ev_ok and log_ok
	return [ok, "Telemetrie %d Zeilen (%d geschrieben, %.1f–%.1f s, Puffer fest %s), CSV %d, fps %d Plätze %.1f/%.1f, Ereignisse %s, Log %s" % [
		r.tele_count, written, first, last, r.tele.size() == size0, csv_rows, r.fps_count, st.x, st.y, ev_ok, log_ok]]
