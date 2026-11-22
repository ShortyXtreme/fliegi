extends TestSuite
## M3.5: Motor anlassen/abstellen und Elektrik (EngineControl): richtige Reihenfolge, Treibstoff,
## Arcade eine Taste, Schwungkraft-Anlasser (zu kurz gehalten), Abstellen per Gemisch/Zündung,
## Luftstart warm, KI lässt am Boden an, Schalterpanel/Tasten-Leiste.


func _cold(a: Aircraft) -> EngineControl:
	var ec := EngineControl.of(a)
	ec.cold()
	return ec


func _wait(ec: EngineControl, s: float) -> void:
	await _step(int(s * 60.0))


func test_arcade_toggle_start_stop() -> Array:
	var a := _spawn(true)
	var ec := _cold(a)
	await _step(5)
	var off: bool = not a.flight.engine.running
	ec.toggle()
	await _wait(ec, 2.5)
	var on: bool = ec.is_running() and a.flight.engine.running
	ec.toggle()
	await _wait(ec, 2.6)
	var stopped: bool = ec.phase == EngineControl.Phase.OFF and not a.flight.engine.running
	ec.toggle()                                  # erneut anlassen (Gemisch wieder reich)
	await _wait(ec, 2.5)
	var again := ec.is_running()
	return [off and on and stopped and again, "aus %s, an %s, abgestellt %s, wieder an %s" % [off, on, stopped, again]]


func test_realistic_sequence() -> Array:
	var a := _spawn(true)
	var ec := _cold(a)
	var msgs := []
	ec.message.connect(func(t, _w): msgs.append(t))
	# 1) ohne Batterie: Anlasser tut nichts
	ec.set_starter(true)
	await _step(2)
	var no_power := ec.phase == EngineControl.Phase.OFF
	ec.set_starter(false)
	# 2) Batterie, Pumpe an, Zündung AUS: dreht durch, springt nicht an
	ec.set_master(true)
	ec.set_fuel_pump(true)
	ec.set_starter(true)
	await _wait(ec, 3.6)
	ec.set_starter(false)
	await _wait(ec, 1.6)
	var no_ign: bool = not ec.is_running() and msgs.any(func(m): return String(m).contains("Zündung aus"))
	# 3) Anlasser zu kurz gehalten
	ec.set_magnetos(true)
	ec.set_starter(true)
	await _wait(ec, 0.5)
	ec.set_starter(false)
	await _step(3)
	var too_short: bool = not ec.is_running() and msgs.any(func(m): return String(m).contains("zu kurz"))
	# 4) richtig: halten bis das Schwungrad läuft, loslassen
	ec.set_starter(true)
	await _wait(ec, 3.6)
	ec.set_starter(false)
	await _wait(ec, 1.6)
	var runs := ec.is_running()
	# 5) Abstellen per Gemisch
	ec.set_mixture(false)
	await _wait(ec, 2.4)
	var stop_mix := ec.phase == EngineControl.Phase.OFF
	var ok := no_power and no_ign and too_short and runs and stop_mix
	return [ok, "ohne Strom %s, ohne Zündung %s, zu kurz %s, läuft %s, Gemisch aus %s; %s" % [no_power, no_ign,
		too_short, runs, stop_mix, msgs]]


func test_no_fuel_and_magneto_stop() -> Array:
	var a := _spawn(true)
	var ec := _cold(a)
	a.damage.fuel.set_fraction(0.0)
	ec.toggle()
	await _wait(ec, 2.5)
	var no_fuel := not ec.is_running()
	a.damage.fuel.set_fraction(0.5)
	await _step(2)
	ec.toggle()
	await _wait(ec, 2.5)
	var runs := ec.is_running()
	ec.set_magnetos(false)
	await _wait(ec, 2.4)
	var stop_ign := ec.phase == EngineControl.Phase.OFF
	return [no_fuel and runs and stop_ign, "ohne Treibstoff aus %s, dann an %s, Zündung aus -> aus %s" % [no_fuel, runs, stop_ign]]


func test_air_start_warm_and_thrust() -> Array:
	var a := _spawn(true)
	var ec := _cold(a)
	await _step(3)
	var p := a.global_position + Vector3(0, 800, 0)
	a.place(Transform3D(a.global_transform.basis, p), 90.0, 0.8, false)
	await _step(10)
	var warm := ec.is_running() and a.flight.engine.running
	return [warm, "Luftstart warm %s" % warm]


## Hauptszene: Spieler startet mit stehendem Motor; Panel/Tasten-Leiste zeigen das Anlassen;
## Motortaste lässt an.
func test_main_scene_cold_start() -> Array:
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	await _step(30)
	var pa := g.player_aircraft
	var ec := EngineControl.find(pa)
	var cold: bool = ec != null and not ec.is_running()
	var keys: Array = g.hud.ground_hud.key_bar.entries.map(func(e): return e[0])
	var panel: bool = g.hud.combat.switch_panel.visible
	for pr in [true, false]:
		var ev := InputEventAction.new()
		ev.action = &"engine_toggle"
		ev.pressed = pr
		Input.parse_input_event(ev)
		await _step(2)
	await _step(150)
	var runs: bool = ec != null and ec.is_running()
	var ai_ec := false
	for e in g.scenario.enemies:
		ai_ec = ai_ec or EngineControl.find(e) != null
	g.queue_free()
	await _step(2)
	var ok: bool = cold and keys.has(&"engine_toggle") and panel and runs and ai_ec
	return [ok, "kalt %s, Leiste %s, Panel %s, läuft %s, KI mit Motorsteuerung %s" % [cold, keys, panel, runs, ai_ec]]
