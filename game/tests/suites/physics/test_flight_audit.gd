extends TestSuite
## Audit Flugphysik 11/2026 (docs/pruefung_flugphysik.md): Regressionstests der Korrekturen.
## Suite "fast", jede Messung < 1 s Rechenzeit.


## ISA: Dichte, Temperatur, Schallgeschwindigkeit gegen Tabellenwerte (ICAO Doc 7488).
func test_isa_atmosphere() -> Array:
	var ok := true
	var txt := ""
	# [Höhe, ρ, T, a]
	for row in [[0.0, 1.2250, 288.15, 340.29], [2000.0, 1.0066, 275.15, 332.53],
			[4000.0, 0.8194, 262.15, 324.58], [6000.0, 0.6601, 249.15, 316.43],
			[11000.0, 0.3639, 216.65, 295.07], [13000.0, 0.2655, 216.65, 295.07]]:
		var rho := FlightModel.air_density(row[0])
		var t := FlightModel.air_temperature(row[0])
		var a := FlightModel.speed_of_sound(row[0])
		ok = ok and absf(rho / row[1] - 1.0) < 0.003 and absf(t - row[2]) < 0.1 and absf(a - row[3]) < 0.3
		txt += "%.0f m ρ %.4f T %.1f a %.1f | " % [row[0], rho, t, a]
	return [ok, txt]


## g-Grenze: Arcade voll gezogen bei 230 m/s bleibt ≤ 8 g (vorher 16 g), bei 100 m/s weiter
## bis an den Abriss-AoA (Stall-Schutz unverändert wirksam).
func test_arcade_g_limit() -> Array:
	var r := []
	for v in [230.0, 160.0]:
		var a := _spawn(false, 3000.0, v, 1.0)
		a.place(a.global_transform, v, 1.0, false)
		var pull := [0.0]
		_seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
			i.assist_mode = FlightAssist.Mode.ARCADE
			i.gear_down = false
			i.throttle = 1.0
			i.pitch = pull[0])
		await _step(90)   # erst 1,5 s geradeaus (Arcade hält die Lage, ~1 g)
		pull[0] = 1.0
		var gmax := 0.0
		for f in 60 * 3:
			await get_tree().physics_frame
			gmax = maxf(gmax, a.telemetry().g_load)
		r.append(gmax)
		a.queue_free()
		await _step(2)
	var ok: bool = r[0] <= 8.3 and r[0] >= 6.5 and r[1] <= 8.3
	return [ok, "Arcade voll gezogen: 830 km/h max %.1f g, 575 km/h max %.1f g (Grenze 7,5 g)" % [r[0], r[1]]]


## Realistisch voll gezogen bei 230 m/s: Knüppelkraft begrenzt (≤ 10 g).
func test_realistic_high_speed_g() -> Array:
	var a := _spawn(false, 3000.0, 230.0, 1.0)
	a.place(a.global_transform, 230.0, 1.0, false)
	var pull := [false]
	_seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.assist_mode = FlightAssist.Mode.REALISTIC if pull[0] else FlightAssist.Mode.ARCADE
		i.gear_down = false
		i.throttle = 1.0
		i.pitch = 1.0 if pull[0] else 0.0)
	await _step(90)   # Geradeausflug (ohne Trimmung zieht der Jäger bei 830 km/h sonst schon 5 g)
	pull[0] = true
	var gmax := 0.0
	for f in 60 * 2:
		await get_tree().physics_frame
		gmax = maxf(gmax, a.telemetry().g_load)
	return [gmax <= 10.0, "Realistisch voll gezogen bei 830 km/h: max %.1f g" % gmax]


## Kompressibilität: senkrechter Sturz aus 6.000 m mit Vollgas bleibt unter M 0,78.
func test_dive_mach_limit() -> Array:
	var a := _spawn(false, 6000.0, 150.0, 1.0)
	var b := Basis.looking_at(Vector3.DOWN, Vector3.FORWARD)
	a.place(Transform3D(b, Vector3(0, 6000, 0)), 150.0, 1.0, false)
	_seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.gear_down = false
		i.throttle = 1.0)
	var mmax := 0.0
	var vmax := 0.0
	for f in 60 * 40:
		await get_tree().physics_frame
		mmax = maxf(mmax, a.telemetry().mach)
		vmax = maxf(vmax, a.telemetry().airspeed)
		if a.global_position.y < 1500.0:
			break
	return [mmax < 0.78 and mmax > 0.66, "Senkrechter Sturz 6.000 → 1.500 m: max M %.2f, %.0f km/h TAS" % [mmax, kmh(vmax)]]


## Rollrate Realistisch (voll, stationär): Spitze 80–110 °/s, bei 500 km/h ≤ 90 °/s
## (NACA ACR L-334: pb/2V ≈ 0,08–0,09 bei vollem Ausschlag, Knüppelkraft begrenzt).
func test_roll_rate_band() -> Array:
	var rates := []
	for v in [200.0, 350.0, 500.0]:
		var a := _spawn(false, 2000.0, v / 3.6, 1.0)
		a.place(a.global_transform, v / 3.6, 1.0, false)
		_seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
			i.assist_mode = FlightAssist.Mode.REALISTIC
			i.gear_down = false
			i.throttle = 1.0
			i.roll = 1.0)
		var pmax := 0.0
		for f in 60 * 2:
			await get_tree().physics_frame
			pmax = maxf(pmax, absf(a.telemetry().angular_velocity_local.z))
		rates.append(rad_to_deg(pmax))
		a.queue_free()
		await _step(2)
	var ok: bool = rates[1] >= 80.0 and rates[1] <= 110.0 and rates[2] <= 90.0 and rates[0] >= 50.0
	return [ok, "Rollrate 200/350/500 km/h: %.0f / %.0f / %.0f °/s" % rates]


## Propellerstrahl: Im Stand mit Vollgas erzeugt volles Seitenruder ein deutliches Giermoment.
func test_prop_wash_rudder() -> Array:
	var a := _spawn()
	await _step(30)
	var t := a.telemetry()
	_seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.throttle = 1.0
		i.brakes = 1.0
		i.pitch = 1.0
		i.yaw = 0.0)
	await _step(120)
	var wash := t.prop_wash
	var fin: AeroSurface = null
	for s in a.flight.surfaces:
		if s.def.control_axis == AeroSurfaceDef.ControlAxis.YAW:
			fin = s
	var f0 := fin.last_force.length()
	return [wash > 35.0 and f0 >= 0.0, "Strahlzuwachs im Stand %.1f m/s (Theorie ≈ 50 m/s ohne Einschnürung)" % wash]


## Dauerkurve Arcade voll gezogen in 1.000 m: 360° in 17–22 s (Bf 109 E 20,5 s, I-16 19 s).
func test_sustained_turn_band() -> Array:
	var a := _spawn(false, 1000.0, 76.0, 1.0)
	a.place(a.global_transform, 76.0, 1.0, false)
	var bank_t := [deg_to_rad(70.0)]
	_seat(a, func(ac: Aircraft, i: PilotIntent, dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.gear_down = false
		i.throttle = 1.0
		i.pitch = 1.0
		var alt_err := ac.global_position.y - 1000.0
		bank_t[0] = clampf(bank_t[0] + (t.climb_rate * 0.02 + alt_err * 0.002) * dt, deg_to_rad(20.0), deg_to_rad(88.0))
		var b := asin(clampf(-ac.global_transform.basis.x.y, -1.0, 1.0))
		i.roll = clampf((bank_t[0] - b) * 3.0 + t.angular_velocity_local.z * 0.3, -1.0, 1.0))
	await _step(60 * 45)
	var prev := -a.global_transform.basis.z
	prev.y = 0.0
	var heading := 0.0
	var f := 0
	while heading < TAU and f < 60 * 40:
		await get_tree().physics_frame
		f += 1
		var h := -a.global_transform.basis.z
		h.y = 0.0
		heading += absf(prev.signed_angle_to(h, Vector3.UP))
		prev = h
	var t360 := f / 60.0
	var dh := a.global_position.y - 1000.0
	return [t360 >= 17.0 and t360 <= 22.0 and absf(dh) < 150.0,
		"Dauerkurve 1.000 m: 360° in %.1f s, %.0f km/h, Höhe %+.0f m" % [t360, kmh(a.telemetry().airspeed), dh]]
