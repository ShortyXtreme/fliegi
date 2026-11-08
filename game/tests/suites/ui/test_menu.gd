extends TestSuite
## M3.2 Haupt-/Pausenmenü: Navigation (Tastatur/Controller über ui_*-Aktionen, nav()),
## Einstellungen speichern und anwenden, Startoptionen überspringen das Menü, Pause.

var _backup := ""


func _save_cfg() -> void:
	_backup = FileAccess.get_file_as_string(GameSettings.PATH) if FileAccess.file_exists(GameSettings.PATH) else ""


func _restore_cfg() -> void:
	if _backup == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.PATH))
	else:
		var f := FileAccess.open(GameSettings.PATH, FileAccess.WRITE)
		f.store_string(_backup)
	GameSettings.apply_runtime()


func _press(action: StringName) -> void:
	for p in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = p
		Input.parse_input_event(ev)
		await _step(1)


func test_menu_navigation() -> Array:
	_save_cfg()
	var m := GameMenu.new()
	m.mode = GameMenu.Mode.MAIN
	get_tree().root.add_child(m)
	await _step(2)
	var started := []
	m.start_requested.connect(func(t): started.append(t))
	var ids: Array = m.list.items.map(func(i): return i.id)
	# Pfeil runter (ui_down) -> „Freies Spiel“, Enter (ui_accept) -> Start
	await _press(&"ui_down")
	var on_free := m.list.current_id() == "free"
	await _press(&"ui_accept")
	# Einstellungen öffnen, KI-Stufe weiterschalten, mit Esc zurück
	m.list.nav("down")
	m.list.nav("accept")
	var in_settings := m.page == "settings"
	var before := String(GameSettings.get_value("ki_stufe"))
	m.list.focus = m.list.items.map(func(i): return i.id).find("ki_stufe")
	await _press(&"ui_right")
	var after := String(GameSettings.get_value("ki_stufe"))
	await _press(&"ui_cancel")
	var back := m.page == "start"
	# Steuerung zeigt die F1-Tafel
	m.list.focus = 3
	m.list.nav("accept")
	var help_on := m.help.visible and m.page == "controls"
	m.queue_free()
	await _step(2)
	_restore_cfg()
	var ok: bool = ids == ["tutorial", "free", "settings", "controls", "quit"] and on_free \
		and started == [false] and in_settings and before != after and back and help_on
	return [ok, "Einträge %s, Freies Spiel %s, Start %s, KI %s -> %s, zurück %s, Steuerung %s" % [
		str(ids), on_free, str(started), before, after, back, help_on]]


func test_settings_apply() -> Array:
	_save_cfg()
	GameSettings.set_value("flug", "realistisch")
	GameSettings.set_value("radar", "kampf")
	GameSettings.set_value("maus", 1.5)
	GameSettings.set_value("bodenbetrieb", "authentisch")
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	await _step(10)
	var flight := g.player.assist_mode == FlightAssist.Mode.REALISTIC
	var radar := CombatHud.radar_mode == CombatHud.RadarMode.COMBAT_ONLY
	var mouse := is_equal_approx(g.player.mouse_sens(), PlayerController.MOUSE_SENS * 1.5 / g.player.zoom_mul())
	var ground := MatchRules.ground_realism == MatchRules.parse_ground_realism("authentisch")
	g.queue_free()
	await _step(2)
	_restore_cfg()
	MatchRules.load_ground_config()
	return [flight and radar and mouse and ground, "Flug %s, Radar %s, Maus %s, Boden %s" % [flight, radar, mouse, ground]]


func test_pause_menu_and_skip() -> Array:
	var skip: bool = MainMenu.skip_requested(PackedStringArray(["--tutorial"]), PackedStringArray()) \
		and MainMenu.skip_requested(PackedStringArray(["--ki=veteran"]), PackedStringArray()) \
		and MainMenu.skip_requested(PackedStringArray(["--boden=einfach"]), PackedStringArray()) \
		and MainMenu.skip_requested(PackedStringArray(), PackedStringArray(["--selbsttest"])) \
		and not MainMenu.skip_requested(PackedStringArray(), PackedStringArray())
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	await _step(10)
	var ev := InputEventAction.new()
	ev.action = &"release_mouse"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _step(2)
	var paused := get_tree().paused and g.pause_menu != null
	var ids: Array = g.pause_menu.list.items.map(func(i): return i.id) if paused else []
	g.pause_menu.list.nav("accept")   # Fortsetzen
	await _step(2)
	var resumed := not get_tree().paused and g.pause_menu == null
	get_tree().paused = false
	g.queue_free()
	await _step(2)
	var ok: bool = skip and paused and resumed and ids == ["resume", "controls", "settings", "main_menu", "quit"]
	return [ok, "überspringen %s, Pause %s %s, fortgesetzt %s" % [skip, paused, str(ids), resumed]]


## M3.3: Hauptmenü-Kulisse – Hallen, Lager, Bunker, Wagen und abgestellte Flugzeuge wie im Spiel.
func test_main_menu_airfield_decor() -> Array:
	var m: MainMenu = (load(GameMenu.MENU_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(m)
	await _step(3)
	var mm: Dictionary = m.decor.model_meshes if m.decor != null else {}
	var ok := m.decor != null
	for k in ["fuel_depot", "ammo_bunker", "hangar", "hangar_2", "fuel_truck", "ammo_cart", "parked"]:
		ok = ok and int(mm.get(k, 0)) > 0
	var d := m.cam.global_position.distance_to(m._center) if m.cam != null else INF
	m.queue_free()
	await _step(2)
	return [ok and d < 200.0, "Modelle %s, Kamera %.0f m" % [str(mm), d]]
