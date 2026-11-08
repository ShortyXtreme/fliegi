extends TestSuite
## M3.3 Audio: Busse, Klänge (lizenzfrei, prozedural), Lautstärke-Einstellungen, Anbindung an
## Flugzeuge/Ereignisse, Stimmen-Pool, Größe. Headless ist Master stumm, alles läuft trotzdem.


func test_audio_buses_and_streams() -> Array:
	GameAudio.setup()
	var ok := true
	for b in ["Master", "Motor", "Waffen", "Umgebung", "UI"]:
		ok = ok and AudioServer.get_bus_index(b) >= 0
	ok = ok and GameAudio.loaded_count() == GameAudio.SOUNDS.size()
	var layers := GameAudio.engine_layers("v12")
	var eng := (layers[0][0] if layers.size() == 3 else null) as AudioStreamOggVorbis
	ok = ok and GameAudio.engine_layers("radial").size() == 3
	var hit := GameAudio.stream("hit_own") as AudioStreamOggVorbis
	ok = ok and eng != null and eng.loop and hit != null and not hit.loop
	ok = ok and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))   # headless stumm
	var bytes := 0
	for k in GameAudio.SOUNDS:
		bytes += FileAccess.get_file_as_bytes(GameAudio.DIR % k).size()
	for typ in GameAudio.ENGINE_RPM:
		for l in GameAudio.ENGINE_LAYERS:
			bytes += FileAccess.get_file_as_bytes(GameAudio.ENGINE_DIR % [typ, l]).size()
	return [ok and bytes < 3_000_000, "%s, %d KB" % [GameAudio.diagnostics(), bytes / 1024]]


func test_volume_settings() -> Array:
	GameAudio.setup()
	var old = GameSettings.get_value("vol_motor")
	GameSettings.set_value("vol_motor", 0.5)
	GameSettings.apply_runtime()
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Motor"))
	GameSettings.set_value("vol_motor", 1.0)
	GameSettings.cycle("vol_motor", 1)   # Regler bleibt am Rand
	var top: float = GameSettings.get_value("vol_motor")
	GameSettings.set_value("vol_motor", 0.0)
	GameSettings.apply_runtime()
	var mute := AudioServer.is_bus_mute(AudioServer.get_bus_index("Motor"))
	GameSettings.set_value("vol_motor", old)
	GameSettings.apply_runtime()
	var ok: bool = absf(db + 6.02) < 0.1 and top == 1.0 and mute and GameSettings.label_of("vol_motor").ends_with("%")
	return [ok, "50 %% = %.1f dB, Rand %.1f, 0 %% stumm %s" % [db, top, mute]]


func test_game_sounds_wired() -> Array:
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	await _step(20)
	var d := g.sound
	var s: AircraftSound = d.aircraft.get(g.player_aircraft)
	var eng_ok := s != null and s.engine.playing and s.engine.bus == &"Motor"
	var enemy_ok := g.ai_aircrafts.is_empty() or (d.aircraft.get(g.ai_aircrafts[0]) as AircraftSound).engine_type \
		== g.ai_aircrafts[0].data.engine_sound
	eng_ok = eng_ok and s.engine_type == "v12" and s.engines.size() == 3
	var cb := CombatEvents.bus()
	cb.shot_fired.emit(g.player_aircraft, 0, 1)
	await _step(2)
	var mg_ok := s.mg.playing
	cb.hit_confirmed.emit(g.ai_aircrafts[0] if not g.ai_aircrafts.is_empty() else null, g.player_aircraft, 0, 5.0)
	GroundEvents.bus().alarm_started.emit(30.0)
	var crew: Node = g.crew
	GroundEvents.bus().job_progress.emit(77, &"pump", 0.3, crew)
	for k in 30:
		d.play_3d("hit_enemy", g.player_aircraft.global_position, "Waffen")
	await _step(2)
	var act_ok := d.activity.has("77|pump")
	var ok: bool = eng_ok and enemy_ok and mg_ok and d.played.get("hit_own", 0) == 1 \
		and d.played.get("alarm_siren", 0) + d.played.get("alarm_bell", 0) == 1 and act_ok and d.voices() <= SoundDirector.POOL_3D + SoundDirector.POOL_2D \
		and d.vehicles.size() >= 2 and d.walkers.size() >= 1
	var txt := "Motor %s, Gegner-Motortyp %s, MG %s, gespielt %s, Pumpe %s, Stimmen %d, Wagen %d, Figuren %d" % [
		eng_ok, enemy_ok, mg_ok, str(d.played), act_ok, d.voices(), d.vehicles.size(), d.walkers.size()]
	GroundEvents.bus().alarm_ended.emit(true)
	g.queue_free()
	await _step(2)
	return [ok, txt]


## Drehzahl-Layer: gleichleistende Überblendung, an den Stützstellen nur ein Layer hörbar.
func test_engine_layer_crossfade() -> Array:
	var refs: Array[float] = [850.0, 1800.0, 2750.0]
	var ok := true
	for r in [850.0, 1200.0, 1800.0, 2300.0, 2750.0, 3000.0]:
		var pw := 0.0
		for i in 3:
			pw += pow(AircraftSound.layer_weight(refs, i, r), 2)
		ok = ok and absf(pw - 1.0) < 0.01
	ok = ok and AircraftSound.layer_weight(refs, 0, 1800.0) < 0.001 and AircraftSound.layer_weight(refs, 1, 1800.0) > 0.999
	return [ok, "Leistungssumme = 1 über 850–3000 U/min: %s" % ok]


## Einstellung „Alarmton“: Sirene (Standard) / Glocke.
func test_alarm_setting() -> Array:
	GameAudio.setup()
	var old = GameSettings.get_value("alarmton")
	var a := GameAudio.alarm_sound()
	GameSettings.set_value("alarmton", "glocke")
	var b := GameAudio.alarm_sound()
	GameSettings.set_value("alarmton", old)
	var ok: bool = GameSettings.option("alarmton")[5] == "sirene" and b == "alarm_bell" \
		and GameAudio.stream("alarm_bell") != null and GameAudio.stream("alarm_siren") != null
	return [ok, "Standard %s, Glocke %s (%s)" % [GameSettings.option("alarmton")[5], b, a]]
