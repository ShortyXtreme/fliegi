extends TestSuite
## M3.2 Tutorial: kompletter Ablauf headless mit simulierten Aktionen (Eingaben, Lagen,
## Treffer-Bus, Befehlsrad, Tragen, Munition, Sitz). Jeder Schritt darf erst weitergehen,
## wenn seine Prüfung die Aktion sieht.


func _place_air(g: Game, pos: Vector3, dir: Vector3, speed := 80.0) -> void:
	g.player_aircraft.place(Transform3D(Basis.looking_at(dir, Vector3.UP), pos), speed, 0.8, true)


func _tap(action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _step(2)


func test_tutorial_flow() -> Array:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.PROGRESS_PATH))
	Game.tutorial_mode = true
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	Game.tutorial_mode = false
	await _step(20)
	var tu := g.tutorial
	var log := []
	var red := g.ai_aircrafts.size()
	var alarm_off := g._alarm_next < 0.0
	var pa := g.player_aircraft
	var home := tu.home
	var fwd := -home.basis.z
	# M3.4: Maschine fast leer, zuerst Bodenvorbereitung; ohne Aktion geht nichts weiter
	var empty := pa.weapons.ammo() == 0 and pa.telemetry().fuel_fraction < 0.3
	await _step(30)
	var waits: bool = tu.index == 0 and not tu.done[0]
	# 0 Aussteigen
	Input.action_press(&"eject_hold")
	await _step(75)
	Input.action_release(&"eject_hold")
	await _step(60)
	log.append("s1 %d" % tu.index)
	var no_auto := pa.weapons.ammo() == 0   # Automatik-Abfertigung aus
	# 1 Tanken: Befehlsrad „Nur tanken“, Tank füllt sich
	g.hud.ground_hud.issue_command(GroundCrewBrain.Command.FUEL_ONLY, pa)
	await _step(2)
	pa.damage.fuel.set_fraction(0.45)
	await _step(4)
	log.append("s2 %d" % tu.index)
	# 2 Munition: Kiste, Klappe/Gurt
	var crate := CarryItem.new()
	g.crew.carried_changed.emit(crate)
	await _step(2)
	pa.weapons.magazines[0].count += 50
	await _step(3)
	log.append("s3 %d" % tu.index)
	# 3 Einsteigen
	g.crew.try_enter(pa.pilot_seat)
	await _step(30)
	log.append("s4 %d" % tu.index)
	# 4 Vorflug-Check: Gas allein reicht nicht, erst Startklappen
	Input.action_press(&"throttle_up")
	await _step(60)
	Input.action_release(&"throttle_up")
	var flaps_first: bool = tu.index == 4 and not tu.done[1]
	# M3.5: Motor anlassen (Arcade: Motortaste, Anlasser ca. 2 s)
	var engine_wait: bool = tu.index == 4 and not tu.done[0]
	await _tap(&"engine_toggle")
	await _step(180)
	flaps_first = flaps_first and engine_wait and tu.done[0]
	g.player.reset_state(0.0)
	await _tap(&"flaps_cycle")
	Input.action_press(&"throttle_up")
	for i in 200:
		await _step(1)
		if tu.index != 4:
			break
	Input.action_release(&"throttle_up")
	log.append("s5 %d" % tu.index)
	# 5 Start: abheben, Fahrwerk ein, Klappen ein (zweimal tippen: Landung -> ein)
	_place_air(g, home.origin + fwd * 400 + Vector3(0, 60, 0), fwd)
	await _step(5)
	await _tap(&"gear_toggle")
	await _step(480)
	var flaps_wait: bool = tu.index == 5 and not tu.done[2]
	await _tap(&"flaps_cycle")
	await _tap(&"flaps_cycle")
	await _step(5)
	log.append("s6 %d" % tu.index)
	# 6 Fliegen: Kurve, Steigen
	var p := pa.global_position
	for k in 7:
		var d := fwd.rotated(Vector3.UP, 0.3 * (k + 1))
		_place_air(g, p, d)
		await _step(3)
	_place_air(g, p + Vector3(0, 400, 0), fwd)
	await _step(5)
	log.append("s7 %d" % tu.index)
	# 7 Zielen: Übungsziel da, schießt nicht; Zoom + Treffer
	var tgt := tu.target
	var tgt_ok := tgt != null and tgt.nation_id == Nations.RED and tgt.get("pilot_seat") != null \
		and tgt.pilot_seat.controller == null
	Input.action_press(&"zoom_hold")
	await _step(3)
	Input.action_release(&"zoom_hold")
	for k in 3:
		CombatEvents.bus().hit_confirmed.emit(pa, tgt, DamageModel.Zone.TAIL, 5.0)
		await _step(2)
	await _step(3)
	log.append("s8 %d" % tu.index)
	# 8 Landung: Platz, Fahrwerk aus, Landeklappen (Aktion wird geprüft), Aufsetzen
	_place_air(g, home.origin + fwd * -1500 + Vector3(0, 200, 0), fwd, 60.0)
	await _step(3)
	await _tap(&"gear_toggle")
	await _step(480)
	var land_flaps_wait: bool = tu.index == 8 and tu.done[1] and not tu.done[2]
	await _tap(&"flaps_cycle")
	await _tap(&"flaps_cycle")
	await _step(3)
	g.player.throttle = 0.0
	pa.place_on_ground(home.origin, -home.basis.z, false)
	await _step(30)
	log.append("s9 %d" % tu.index)
	# 9 Abstellplatz
	g.player.reset_state(0.0)
	await _step(120)
	log.append("s10 %d" % tu.index)
	# 10 Abschluss
	tu.step_t = Tutorial.TEXT_STEP_TIME
	await _step(3)
	var completed := not tu.active and bool(Tutorial.load_progress().get_value("tutorial", "completed", false))
	var auto_back: bool = not g.blue_ops.dispatch.auto_exclude.has(pa)
	crate.free()
	g.queue_free()
	await _step(2)
	var ok: bool = red == 0 and alarm_off and waits and tgt_ok and completed and empty and no_auto \
		and flaps_first and flaps_wait and land_flaps_wait and auto_back \
		and log == ["s1 1", "s2 2", "s3 3", "s4 4", "s5 5", "s6 6", "s7 7", "s8 8", "s9 9", "s10 10"]
	return [ok, "Rote %d, Alarm aus %s, leer %s, keine Automatik %s, wartet %s, Klappen vor Gas %s, Klappen ein %s, Landeklappen %s, Ziel ok %s, Ablauf %s, fertig %s" % [
		red, alarm_off, empty, no_auto, waits, flaps_first, flaps_wait, land_flaps_wait, tgt_ok, str(log), completed]]


func test_tutorial_skip_and_diagnose() -> Array:
	var d := Tutorial.diagnose()
	Game.tutorial_mode = true
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	Game.tutorial_mode = false
	await _step(10)
	var tu := g.tutorial
	var ev := InputEventAction.new()
	ev.action = &"tutorial_skip"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _step(3)
	var skipped := tu.index == 1
	var keys: Array = g.hud.ground_hud.key_bar.entries.map(func(e): return e[0])
	tu.quit()
	await _step(2)
	var quit_ok := not tu.active and g.hud.ground_hud.key_override.is_empty()
	g.queue_free()
	await _step(2)
	# M3.5: Schritt „Tanken“ im Cockpit – Tasten-Leiste zeigt nur Flug-Kontext (Aussteigen), keine Bodentasten
	return [d[0] and skipped and quit_ok and not keys.has(&"crew_wheel") and keys.has(&"eject_hold"),
		"%s, übersprungen %s, beendet %s, Leiste %s" % [d[1], skipped, quit_ok, str(keys)]]


## M3.3: Controller – View kurz = Hilfe, View halten = überspringen; Pausenmenü „Tutorial beenden“.
func test_tutorial_pad_skip_and_pause_quit() -> Array:
	Game.tutorial_mode = true
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	Game.tutorial_mode = false
	await _step(10)
	var tu := g.tutorial
	var pad := func(pressed: bool) -> void:
		var e := InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_BACK
		e.pressed = pressed
		Input.parse_input_event(e)
	pad.call(true)
	await _step(3)
	pad.call(false)
	await _step(3)
	var short_ok := tu.index == 0
	pad.call(true)
	await _step(int(Tutorial.VIEW_HOLD_S * 60.0) + 10)
	pad.call(false)
	await _step(3)
	var hold_ok := tu.index == 1 and KeyGlyphs.pad
	g.open_pause_menu()
	await _step(2)
	var ids: Array = g.pause_menu.list.items.map(func(i): return i.id)
	g.pause_menu.list.nav("down")
	g.pause_menu.list.nav("accept")
	await _step(3)
	var quit_ok := not tu.active and not get_tree().paused
	get_tree().paused = false
	KeyGlyphs.pad = false
	g.queue_free()
	await _step(2)
	return [short_ok and hold_ok and ids.has("tutorial_quit") and quit_ok,
		"kurz %s, halten %s, Pause %s, beendet %s" % [short_ok, hold_ok, str(ids), quit_ok]]
