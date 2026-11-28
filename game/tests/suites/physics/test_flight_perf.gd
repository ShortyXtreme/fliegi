extends TestSuite
## Prüfung Flugphysik (Audit 11/2026): Leistungsdaten des Tier-I-Jägers gegen reale Jäger
## der späten 1930er (Bf 109 E, Spitfire I, Hurricane I, P-36, MS.406, I-16, G.50, Ki-27).
## Suite "perf" (nur Messung, ausführlich): tests/run_tests.sh --suite=perf --file=flight_perf
## Einzelne Messungen mit --only=perf_<name>. Sollbereiche siehe docs/pruefung_flugphysik.md.

const SUITE := "perf"


func _bank(ac: Aircraft) -> float:
	return asin(clampf(-ac.global_transform.basis.x.y, -1.0, 1.0))   # + = rechts hängend


## Arcade, Höhe halten, Flügel waagerecht, Vollgas.
func _level_logic(alt: float) -> Callable:
	return func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.gear_down = false
		i.throttle = 1.0
		var want_vs := clampf((alt - ac.global_position.y) * 0.3, -10.0, 10.0)
		i.pitch = clampf((want_vs - t.climb_rate) * 0.08, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0)


func _top_speed_at(alt: float, v0: float) -> Array:
	var a := _spawn(false, alt, v0, 1.0)
	a.place(a.global_transform, v0, 1.0, false)
	_seat(a, _level_logic(alt))
	var samples: Array[float] = []
	for f in 60 * 100:
		await get_tree().physics_frame
		if f > 60 * 85:
			samples.append(a.telemetry().airspeed)
	var v: float = (samples.min() + samples.max()) * 0.5
	var h := a.global_position.y
	a.queue_free()
	await _step(2)
	return [v, h]


func test_perf_top_speed() -> Array:
	var txt := ""
	for alt in [100.0, 2000.0, 4000.0, 5000.0, 6000.0]:
		var r := await _top_speed_at(alt, 135.0)
		txt += "%4.0f m: %3.0f km/h TAS | " % [r[1], kmh(r[0])]
	return [true, "Höchstgeschw. " + txt]


## Steigrate bei gehaltener Fahrt (Realistisch, Fahrwerk ein), Mittel über 10 s.
func _climb_at(alt: float, speed: float) -> float:
	var a := _spawn(false, alt, speed, 1.0)
	a.place(a.global_transform, speed, 1.0, false)
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.gear_down = false
		i.throttle = 1.0
		var want_vs := clampf((t.airspeed - speed) * 1.5, -30.0, 40.0)
		i.pitch = clampf((want_vs - t.climb_rate) * 0.03 - t.angular_velocity_local.x * 0.8 + 0.05, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0))
	var s := 0.0
	var n := 0
	for f in 60 * 25:
		await get_tree().physics_frame
		if f > 60 * 15:
			s += a.telemetry().climb_rate
			n += 1
	a.queue_free()
	await _step(2)
	return s / n


func test_perf_climb() -> Array:
	var txt := ""
	for alt in [300.0, 3000.0, 4500.0, 6000.0, 8000.0]:
		var best := -99.0
		var best_v := 0.0
		for v in [65.0, 75.0, 85.0]:
			var vs := await _climb_at(alt, v)
			if vs > best:
				best = vs
				best_v = v
		txt += "%4.0f m: %4.1f m/s @%3.0f | " % [alt, best, kmh(best_v)]
	return [true, "Steigrate " + txt]


## Dauerkurve: Arcade voll gezogen (Begrenzer am Abriss-AoA), Querlage so, dass die Höhe
## gehalten wird. Misst Zeit für 360°, Radius, Fahrt, G (stationär).
func _sustained_turn(alt: float, v0: float, pull := 1.0) -> Array:
	var a := _spawn(false, alt, v0, 1.0)
	a.place(a.global_transform, v0, 1.0, false)
	var bank_t := [deg_to_rad(70.0)]
	_seat(a, func(ac: Aircraft, i: PilotIntent, dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.gear_down = false
		i.throttle = 1.0
		i.pitch = pull
		var alt_err := ac.global_position.y - alt
		bank_t[0] = clampf(bank_t[0] + (t.climb_rate * 0.02 + alt_err * 0.002) * dt, deg_to_rad(20.0), deg_to_rad(88.0))
		var b := _bank(ac)
		i.roll = clampf((bank_t[0] - b) * 3.0 + t.angular_velocity_local.z * 0.3, -1.0, 1.0))
	var prev := -a.global_transform.basis.z
	prev.y = 0.0
	var heading := 0.0
	var marks: Array = []   # [time, heading, pos, v, g]
	for f in 60 * 70:
		await get_tree().physics_frame
		var h := -a.global_transform.basis.z
		h.y = 0.0
		heading += absf(prev.signed_angle_to(h, Vector3.UP))
		prev = h
		if f % 6 == 0:
			marks.append([f / 60.0, heading, a.global_position, a.telemetry().airspeed, a.telemetry().g_load, a.global_position.y, a.telemetry().aoa])
	# letzte 360° auswerten
	var last = marks[marks.size() - 1]
	var k := marks.size() - 1
	while k > 0 and last[1] - marks[k][1] < TAU:
		k -= 1
	var t360: float = last[0] - marks[k][0]
	var vm := 0.0
	var gm := 0.0
	var am := 0.0
	var n := 0
	var cx := Vector3.ZERO
	for j in range(k, marks.size()):
		vm += marks[j][3]
		gm += marks[j][4]
		am += marks[j][6]
		cx += marks[j][2]
		n += 1
	vm /= n
	gm /= n
	cx /= n
	var rad := 0.0
	for j in range(k, marks.size()):
		var d: Vector3 = marks[j][2] - cx
		d.y = 0.0
		rad += d.length()
	rad /= n
	var dh: float = last[5] - marks[k][5]
	var sa := a.telemetry().stall_aoa
	a.queue_free()
	await _step(2)
	return [t360, rad, vm, gm, dh, am / n, sa]


func test_perf_turn() -> Array:
	var txt := ""
	for alt in [1000.0, 4000.0]:
		var r := await _sustained_turn(alt, 100.0)
		txt += "%4.0f m: 360° in %.1f s, r %.0f m, %.0f km/h, %.2f g, dh %.0f m, AoA %.1f° (Abriss %.1f°) | " % [alt, r[0], r[1], kmh(r[2]), r[3], r[4], rad_to_deg(r[5]), rad_to_deg(r[6])]
	return [true, "Dauerkurve (Arcade voll gezogen) " + txt]


## Energieverlust: aus 400 km/h in 1.500 m voll ziehen in der Horizontalen (Querlage 80°),
## Fahrtverlust in den ersten 3 s und Fahrt nach 10 s.
func test_perf_bleed() -> Array:
	var a := _spawn(false, 1500.0, 111.0, 1.0)
	a.place(a.global_transform, 111.0, 1.0, false)
	await _step(1)
	a.global_transform.basis = a.global_transform.basis.rotated(-a.global_transform.basis.z, deg_to_rad(80.0))
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.gear_down = false
		i.throttle = 1.0
		i.pitch = 1.0
		var b := _bank(ac)
		i.roll = clampf((deg_to_rad(-80.0) - b) * 3.0 + t.angular_velocity_local.z * 0.3, -1.0, 1.0))
	var v := [0.0, 0.0, 0.0]
	var gmax := 0.0
	var amax := 0.0
	for f in 60 * 10:
		await get_tree().physics_frame
		var t := a.telemetry()
		gmax = maxf(gmax, t.g_load)
		amax = maxf(amax, t.aoa)
		if f == 0:
			v[0] = t.airspeed
		if f == 180:
			v[1] = t.airspeed
		if f == 599:
			v[2] = t.airspeed
	return [true, "Ziehen aus %.0f km/h: nach 3 s %.0f km/h (%.1f km/h/s), nach 10 s %.0f km/h, max %.1f g, AoA max %.1f°, Höhe %.0f" % [
		kmh(v[0]), kmh(v[1]), kmh(v[0] - v[1]) / 3.0, kmh(v[2]), gmax, rad_to_deg(amax), a.global_position.y]]


func _stall_level(flaps: float, gear: bool) -> float:
	var a := _spawn(false, 1000.0, 60.0, 0.0)
	a.place(a.global_transform, 60.0, 0.0, gear)
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.throttle = 0.0
		i.flaps = flaps
		i.gear_down = gear
		i.pitch = clampf(i.pitch + (0.0 - t.climb_rate) * 0.004 - t.angular_velocity_local.x * 0.05, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0))
	var stall_speed := -1.0
	for f in 60 * 60:
		await get_tree().physics_frame
		var t := a.telemetry()
		if t.stall_amount > 0.5:
			stall_speed = t.airspeed
			break
	a.queue_free()
	await _step(2)
	return stall_speed


func test_perf_stall() -> Array:
	var clean := await _stall_level(0.0, false)
	var half := await _stall_level(0.5, true)
	var full := await _stall_level(1.0, true)
	# TAS in 1.000 m -> IAS (ISA: sqrt(σ) = 0,952)
	var s := sqrt(FlightModel.air_density(1000.0) / 1.225)
	return [true, "1-g-Abriss (Leerlauf, 1.000 m) TAS/IAS: sauber %.0f/%.0f, Klappen 50 %% %.0f/%.0f, Landeklappen %.0f/%.0f km/h" % [
		kmh(clean), kmh(clean * s), kmh(half), kmh(half * s), kmh(full), kmh(full * s)]]


func test_perf_takeoff() -> Array:
	var a := _spawn()
	var p0 := a.global_position
	var lift_d := -1.0
	var lift_v := 0.0
	var d15 := -1.0
	var t_lift := 0.0
	var ground_h := p0.y - a.data.ground_height
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.throttle = 1.0
		i.flaps = 0.5
		i.yaw = Autopilot.hold_heading(ac.global_transform.basis, -t.angular_velocity_local.y, TestWorld.RUNWAY_DIR)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0)   # M3.11: Rückdrehmoment
		i.pitch = -0.2 if t.airspeed < 30.0 else 0.35)
	for f in 60 * 60:
		await get_tree().physics_frame
		var t := a.telemetry()
		var d := Vector2(a.global_position.x - p0.x, a.global_position.z - p0.z).length()
		if f > 60 and t.wheels_in_contact == 0 and lift_d < 0.0:
			lift_d = d
			lift_v = t.airspeed
			t_lift = f / 60.0
		if lift_d > 0.0 and a.global_position.y - ground_h - 1.0 > 15.0 and d15 < 0.0:
			d15 = d
			break
	return [true, "Start (Klappen 50 %%, Vollgas, Gras): Abheben nach %.0f m / %.1f s bei %.0f km/h, 15 m Höhe nach %.0f m" % [
		lift_d, t_lift, kmh(lift_v), d15]]


func test_perf_landing_roll() -> Array:
	# Aufsetzen dreipunkt bei ~150 km/h, dann Gas weg, bremsen (Realistisch, Knüppel gezogen).
	var a := _spawn()
	await _step(30)
	a.linear_velocity = -a.global_transform.basis.z * (140.0 / 3.6)
	var p0 := a.global_position
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.throttle = 0.0
		i.flaps = 1.0
		i.pitch = 1.0
		i.brakes = 1.0 if t.airspeed < 100.0 / 3.6 else 0.0
		i.yaw = Autopilot.hold_heading(ac.global_transform.basis, -t.angular_velocity_local.y, TestWorld.RUNWAY_DIR))
	var nose := false
	for f in 60 * 40:
		await get_tree().physics_frame
		if a.global_transform.basis.y.y < 0.7:
			nose = true
		if a.linear_velocity.length() < 0.5:
			break
	var d := p0.distance_to(a.global_position)
	# ohne Bremse
	var b := _spawn()
	b.global_position.x += 100.0
	await _step(30)
	b.linear_velocity = -b.global_transform.basis.z * (140.0 / 3.6)
	var q0 := b.global_position
	_seat(b, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.throttle = 0.0
		i.flaps = 1.0
		i.pitch = 1.0
		i.yaw = Autopilot.hold_heading(ac.global_transform.basis, -ac.telemetry().angular_velocity_local.y, TestWorld.RUNWAY_DIR))
	for f in 60 * 120:
		await get_tree().physics_frame
		if b.linear_velocity.length() < 0.5:
			break
	var d2 := q0.distance_to(b.global_position)
	return [true, "Ausrollen aus 140 km/h: mit Bremse (ab 100 km/h) %.0f m, überschlagen %s | ohne Bremse %.0f m" % [d, nose, d2]]


## Rollrate bei vollem Querruder (Realistisch), stationär nach 1 s.
func test_perf_roll_rate() -> Array:
	var txt := ""
	for v in [200.0, 300.0, 400.0, 500.0]:
		var a := _spawn(false, 2000.0, v / 3.6, 1.0)
		a.place(a.global_transform, v / 3.6, 1.0, false)
		_seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
			i.assist_mode = FlightAssist.Mode.REALISTIC
			i.gear_down = false
			i.throttle = 1.0
			i.roll = 1.0)
		var pmax := 0.0
		var t90 := -1.0
		var ang := 0.0
		for f in 60 * 3:
			await get_tree().physics_frame
			var p := absf(a.telemetry().angular_velocity_local.z)
			pmax = maxf(pmax, p)
			ang += p / 60.0
			if ang >= PI * 0.5 and t90 < 0.0:
				t90 = f / 60.0
		txt += "%3.0f km/h: %3.0f°/s (90° in %.2f s) | " % [v, rad_to_deg(pmax), t90]
		a.queue_free()
		await _step(2)
	# Arcade-Grenze zum Vergleich
	return [true, "Rollrate Realistisch voll: " + txt]


## Sturz: aus 4.000 m, 60° Bahnneigung, Vollgas; max. Fahrt bis 1.000 m.
func test_perf_dive() -> Array:
	var a := _spawn(false, 4000.0, 100.0, 1.0)
	var b := Basis.looking_at((TestWorld.RUNWAY_DIR * 0.5 + Vector3.DOWN * 0.866).normalized(), Vector3.UP)
	a.place(Transform3D(b, Vector3(0, 4000, 0)), 100.0, 1.0, false)
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.gear_down = false
		i.throttle = 1.0
		# Bahnneigung -60° halten
		var gamma := asin(clampf(ac.linear_velocity.normalized().y, -1.0, 1.0))
		i.pitch = clampf((deg_to_rad(-60.0) - gamma) * 2.0, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0))
	var vmax := 0.0
	var hv := 0.0
	for f in 60 * 60:
		await get_tree().physics_frame
		var v := a.telemetry().airspeed
		if v > vmax:
			vmax = v
			hv = a.global_position.y
		if a.global_position.y < 1000.0:
			break
	var s := sqrt(FlightModel.air_density(hv) / 1.225)
	return [true, "Sturz 60° Vollgas ab 4.000 m: max %.0f km/h TAS (≈ %.0f km/h IAS) in %.0f m, Mach %.2f" % [
		kmh(vmax), kmh(vmax * s), hv, vmax / 330.0]]


## Verbrauch/Reichweite aus dem Schadensprofil (Liter, l/s) bei Vollgas und 60 % Gas.
func test_perf_fuel() -> Array:
	var a := _spawn(false, 2000.0, 120.0, 1.0)
	var f := a.damage.fuel
	var cap := f.capacity[0] + f.capacity[1]
	var full := f.burn_full_lps
	var cruise := lerpf(f.burn_idle_lps, f.burn_full_lps, 0.6)
	return [true, "Tank %.0f l, Vollgas %.0f l/h (%.0f min), 60 %% Gas %.0f l/h (%.0f min)" % [
		cap, full * 3600.0, cap / full / 60.0, cruise * 3600.0, cap / cruise / 60.0]]


## Reisefahrt bei 60 % Gas in 4.000 m (für die Reichweite).
func test_perf_cruise() -> Array:
	var a := _spawn(false, 4000.0, 110.0, 0.6)
	a.place(a.global_transform, 110.0, 0.6, false)
	var lg := _level_logic(4000.0)
	_seat(a, func(ac: Aircraft, i: PilotIntent, dt: float) -> void:
		lg.call(ac, i, dt)
		i.throttle = 0.6)
	await _step(60 * 90)
	return [true, "Reisefahrt 60 %% Gas, 4.000 m: %.0f km/h TAS" % kmh(a.telemetry().airspeed)]


## Abfangen aus steilem Sturz (Arcade voll gezogen), 600 km/h in 600 m.
func test_perf_dive_pullout() -> Array:
	var a := _spawn(false, 600.0, 166.0, 1.0)
	var b := Basis.looking_at((TestWorld.RUNWAY_DIR * 0.34 + Vector3.DOWN * 0.94).normalized(), Vector3.UP)
	a.place(Transform3D(b, Vector3(0, 600, 0)), 166.0, 1.0, false)
	_seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.gear_down = false
		i.throttle = 1.0
		i.pitch = 1.0)
	var txt := ""
	for f in 60 * 4:
		await get_tree().physics_frame
		var t := a.telemetry()
		if f % 20 == 0:
			txt += "%.1fs g%.1f aoa%.1f lim%.2f el%.2f h%.0f | " % [f / 60.0, t.g_load, rad_to_deg(t.aoa), a.assist.limiter_amount, t.commands.elevator, a.global_position.y]
	return [true, txt]
