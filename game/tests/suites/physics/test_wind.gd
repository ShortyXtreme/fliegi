extends TestSuite
## M3.8: Wind – Luftgeschwindigkeit relativ zur Luftmasse, Abdrift, Wind aus = altes Verhalten,
## Höhenprofil/Böen/Seed, Windsack zeigt Richtung und Stärke, Fallschirm treibt, Funkmeldung.


## Geradeausflug mit festem Gas, Flügel waagerecht, Kurs halten (Seitenruder neutral).
func _fly_level(a: Aircraft) -> ScriptedController:
	return _seat(a, func(_v, i: PilotIntent, _dt):
		i.throttle = 0.75
		i.gear_down = false
		var t := a.telemetry()
		var b := a.global_transform.basis
		var bank := atan2(-b.x.y, b.y.y)
		i.roll = clampf(-bank * 2.0, -1.0, 1.0)
		i.pitch = clampf(-t.climb_rate * 0.05, -0.5, 0.5))


func _air(alt := 800.0, speed := 80.0) -> Aircraft:
	var a := _spawn(false, alt, speed, 0.75)
	return a


func test_wind_off_is_old_behaviour() -> Array:
	Weather.reset()
	var a := _air()
	_fly_level(a)
	var max_diff := 0.0
	for f in 180:
		await get_tree().physics_frame
		var t := a.telemetry()
		max_diff = maxf(max_diff, absf(t.airspeed - a.linear_velocity.length()))
	var t := a.telemetry()
	var ok := max_diff < 1e-4 and t.wind == Vector3.ZERO and Weather.wind_at(a.global_position) == Vector3.ZERO \
		and not Weather.enabled()
	return [ok, "Wind aus: Fahrt = Bahngeschwindigkeit (max. Differenz %.6f m/s), Wind %s" % [max_diff, t.wind]]


## Gegenwind: Fahrt über Grund kleiner als die Fahrt gegenüber der Luft (um den Wind).
func test_headwind_airspeed() -> Array:
	Weather.set_steady(0.0, 8.0)    # aus Norden, das Flugzeug fliegt nach Norden (−Z)
	var a := _air(800.0, 80.0)
	_fly_level(a)
	await _step(240)
	var t := a.telemetry()
	var w := Weather.wind_at(a.global_position)
	var gs_along := -a.linear_velocity.z
	var diff := t.airspeed - gs_along
	var ok := w.length() > 8.0 and w.z > 8.0 and absf(diff - w.length()) < 1.5 and absf(t.ground_speed - a.linear_velocity.length()) < 1e-3
	return [ok, "Wind %.1f m/s in 800 m (aus Nord), Fahrt %.1f m/s, über Grund %.1f m/s, Differenz %.1f m/s" % [
		w.length(), t.airspeed, gs_along, diff]]


## Seitenwind: das Flugzeug treibt mit der Luftmasse ab (Kurs Nord, Wind aus Ost → Drift nach West).
func test_crosswind_drift() -> Array:
	Weather.set_steady(90.0, 6.0)
	var a := _air(800.0, 80.0)
	_fly_level(a)
	var x0 := a.global_position.x
	await _step(600)
	var drift := a.global_position.x - x0
	var w := Weather.wind_at(a.global_position)
	var expect := w.x * 10.0
	var ok := drift < -40.0 and absf(drift - expect) < absf(expect) * 0.35
	return [ok, "10 s Kurs Nord bei Wind aus Ost (%.1f m/s in 800 m): Abdrift %.0f m (Luftmasse %.0f m)" % [
		w.length(), drift, expect]]


## Vergleich ohne/mit Gegenwind über 10 s: gleiche Fahrt gegenüber der Luft, Weg über Grund kürzer.
func test_wind_changes_groundtrack_not_flight() -> Array:
	var res := []
	for spd in [0.0, 8.0]:
		Weather.reset()
		if spd > 0.0:
			Weather.set_steady(0.0, spd)
		var a := _air(800.0, 80.0)
		_fly_level(a)
		var z0 := a.global_position.z
		await _step(600)
		res.append([a.telemetry().airspeed, z0 - a.global_position.z, a.telemetry().altitude])
		a.queue_free()
		await _step(1)
	var d_air := absf(res[0][0] - res[1][0])
	var d_dist: float = res[0][1] - res[1][1]
	var ok := d_air < 2.0 and d_dist > 100.0
	return [ok, "Fahrt ohne/mit Gegenwind %.1f / %.1f m/s, Weg über Grund %.0f / %.0f m (Differenz %.0f m)" % [
		res[0][0], res[1][0], res[0][1], res[1][1], d_dist]]


func test_wind_profile_gusts_seed() -> Array:
	var f1 := Weather.height_factor(1.0)
	var f10 := Weather.height_factor(10.0)
	var f2k := Weather.height_factor(2000.0)
	Weather.setup(Weather.Level.NORMAL, 42)
	var a := [Weather.base_from_deg, Weather.base_speed]
	Weather.setup(Weather.Level.NORMAL, 42)
	var same: bool = a == [Weather.base_from_deg, Weather.base_speed]
	Weather.setup(Weather.Level.NORMAL, 43)
	var other: bool = a != [Weather.base_from_deg, Weather.base_speed]
	var ranges_ok := true
	var sector_ok := true
	for lvl in [Weather.Level.SCHWACH, Weather.Level.NORMAL, Weather.Level.STARK]:
		for s in 20:
			Weather.setup(lvl, s)
			var r: Vector2 = Weather.SPEED_RANGE[lvl]
			ranges_ok = ranges_ok and Weather.base_speed >= r.x and Weather.base_speed <= r.y
			sector_ok = sector_ok and absf(Weather.base_from_deg) <= Weather.DIR_SECTOR
	# Böen und Drehen: Wind ändert sich mit der Zeit
	Weather.setup(Weather.Level.STARK, 5)
	var p := Vector3(100, 300, 200)
	var lo := INF
	var hi := 0.0
	var dmin := INF
	var dmax := -INF
	for k in 120:
		Weather.time = k * 5.0
		var w := Weather.wind_at_agl(p, 300.0)
		lo = minf(lo, Vector2(w.x, w.z).length())
		hi = maxf(hi, Vector2(w.x, w.z).length())
		var d := Weather.from_deg_at(Weather.time)
		dmin = minf(dmin, d)
		dmax = maxf(dmax, d)
	Weather.setup(Weather.Level.AUS, 5)
	var off := Weather.wind_at_agl(p, 300.0) == Vector3.ZERO
	var ok := f1 < 0.8 and absf(f10 - 1.0) < 1e-4 and absf(f2k - Weather.MAX_FACTOR) < 1e-4 and same and other \
		and ranges_ok and sector_ok and hi - lo > 1.5 and dmax - dmin > 8.0 and off
	return [ok, "Höhenfaktor 1 m %.2f, 10 m %.2f, 2 km %.2f; Seed gleich %s/anders %s; Stufen %s, Sektor %s; Böen %.1f–%.1f m/s, Richtung %.0f–%.0f°; aus %s" % [
		f1, f10, f2k, same, other, ranges_ok, sector_ok, lo, hi, dmin, dmax, off]]


func test_windsock_shows_wind() -> Array:
	var res := []
	for c in [[270.0, 8.0], [0.0, 3.0], [135.0, 6.0]]:
		Weather.set_steady(c[0], c[1])
		var ws := Windsock.new()
		world.add_child(ws)
		ws._update(0.016)
		var want := Weather.dir_to(c[0])
		var got := ws.sock_direction()
		var spd: float = ws.shown_wind.length()
		res.append([rad_to_deg(want.angle_to(got)), spd, Windsock.droop_deg(spd)])
		ws.queue_free()
	Weather.reset()
	var limp := Windsock.droop_deg(0.0)
	var ok: bool = res.all(func(r): return r[0] < 12.0) and res[0][2] < 15.0 and res[1][2] > 30.0 and limp > 60.0
	return [ok, "Windsack: Abweichung zur Windrichtung %s°, Stärke %s m/s, Hängewinkel %s°, Flaute %.0f°" % [
		res.map(func(r): return "%.1f" % r[0]), res.map(func(r): return "%.1f" % r[1]),
		res.map(func(r): return "%.0f" % r[2]), limp]]


func test_parachute_and_debris_drift() -> Array:
	Weather.set_steady(270.0, 7.0)    # aus West → treibt nach Ost (+X)
	var dummy := Node3D.new()
	world.add_child(dummy)
	dummy.global_position = Vector3(0, 600, 0)
	var p := Parachute.spawn_from(dummy, null, true)
	var x0 := p.global_position.x
	await _step(600)
	var drift := p.global_position.x - x0
	var w := Weather.wind_at(p.global_position)
	var ok := drift > w.x * 10.0 * 0.6
	return [ok, "Fallschirm 10 s bei Wind aus West (%.1f m/s): Drift nach Ost %.0f m" % [w.x, drift]]


func test_radio_report() -> Array:
	Weather.set_steady(225.0, 5.0)
	var r1 := Weather.report()
	Weather.set_steady(0.0, 0.5)
	var r2 := Weather.report()
	Weather.reset()
	var r3 := Weather.report()
	var ok := r1 == "Wind aus Südwest, mäßig" and r2 == "Windstill" and r3 == "Windstill" \
		and not r1.contains("m/s") and not r1.contains("°")
	return [ok, "Meldungen: „%s“, „%s“, „%s“" % [r1, r2, r3]]


## Debug-Wind, Spieler-Einstellung und Tutorial/Selbsttest-Regeln.
func test_wind_setting() -> Array:
	var o := GameSettings.option("wind")
	var ok: bool = not o.is_empty() and o[5] == "normal" and o[4] == ["Aus", "Schwach", "Normal", "Stark"]
	return [ok, "Einstellung Wind: %s, Standard %s" % [o[4] if not o.is_empty() else "-", o[5] if not o.is_empty() else "-"]]
