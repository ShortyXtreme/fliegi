extends TestSuite
## M3.11 Feinschliff (Punkte 2–6): Massen- und Trägheitskopplung, Motor (Drehmoment,
## P-Faktor, Drall, Kühlung, Verbrauch), IAS-Anzeige, Rollreibung, g-Toleranz des Piloten.
## Suite "fast".


## Punkt 2: Munitionsmasse. Verschossene Munition macht das Flugzeug leichter
## (40 g je Schuss inkl. Gurtglied), Nachladen (place/refill) stellt die Masse wieder her.
func test_ammo_mass_coupling() -> Array:
	var a := _spawn(false, 1500.0, 120.0, 0.8)
	await _step(3)
	var m_full := a.mass
	var full_kg := a.weapons.ammo_mass_full_kg()
	var taken := 0
	for mg in a.weapons.magazines:
		taken += mg.take(300)
	await _step(3)
	var drop := m_full - a.mass
	var want := taken * 0.040
	a.place(a.global_transform, 120.0, 0.8, false)
	await _step(3)
	var back := a.mass
	var ok := full_kg > 30.0 and absf(drop - want) < 0.6 and absf(back - m_full) < 0.6
	return [ok, "Munition voll %.1f kg, %d Schuss verschossen: −%.2f kg (Soll %.2f), nach Nachladen %.1f kg (vorher %.1f)" % [
		full_kg, taken, drop, want, back, m_full]]


## Punkt 3: Trägheitsmomente. Voll 8.000/9.000/4.400 kg m² (Roskam), mit leeren Tanks und
## leerer Munition sinken Gieren und Rollen um Δm·r² (Tanks ±1,0 m, Waffen ±2,35 m),
## Nicken kaum.
func test_inertia_loading() -> Array:
	var a := _spawn(false, 1500.0, 120.0, 0.8)
	await _step(3)
	var i_full := a.inertia
	a.damage.fuel.liters = PackedFloat32Array([0.0, 0.0])
	for mg in a.weapons.magazines:
		mg.take(mg.count)
	await _step(3)
	var i_empty := a.inertia
	var d := i_full - i_empty
	var ok := i_full.is_equal_approx(Vector3(8000, 9000, 4400)) and d.z > 350.0 and d.z < 700.0 \
		and d.y > 350.0 and d.y < 700.0 and d.x < 120.0 and a.mass < 2500.0 - 290.0
	return [ok, "Trägheit voll %s, leer %s (Δ %s), Masse leer %.0f kg" % [i_full, i_empty, d, a.mass]]


# --- Punkt 4: Motor -------------------------------------------------------------

static func _heading(a: Aircraft) -> float:
	var f := -a.global_transform.basis.z
	return atan2(-f.x, -f.z)    # + = nach links gedreht


## Startlauf mit Vollgas, Heck unten, 10 s. rudder_k > 0: Seitenruder hält den Kurs
## (P-Regler auf Kursfehler und Gierrate). Rückgabe [Kursänderung links (°), max |Seitenruder|,
## Fahrt km/h].
func _takeoff_run(mode: int, rudder_k: float) -> Array:
	var a := _spawn(true)
	await _step(5)
	var h0 := _heading(a)
	var rmax := [0.0]
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.assist_mode = mode
		i.throttle = 1.0
		i.gear_down = true
		i.pitch = 0.0
		var err := _heading(ac) - h0
		var r := 0.0
		if rudder_k > 0.0:
			r = clampf(err * rudder_k + ac.telemetry().angular_velocity_local.y * 1.5, -1.0, 1.0)
		rmax[0] = maxf(rmax[0], absf(r))
		i.yaw = r)
	var hmax := 0.0
	for k in 600:
		await get_tree().physics_frame
		hmax = maxf(hmax, absf(rad_to_deg(_heading(a) - h0)))
	var dh := rad_to_deg(_heading(a) - h0)
	var v := a.telemetry().airspeed * 3.6
	a.queue_free()
	await _step(2)
	return [dh, rmax[0], v, hmax]


## Vorzeichen: rechtsdrehender Propeller -> Rückdrehmoment rollt links (+z), P-Faktor und
## Drall drehen die Nase links (+y).
func test_prop_moment_signs() -> Array:
	var a := _spawn(false, 1000.0, 60.0, 1.0)
	await _step(2)
	var m_static := a.flight.prop_moments(0.0, 12000.0, 700000.0, deg_to_rad(12.0), 1.225)
	var m_roll := a.flight.prop_moments(40.0, 9000.0, 700000.0, deg_to_rad(12.0), 1.225)
	var m_fast := a.flight.prop_moments(130.0, 4300.0, 700000.0, deg_to_rad(0.5), 1.225)
	var ok := m_static.z > 0.0 and m_static.y > 0.0 and m_roll.y > 0.0 and m_fast.y < m_roll.y
	return [ok, "Moment (Nicken/Gieren/Rollen, N m): Stand %s, 145 km/h %s, 470 km/h %s" % [
		m_static.round(), m_roll.round(), m_fast.round()]]


## Realistisch zieht der Startlauf ohne Seitenruder nach links; mit Seitenruder lässt sich
## der Kurs halten (≤ 60 % Ausschlag, Stil B). Arcade gleicht weitgehend aus.
func test_prop_takeoff_swing() -> Array:
	var free := await _takeoff_run(FlightAssist.Mode.REALISTIC, 0.0)
	var held := await _takeoff_run(FlightAssist.Mode.REALISTIC, 4.0)
	var arc := await _takeoff_run(FlightAssist.Mode.ARCADE, 0.0)
	var ok: bool = free[0] > 4.0 and held[3] < 3.0 and held[1] < 0.6 \
		and arc[3] < 4.0
	return [ok, "Startlauf 10 s Vollgas: Realistisch ohne Seitenruder %.1f° links (%.0f km/h), mit Seitenruder max. Abweichung %.1f° bei max. %.0f %% Ausschlag, Arcade ohne Seitenruder max. %.1f°" % [
		free[0], free[2], held[3], held[1] * 100.0, arc[3]]]



## Kühlung (Modell allein, 15 °C Luft): Temperatur nach t s bei fester Wellenleistung.
static func _cool(d: AircraftData, power_frac: float, v: float, wash: float, secs: float,
		t0 := 80.0) -> PropEngine:
	var e := PropEngine.new(d)
	e.coolant_temp = t0
	e.shaft_power = d.engine_power_w * power_frac
	var n := int(secs * 10.0)
	for k in n:
		e.update_cooling(0.1, v, wash, 15.0)
	return e


## Sollwerte: Vollgas-Steigflug 230 km/h ≈ 100 °C (Auslegung), Reiseflug 400 km/h Vollgas
## deutlich darunter mit halb geschlossener Klappe, Vollgas im Stand überhitzt in 1–3 min,
## Leerlauf am Boden bleibt 15 min unter der Warnung. Danach Leistungsabfall.
func test_cooling_model() -> Array:
	var d: AircraftData = load(FIGHTER)
	var climb := _cool(d, 1.0, 230.0 / 3.6, 0.0, 1200.0)
	var cruise := _cool(d, 1.0, 400.0 / 3.6, 5.0, 1200.0)
	var idle := _cool(d, d.idle_throttle, 0.0, 10.0, 900.0, 15.0)
	# Vollgas im Stand: Zeit bis zur Warnung und bis zur Leistungsgrenze
	var e := PropEngine.new(d)
	e.coolant_temp = 80.0
	e.shaft_power = d.engine_power_w
	var t_warn := -1.0
	var t_hot := -1.0
	for k in 3000:
		e.update_cooling(0.1, 0.0, 50.0, 15.0)
		if t_warn < 0.0 and e.coolant_temp >= d.coolant_warn:
			t_warn = k * 0.1
		if t_hot < 0.0 and e.coolant_temp >= d.coolant_hot:
			t_hot = k * 0.1
	e.coolant_temp = d.coolant_hot + 10.0
	var mul_hot := e.heat_power_mul()
	var ok := absf(climb.coolant_temp - 100.0) < 4.0 and cruise.coolant_temp < 92.0 \
		and cruise.radiator < 0.9 and idle.coolant_temp < d.coolant_warn \
		and t_warn > 40.0 and t_warn < 180.0 and t_hot > t_warn and absf(mul_hot - 0.8) < 0.01
	return [ok, "Steigflug 230 km/h %.0f °C (Klappe %.2f), 400 km/h %.0f °C (Klappe %.2f), Leerlauf Boden 15 min %.0f °C; Vollgas im Stand: Warnung nach %.0f s, %d °C nach %.0f s; Leistung bei +10 K über Grenze ×%.2f" % [
		climb.coolant_temp, climb.radiator, cruise.coolant_temp, cruise.radiator, idle.coolant_temp,
		t_warn, int(d.coolant_hot), t_hot, mul_hot]]


## Überhitzung im Flug: Leistung sinkt, die Motorzone verliert HP, die Motorlampe wird rot.
func test_overheat_damage() -> Array:
	var a := _spawn(false, 1500.0, 110.0, 1.0)
	_seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.throttle = 1.0
		i.gear_down = false)
	await _step(30)
	var thrust_ok := a.telemetry().thrust
	var hp0: float = a.damage.hp[DamageModel.Zone.ENGINE]
	for k in 300:
		a.flight.engine.coolant_temp = 140.0
		await get_tree().physics_frame
	var thrust_hot := a.telemetry().thrust
	var hp1: float = a.damage.hp[DamageModel.Zone.ENGINE]
	var lamp := {}
	for l in FlightPanel.lamps(a, null, a.telemetry(), []):
		if l.id == "motor":
			lamp = l
	var ok := thrust_hot < thrust_ok * 0.75 and hp1 < hp0 - 25.0 and int(lamp.get("level", 0)) == 2
	return [ok, "140 °C für 5 s: Schub %.0f -> %.0f N, Motor-HP %.0f -> %.0f, Lampe %s" % [
		thrust_ok, thrust_hot, hp0, hp1, lamp.get("text", "?")]]


## Verbrauch folgt der abgegebenen Leistung: Vollgas in 7.000 m (über der Volldruckhöhe,
## ρ-Anteil ≈ 0,72) verbraucht weniger als in 500 m.
func test_fuel_follows_power() -> Array:
	var r := []
	for alt in [500.0, 7000.0]:
		var a := _spawn(false, alt, 120.0, 1.0)
		_seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
			i.assist_mode = FlightAssist.Mode.ARCADE
			i.throttle = 1.0
			i.gear_down = false)
		await _step(60)
		var f0 := a.damage.fuel.total()
		await _step(600)
		r.append([(f0 - a.damage.fuel.total()) * 360.0, a.telemetry().engine_power_fraction])
		a.queue_free()
		await _step(2)
	var ratio: float = r[1][0] / maxf(r[0][0], 1e-3)
	var ok: bool = r[0][0] > 300.0 and r[0][0] < 345.0 and ratio > 0.65 and ratio < 0.85
	return [ok, "Vollgas 500 m: %.0f l/h (Leistung %.2f), 7.000 m: %.0f l/h (Leistung %.2f), Verhältnis %.2f" % [
		r[0][0], r[0][1], r[1][0], r[1][1], ratio]]


# --- Punkt 5: Fahrtmesser und Rollreibung ----------------------------------------

## Fahrtmesser (Flug-Panel) zeigt IAS: in 4.000 m bei 400 km/h wahrer Fahrt ≈ 327 km/h.
func test_airspeed_indicator_ias() -> Array:
	var a := _spawn(false, 4000.0, 400.0 / 3.6, 1.0)
	await _step(2)
	var d := FlightPanel.gather(a, null, null)
	var want := a.telemetry().airspeed * 3.6 * sqrt(FlightModel.air_density(a.global_position.y) / 1.225)
	var ok: bool = absf(d.speed_kmh - want) < 1.0 and d.speed_kmh < d.tas_kmh * 0.85
	return [ok, "Anzeige %.0f km/h (IAS), wahre Fahrt %.0f km/h" % [d.speed_kmh, d.tas_kmh]]


## Rollreibung Gras 0,045: Ausrollen mit Leerlauf von 15 auf 8 m/s, mittlere Verzögerung
## ≈ μ·g − Leerlaufschub/m (≈ 0,44 − 0,15 m/s²).
func test_grass_rolling_friction() -> Array:
	var a := _spawn(true)
	await _step(5)
	var mu: float = a.data.wheels[0].rolling_friction
	_seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.throttle = 0.0
		i.brakes = 0.0
		i.gear_down = true)
	await _step(5)
	a.linear_velocity = -a.global_transform.basis.z.slide(Vector3.UP).normalized() * 15.0
	var t := 0.0
	var v0 := -1.0
	var t0 := 0.0
	for k in 1200:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var v := a.linear_velocity.length()
		if v0 < 0.0 and v <= 14.0:
			v0 = v
			t0 = t
		if v0 > 0.0 and v <= 8.0:
			break
	var decel := (v0 - a.linear_velocity.length()) / maxf(t - t0, 1e-3)
	var ok := is_equal_approx(mu, 0.045) and decel > 0.2 and decel < 0.6
	return [ok, "μ_Roll %.3f, Ausrollen 14 -> 8 m/s: %.2f m/s² in %.1f s" % [mu, decel, t - t0]]
