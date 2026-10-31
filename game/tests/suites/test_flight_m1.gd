extends TestSuite
## M1/M1.1-Flugtests (aus dem alten test_runner.gd übernommen, unverändert in der Sache).
## Suite "fast". Gehört nach Paket 0 niemandem exklusiv – Änderungen nur in Paket 14.

const SUITE := "fast"


# ---------------------------------------------------------------------------

func test_intent_roundtrip() -> Array:
	var i := PilotIntent.new()
	i.pitch = 2.0; i.roll = -0.5; i.throttle = 0.7; i.flaps = 1.0; i.assist_mode = 1
	i.clamp_values()
	var j := PilotIntent.from_array(i.to_array())
	var ok := is_equal_approx(j.pitch, 1.0) and is_equal_approx(j.roll, -0.5) \
		and is_equal_approx(j.throttle, 0.7) and j.assist_mode == 1
	# M2: Tasten-Bits (alle 8 Kombinationen) und Abwärtskompatibilität (altes 8er-Array)
	var bits_ok := true
	for bits in 8:
		var k := PilotIntent.new()
		k.fire_primary = bits & 1 != 0
		k.fire_secondary = bits & 2 != 0
		k.eject = bits & 4 != 0
		k.gear_down = bits % 2 == 0
		var r := PilotIntent.from_array(k.to_array())
		var c := PilotIntent.new()
		c.copy_from(r)
		bits_ok = bits_ok and c.fire_primary == k.fire_primary and c.fire_secondary == k.fire_secondary \
			and c.eject == k.eject and c.gear_down == k.gear_down and c.button_bits() == bits
	var old := PilotIntent.from_array(PackedFloat32Array([0, 0, 0, 0.5, 0, 0, 0, 1]))
	bits_ok = bits_ok and not old.fire_primary and not old.eject and old.gear_down
	return [ok and bits_ok, "Intent serialisieren/klemmen, Tasten-Bits fire/secondary/eject"]


func test_takeoff_speed() -> Array:
	var a := _spawn()
	var liftoff_speed := -1.0
	var dist_start := a.global_position
	var roll_dist := 0.0
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.throttle = 1.0
		i.flaps = 0.5
		i.yaw = Autopilot.hold_heading(ac.global_transform.basis, -t.angular_velocity_local.y, TestWorld.RUNWAY_DIR)
		# Klassische Spornrad-Technik: Knüppel leicht nach vorn bis ~110 km/h, dann ziehen
		i.pitch = -0.2 if t.airspeed < 30.0 else 0.35)
	for f in 60 * 60:
		await get_tree().physics_frame
		var t := a.telemetry()
		if f > 60 and t.wheels_in_contact == 0 and liftoff_speed < 0.0:
			liftoff_speed = t.airspeed
			roll_dist = dist_start.distance_to(a.global_position)
		if liftoff_speed > 0.0 and a.telemetry().height_agl > 20.0:
			break
		if OS.has_environment("TRACE") and f % 60 == 0:
			print("  t=%2ds v=%5.1f km/h agl=%5.1f aoa=%5.1f pitch=%5.1f wheels=%d thrust=%5.0f pos=%s" % [f / 60, kmh(t.airspeed), t.height_agl, rad_to_deg(t.aoa), rad_to_deg(asin(-a.global_transform.basis.z.y)), t.wheels_in_contact, t.thrust, a.global_position])
	var kmh_v := kmh(liftoff_speed)
	var ok := kmh_v >= 120.0 and kmh_v <= 175.0 and a.telemetry().height_agl > 20.0
	return [ok, "Abheben bei %.0f km/h nach %.0f m, Höhe %.0f m" % [kmh_v, roll_dist, a.telemetry().height_agl]]


func test_top_speed() -> Array:
	var a := _spawn(false, 500.0, 120.0, 1.0)
	var alt_target := 500.0
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.gear_down = false
		i.throttle = 1.0
		# Höhe halten: Wunschsteigrate aus Höhenfehler
		var want_vs := clampf((alt_target - ac.global_position.y) * 0.3, -10.0, 10.0)
		i.pitch = clampf((want_vs - t.climb_rate) * 0.08, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0))
	var samples: Array[float] = []
	for f in 60 * 90:
		await get_tree().physics_frame
		if f > 60 * 75:
			samples.append(a.telemetry().airspeed)
	var mn: float = samples.min()
	var mx: float = samples.max()
	var avg := kmh((mn + mx) * 0.5)
	var stable := kmh(mx - mn) < 8.0
	var ok := stable and avg >= 470.0 and avg <= 530.0 and absf(a.global_position.y - alt_target) < 40.0
	return [ok, "Höchstgeschw. (Fahrwerk ein) %.0f km/h (Schwankung %.1f km/h, Höhe %.0f m)" % [avg, kmh(mx - mn), a.global_position.y]]


func test_stall() -> Array:
	# Realistisch-Modus, Gas raus, Knüppel voll ziehen -> Anstellwinkel steigt bis Abriss
	var a := _spawn(false, 1200.0, 70.0, 0.0)
	_seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.throttle = 0.0
		i.pitch = 1.0)
	var max_aoa := 0.0
	var max_stall := 0.0
	var stall_speed := -1.0
	for f in 60 * 20:
		await get_tree().physics_frame
		var t := a.telemetry()
		max_aoa = maxf(max_aoa, t.aoa)
		max_stall = maxf(max_stall, t.stall_amount)
		if t.stall_amount > 0.5 and stall_speed < 0.0:
			stall_speed = t.airspeed
	var ok := max_stall > 0.5 and rad_to_deg(max_aoa) > rad_to_deg(a.telemetry().stall_aoa)
	# Gegenprobe Arcade: Stall-Schutz verhindert Abriss
	var b := _spawn(false, 1200.0, 70.0, 0.0)
	b.global_position.x += 200
	_seat(b, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.throttle = 0.0
		i.pitch = 1.0)
	var arcade_max := 0.0
	for f in 60 * 8:
		await get_tree().physics_frame
		arcade_max = maxf(arcade_max, b.telemetry().stall_amount)
	ok = ok and arcade_max < 0.5
	return [ok, "Realistisch: Abriss bei %.0f km/h, max AoA %.1f° | Arcade max Abriss %.2f" % [
		kmh(stall_speed), rad_to_deg(max_aoa), arcade_max]]


func test_stall_speed_level() -> Array:
	# Realistisch, Leerlauf, Höhe halten -> Fahrt sinkt bis zum Abriss (1 g, ohne Klappen).
	var a := _spawn(false, 1000.0, 60.0, 0.0)
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.throttle = 0.0
		i.pitch = clampf(i.pitch + (0.0 - t.climb_rate) * 0.004 - t.angular_velocity_local.x * 0.05, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0))
	var stall_speed := -1.0
	for f in 60 * 60:
		await get_tree().physics_frame
		var t := a.telemetry()
		if OS.has_environment("TRACE") and f % 60 == 0:
			print("  t=%2ds v=%5.1f vs=%5.1f aoa=%5.1f stall=%.2f elev=%.2f" % [f / 60, kmh(t.airspeed), t.climb_rate, rad_to_deg(t.aoa), t.stall_amount, t.commands.elevator])
		if t.stall_amount > 0.5:
			stall_speed = t.airspeed
			break
	var v := kmh(stall_speed)
	var ok := v >= 140.0 and v <= 162.0
	return [ok, "Abriss im Horizontalflug bei %.0f km/h (ohne Klappen, Leerlauf)" % v]


func test_turn() -> Array:
	# Arcade: 60° Querlage halten und ziehen -> Kurs ändert sich deutlich, Höhe in Grenzen
	var a := _spawn(false, 800.0, 100.0, 1.0)
	var h0 := -a.global_transform.basis.z
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var bank := asin(clampf(-ac.global_transform.basis.x.y, -1.0, 1.0))  # + = rechts hängend
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.throttle = 1.0
		i.roll = clampf((deg_to_rad(60.0) - bank) * 2.0, -1.0, 1.0)
		i.pitch = 0.55 if bank > deg_to_rad(45.0) else 0.0)
	var turned := 0.0
	var prev := h0
	prev.y = 0
	for f in 60 * 12:
		await get_tree().physics_frame
		var h := -a.global_transform.basis.z
		h.y = 0
		turned += rad_to_deg(prev.signed_angle_to(h, Vector3.DOWN))  # + = nach rechts
		prev = h
	# 12 s Kurve bei ~60° Querlage: mind. 120° Kursänderung nach rechts, Höhe +-300 m
	var ok := turned > 120.0 and absf(a.global_position.y - 800.0) < 300.0
	return [ok, "Kursänderung %.0f° in 12 s, Höhe %.0f m, %.0f km/h" % [turned, a.global_position.y, kmh(a.telemetry().airspeed)]]


func test_mouse_aim_follow() -> Array:
	# PlayerController im Mouse-Aim-Modus: Zielrichtung 120° rechts und leicht hoch.
	# Das Flugzeug muss innerhalb von 15 s mit der Nase auf < 8° ans Ziel kommen.
	var a := _spawn(false, 800.0, 100.0, 0.9)
	var pc := PlayerController.new()
	pc.force_mouse_aim = true
	a.add_child(pc)
	a.pilot_seat.possess(pc)
	pc.throttle = 0.9
	var target := TestWorld.RUNWAY_DIR.rotated(Vector3.UP, deg_to_rad(-120.0))
	target = (target + Vector3.UP * 0.1).normalized()
	pc.aim_dir = target
	var err := 180.0
	var reached_t := -1.0
	for f in 60 * 15:
		await get_tree().physics_frame
		pc.aim_dir = target
		err = rad_to_deg((-a.global_transform.basis.z).angle_to(target))
		if err < 8.0 and reached_t < 0.0:
			reached_t = f / 60.0
	var ok := reached_t > 0.0 and err < 8.0 and a.telemetry().stall_amount < 0.3
	return [ok, "Maus-Ziel erreicht nach %.1f s, Restfehler %.1f°" % [reached_t, err]]


func test_mouse_aim_takeoff() -> Array:
	# Spieler im Arcade-Modus mit Maus-Ziel: Vollgas, Maus 8° über den Horizont -> startet.
	var a := _spawn()
	var pc := PlayerController.new()
	pc.force_mouse_aim = true
	a.add_child(pc)
	a.pilot_seat.possess(pc)
	pc.throttle = 1.0
	var target := (TestWorld.RUNWAY_DIR + Vector3.UP * tan(deg_to_rad(8.0))).normalized()
	var crashed := [false]
	a.crashed.connect(func(_x): crashed[0] = true)
	var min_up := 1.0
	for f in 60 * 40:
		await get_tree().physics_frame
		pc.aim_dir = target
		min_up = minf(min_up, a.global_transform.basis.y.y)
		if a.telemetry().height_agl > 50.0:
			break
	var ok: bool = a.telemetry().height_agl > 50.0 and not crashed[0] and min_up > 0.8
	return [ok, "Maus-Start: Höhe %.0f m, min. Aufrichtung %.2f, Crash=%s" % [a.telemetry().height_agl, min_up, crashed[0]]]


func test_brakes_stop() -> Array:
	# Am Boden mit 80 km/h rollen, Gas weg, bremsen -> steht innerhalb von 200 m
	var a := _spawn()
	await _step(60)
	a.linear_velocity = -a.global_transform.basis.z * 22.0
	var p0 := a.global_position
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.throttle = 0.0
		i.brakes = 1.0
		i.pitch = 1.0   # Knüppel gezogen gegen Kopfstand
		i.yaw = Autopilot.hold_heading(ac.global_transform.basis, -ac.telemetry().angular_velocity_local.y, TestWorld.RUNWAY_DIR))
	for f in 60 * 20:
		await get_tree().physics_frame
		if a.linear_velocity.length() < 0.5:
			break
	var d := p0.distance_to(a.global_position)
	var nose_over := a.global_transform.basis.y.y < 0.7
	var ok := a.linear_velocity.length() < 0.5 and d < 200.0 and not nose_over
	return [ok, "Bremsweg %.0f m, Restgeschw. %.1f m/s, überschlagen=%s" % [d, a.linear_velocity.length(), nose_over]]


func test_landing() -> Array:
	# Anflug in 60 m mit 180 km/h, sinken, abfangen, aufsetzen, ausrollen.
	var a := _spawn(false, 60.0, 50.0, 0.3)
	a.global_position = TestWorld.RUNWAY_START + Vector3(0, 60, 700)
	var crashed := [false]
	a.crashed.connect(func(_x): crashed[0] = true)
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.flaps = 1.0
		var want_vs := -3.0 if t.height_agl > 6.0 else -0.8
		if t.on_ground:
			i.throttle = 0.0
			i.pitch = 0.6
			i.brakes = 0.6 if t.airspeed < 25.0 else 0.0
		else:
			i.throttle = clampf(0.25 + (42.0 - t.airspeed) * 0.05, 0.0, 1.0) if t.height_agl > 6.0 else 0.0
			i.pitch = clampf((want_vs - t.climb_rate) * 0.12, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0)
		i.yaw = 0.0)
	var touchdown := -1.0
	var max_g := 0.0
	for f in 60 * 60:
		await get_tree().physics_frame
		var t := a.telemetry()
		if t.on_ground and touchdown < 0.0:
			touchdown = t.airspeed
		if touchdown > 0.0:
			max_g = maxf(max_g, t.g_load)
		if touchdown > 0.0 and t.airspeed < 1.0:
			break
		if OS.has_environment("TRACE") and f % 30 == 0:
			print("  t=%4.1f v=%5.1f vs=%5.1f agl=%5.1f wheels=%d up=%.2f pitch=%5.1f" % [f / 60.0, kmh(t.airspeed), t.climb_rate, t.height_agl, t.wheels_in_contact, a.global_transform.basis.y.y, rad_to_deg(asin(-a.global_transform.basis.z.y))])
	var up := a.global_transform.basis.y.y
	var ok: bool = touchdown > 0.0 and a.telemetry().airspeed < 1.0 and up > 0.9 and not crashed[0]
	return [ok, "Aufsetzen bei %.0f km/h, steht=%s, aufrecht=%.2f, Crash=%s" % [
		kmh(touchdown), a.telemetry().airspeed < 1.0, up, crashed[0]]]


func test_ai_stays_airborne() -> Array:
	# KI startet selbstständig von der Piste und kreist; danach 60 s Flug ohne Bodenkontakt.
	var a := _spawn()
	var ai := AIController.new()
	ai.behaviour = AIController.Behaviour.CIRCLE
	ai.cruise_altitude = 300.0
	ai.circle_center = TestWorld.RUNWAY_START + Vector3(0, 0, -1500)
	ai.circle_radius = 800.0
	a.add_child(ai)
	a.pilot_seat.possess(ai)
	var airborne_since := -1
	var min_alt := INF
	var max_alt := 0.0
	var f := 0
	var ok := false
	var t := a.telemetry()
	for k in 60 * 180:
		await get_tree().physics_frame
		f += 1
		if ai.phase == AIController.Phase.CRUISE:
			if airborne_since < 0:
				airborne_since = f
			min_alt = minf(min_alt, t.height_agl)
			max_alt = maxf(max_alt, t.height_agl)
			if t.on_ground:
				break
			if f - airborne_since > 60 * 60:
				ok = true
				break
	ok = ok and min_alt > 150.0
	return [ok, "KI: Reiseflug %.0f s, Höhe %.0f–%.0f m, %.0f km/h, Phase %d" % [
		(f - airborne_since) / 60.0 if airborne_since > 0 else 0.0, min_alt, max_alt, kmh(t.airspeed), ai.phase]]


func test_main_scene_loads() -> Array:
	var ps: PackedScene = load("res://world/main.tscn")
	if ps == null:
		return [false, "main.tscn lädt nicht"]
	var n := ps.instantiate()
	get_tree().root.add_child(n)
	await _step(120)
	var game := n as Game
	var ok := game != null and game.player_aircraft != null and game.ai_aircraft != null \
		and game.ai_aircraft.pilot_seat.controller is AIController \
		and game.player_aircraft.pilot_seat.controller is PlayerController
	n.queue_free()
	await _step(2)
	return [ok, "Hauptszene: Spieler- und KI-Flugzeug vorhanden"]


# --- M1.1 ------------------------------------------------------------------------

## Höchstgeschwindigkeit in 500 m nach 90 s Vollgas (Arcade, Höhe halten).
func _top_speed(gear_down: bool) -> float:
	var a := _spawn(false, 500.0, 120.0, 1.0)
	a.place(a.global_transform, 120.0, 1.0, gear_down)
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.gear_down = gear_down
		i.throttle = 1.0
		var want_vs := clampf((500.0 - ac.global_position.y) * 0.3, -10.0, 10.0)
		i.pitch = clampf((want_vs - t.climb_rate) * 0.08, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0))
	await _step(60 * 90)
	var v := a.telemetry().airspeed
	a.queue_free()
	await _step(2)
	return v


func test_arcade_mouse_pull() -> Array:
	# Tester-Szenario: Arcade + Mouse-Aim, bei 360 km/h Maus schlagartig 60° hoch.
	# Der Stall-Schutz soll bis nahe an den Abriss ziehen lassen, ohne Flattern.
	var a := _spawn(false, 1500.0, 100.0, 1.0)
	var pc := PlayerController.new()
	pc.force_mouse_aim = true
	pc.gear_down = false
	a.place(a.global_transform, 100.0, 1.0, false)
	a.add_child(pc)
	a.pilot_seat.possess(pc)
	pc.throttle = 1.0
	pc.parking_brake = false
	var fwd := TestWorld.RUNWAY_DIR
	pc.aim_dir = fwd
	await _step(60)
	var v0 := a.telemetry().airspeed
	var up := (fwd * cos(deg_to_rad(60.0)) + Vector3.UP * sin(deg_to_rad(60.0))).normalized()
	var max_aoa := 0.0
	var max_stall := 0.0
	var g: Array[float] = []
	for f in 60 * 3:
		pc.aim_dir = up
		await get_tree().physics_frame
		var t := a.telemetry()
		max_aoa = maxf(max_aoa, t.aoa)
		max_stall = maxf(max_stall, t.stall_amount)
		if f >= 30 and f < 150:   # Haltephase (0,5–2,5 s), bevor die Nase das Ziel erreicht
			g.append(t.g_load)
	var mean := 0.0
	for x in g:
		mean += x
	mean /= g.size()
	var sd := 0.0
	for x in g:
		sd += (x - mean) * (x - mean)
	sd = sqrt(sd / g.size())
	# Flattern: Abweichung vom gleitenden 0,5-s-Mittel (ohne den langsamen Fahrtverlust)
	var jit := 0.0
	var nj := 0
	for k in range(15, g.size() - 15):
		var m := 0.0
		for j in range(k - 15, k + 15):
			m += g[j]
		jit += pow(g[k] - m / 30.0, 2.0)
		nj += 1
	jit = sqrt(jit / maxf(nj, 1))
	var ok := rad_to_deg(max_aoa) >= 10.0 and max_stall <= 0.3 and sd < 0.3 and jit < 0.1
	return [ok, "Start %.0f km/h: max AoA %.1f°, Abriss %.2f, G Mittel %.2f / Std.-Abw. %.2f / Flattern %.3f" % [
		kmh(v0), rad_to_deg(max_aoa), max_stall, mean, sd, jit]]


func test_realistic_pitch_rate() -> Array:
	# Realistisch, 360 km/h, Taste "ziehen" voll (mit Tastaturrampe): Nickrate <= 50°/s.
	var a := _spawn(false, 1500.0, 100.0, 1.0)
	a.place(a.global_transform, 100.0, 1.0, false)
	var kb := [0.0]
	_seat(a, func(_ac: Aircraft, i: PilotIntent, dt: float) -> void:
		i.assist_mode = FlightAssist.Mode.REALISTIC
		i.gear_down = false
		i.throttle = 1.0
		kb[0] = move_toward(kb[0], 1.0, PlayerController.KEY_RAMP * dt)
		i.pitch = kb[0])
	var q_max := 0.0
	var aoa_max := 0.0
	for f in 60 * 2:
		await get_tree().physics_frame
		q_max = maxf(q_max, a.telemetry().angular_velocity_local.x)
		aoa_max = maxf(aoa_max, a.telemetry().aoa)
	var ok := rad_to_deg(q_max) <= 50.0 and rad_to_deg(q_max) >= 25.0
	return [ok, "Realistisch voll gezogen bei 360 km/h: Nickrate max %.0f°/s, AoA max %.1f°" % [
		rad_to_deg(q_max), rad_to_deg(aoa_max)]]


func test_climb_rate() -> Array:
	# Realistisch, Vollgas, Fahrwerk eingefahren, Fahrt 270 km/h halten -> Steigrate.
	var a := _spawn(false, 300.0, 75.0, 1.0)
	a.place(a.global_transform, 75.0, 1.0, false)
	var speed := 75.0
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
	for f in 60 * 30:
		await get_tree().physics_frame
		if f > 60 * 15:
			s += a.telemetry().climb_rate
			n += 1
	var vs := s / n
	var ok := vs >= 13.0 and vs <= 16.0
	return [ok, "Steigrate bei %.0f km/h (Fahrwerk ein): %.1f m/s" % [kmh(a.telemetry().airspeed), vs]]


func test_gear_top_speed() -> Array:
	var v_up := await _top_speed(false)
	var v_down := await _top_speed(true)
	var ok := v_up > v_down + 15.0 / 3.6
	return [ok, "Höchstgeschw. Fahrwerk ein %.0f km/h, aus %.0f km/h" % [kmh(v_up), kmh(v_down)]]


func test_gear_ground_lock() -> Array:
	# Am Boden: Einfahren wird verweigert (Gewicht auf den Rädern), auch per Intent.
	var a := _spawn()
	var pc := PlayerController.new()
	a.add_child(pc)
	a.pilot_seat.possess(pc)
	await _step(60)
	var accepted := pc.toggle_gear()
	# Auch ein Intent "einfahren" (z. B. vom Netz) darf am Boden nichts bewirken
	var c := _seat(a, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.gear_down = false
		i.brakes = 1.0)
	await _step(60 * 3)
	var t := a.telemetry()
	var ok := not accepted and pc.gear_down and t.gear_extension > 0.999 and t.gear_blocked \
		and t.wheels_in_contact >= 2
	# In der Luft: Einfahren dauert ~5–8 s
	var b := _spawn(false, 800.0, 80.0, 0.8)
	b.global_position.x += 300
	_seat(b, func(_ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		i.gear_down = false
		i.throttle = 0.8
		i.assist_mode = FlightAssist.Mode.ARCADE)
	var t_up := -1.0
	for f in 60 * 12:
		await get_tree().physics_frame
		if b.telemetry().gear_extension <= 0.001 and t_up < 0.0:
			t_up = f / 60.0
	ok = ok and t_up >= 5.0 and t_up <= 8.0
	return [ok, "Am Boden: Einfahren verweigert=%s, Fahrwerk %.0f %% | Luft: eingefahren nach %.1f s" % [
		not accepted, t.gear_extension * 100.0, t_up]]


func test_belly_landing() -> Array:
	# Landung mit eingefahrenem Fahrwerk: Rumpf rutscht, kommt zum Stehen, bleibt aufrecht.
	var a := _spawn(false, 30.0, 50.0, 0.3)
	a.global_position = TestWorld.RUNWAY_START + Vector3(0, 30, 400)
	a.place(a.global_transform, 50.0, 0.3, false)
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.gear_down = false
		i.flaps = 1.0
		i.throttle = 0.0 if t.height_agl < 8.0 or t.on_ground else 0.25
		var want_vs := -2.5 if t.height_agl > 5.0 else -0.8
		i.pitch = 0.0 if t.on_ground else clampf((want_vs - t.climb_rate) * 0.12, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0))
	var touched := false
	var slide_start := Vector3.ZERO
	for f in 60 * 40:
		await get_tree().physics_frame
		var t := a.telemetry()
		if t.belly_contact and not touched:
			touched = true
			slide_start = a.global_position
		if touched and a.linear_velocity.length() < 0.5:
			break
		if OS.has_environment("TRACE") and f % 30 == 0:
			print("  t=%4.1f v=%5.1f agl=%5.2f belly=%s wheels=%d thr=%.0f pitch=%.1f" % [f / 60.0, kmh(t.airspeed), t.height_agl, t.belly_contact, t.wheels_in_contact, t.thrust, rad_to_deg(t.pitch_attitude)])
	var t := a.telemetry()
	var slide := slide_start.distance_to(a.global_position)
	var ok := touched and a.linear_velocity.length() < 0.6 and a.global_transform.basis.y.y > 0.85 \
		and t.gear_extension < 0.01 and slide < 400.0
	return [ok, "Bauchlandung: Kontakt=%s, Rutschweg %.0f m, Rest %.2f m/s, aufrecht %.2f, Fahrwerk %.0f %%" % [
		touched, slide, a.linear_velocity.length(), a.global_transform.basis.y.y, t.gear_extension * 100.0]]


func test_spawn_at_rest() -> Array:
	# Tester-Bug M1: Flugzeug rollte nach dem Start rückwärts. Jetzt: Parkbremse, steht still.
	var a := _spawn()
	var pc := PlayerController.new()
	a.add_child(pc)
	a.pilot_seat.possess(pc)
	var fwd := TestWorld.RUNWAY_DIR
	var p0 := a.global_position
	var min_v := 0.0
	for f in 60 * 5:
		await get_tree().physics_frame
		min_v = minf(min_v, a.linear_velocity.dot(fwd))
	var p1 := a.global_position
	var moved := Vector2(p1.x - p0.x, p1.z - p0.z).length()
	# Parkbremse löst bei Gas > 10 %: dann rollt es vorwärts an
	pc.throttle = 0.5
	await _step(60 * 3)
	var v_fwd := a.linear_velocity.dot(fwd)
	var ok := moved < 0.05 and min_v > -0.1 and not pc.parking_brake and v_fwd > 1.0
	return [ok, "5 s nach Spawn: Weg %.3f m, min. Vorwärtsgeschw. %+.3f m/s | Gas 50 %%: %.1f m/s" % [
		moved, min_v, v_fwd]]
