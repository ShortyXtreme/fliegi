extends SceneTree
## Leistungsdaten: Höchstgeschwindigkeit (Fahrwerk aus/ein), Steigrate bei Fahrt v
## (Fahrwerk eingefahren), Leistung über Höhe. Aufruf:
##   godot --headless --path . --fixed-fps 60 --script res://tests/diag/perf_diag.gd

const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"

func _initialize() -> void:
	_run.call_deferred()

func _spawn(w: TestWorld, alt: float, v: float, gear: bool) -> Aircraft:
	var a := Aircraft.create(load(FIGHTER), false)
	w.add_child(a)
	a.place(Transform3D(Basis.looking_at(TestWorld.RUNWAY_DIR, Vector3.UP), Vector3(0, alt, 0)), v, 1.0, gear)
	return a

func _top(alt: float, gear: bool) -> float:
	var w := TestWorld.new(); root.add_child(w); await physics_frame
	var a := _spawn(w, alt, 120.0, gear)
	var c := ScriptedController.new()
	c.logic = func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.ARCADE; i.throttle = 1.0; i.gear_down = gear
		var want_vs := clampf((alt - ac.global_position.y) * 0.3, -10.0, 10.0)
		i.pitch = clampf((want_vs - t.climb_rate) * 0.08, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0)
	a.add_child(c); a.pilot_seat.possess(c)
	for f in 60 * 90: await physics_frame
	var v := a.telemetry().airspeed * 3.6
	w.queue_free(); await physics_frame
	return v

func _climb(alt: float, v_kmh: float, gear: bool) -> float:
	var w := TestWorld.new(); root.add_child(w); await physics_frame
	var speed := v_kmh / 3.6
	var a := _spawn(w, alt, speed, gear)
	var c := ScriptedController.new()
	c.logic = func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.REALISTIC; i.throttle = 1.0; i.gear_down = gear
		var want_vs := clampf((t.airspeed - speed) * 1.5, -30.0, 40.0)
		i.pitch = clampf((want_vs - t.climb_rate) * 0.03 - t.angular_velocity_local.x * 0.8 + 0.05, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0)
	a.add_child(c); a.pilot_seat.possess(c)
	var s := 0.0; var n := 0
	for f in 60 * 30:
		await physics_frame
		if f > 60 * 15:
			s += a.telemetry().climb_rate; n += 1
	w.queue_free(); await physics_frame
	return s / n

func _run() -> void:
	print("Höchstgeschw. 500 m: Fahrwerk ein %.0f km/h, aus %.0f km/h" % [await _top(500.0, false), await _top(500.0, true)])
	print("Höchstgeschw. 4000 m (Fahrwerk ein): %.0f km/h" % [await _top(4000.0, false)])
	for v in [240, 270, 300]:
		print("Steigen %d km/h, 300 m, Fahrwerk ein: %.1f m/s | aus: %.1f m/s" % [v, await _climb(300.0, v, false), await _climb(300.0, v, true)])
	print("Steigen 270 km/h, 3000 m: %.1f m/s, 6000 m: %.1f m/s" % [await _climb(3000.0, 270, false), await _climb(6000.0, 270, false)])
	quit(0)
