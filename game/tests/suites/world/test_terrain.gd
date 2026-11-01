extends TestSuite
## Paket 12: Gelände (Höhenkarte, Kacheln, Flugplätze).

const TEST_SUITES := {"test_terrain_takeoff_landing": "slow"}


func make_world() -> Node3D:
	return TerrainWorld.new()


func _tw() -> TerrainWorld:
	return world as TerrainWorld


func test_terrain_data() -> Array:
	var tw := _tw()
	var size_mb := FileAccess.get_file_as_bytes(TerrainWorld.DATA_PATH).size() / 1048576.0
	var d: float = (tw.airfield(0).center as Vector3).distance_to(tw.airfield(1).center)
	var types := {}
	for t in tw.targets():
		types[t.type] = true
	var tiles := tw.terrain_root.get_child_count()
	# Flugplätze eben: Höhenspanne über die Pistenfläche
	var span := 0.0
	for ai in tw.airfield_count():
		var c: Vector3 = tw.airfield(ai).center
		var mn := INF
		var mx := -INF
		for k in 200:
			var p := c + Vector3(randf_range(-40, 40), 0, randf_range(-470, 470))
			var h := tw.height_at_terrain(p.x, p.z)
			mn = minf(mn, h)
			mx = maxf(mx, h)
		span = maxf(span, mx - mn)
	var hs := tw.heights
	var lo := INF
	var hi := -INF
	for i in range(0, hs.size(), 97):
		lo = minf(lo, hs[i])
		hi = maxf(hi, hs[i])
	var ok := size_mb < 30.0 and d > 22000.0 and d < 28000.0 and types.size() == 4 and span < 0.3 and tiles >= 256 and hi - lo > 150.0
	return [ok, "Datei %.1f MB, Plätze %.1f km auseinander, Pistenspanne %.2f m, Zieltypen %s, Höhen %.0f–%.0f m, Kacheln %d" % [
		size_mb, d / 1000.0, span, ",".join(PackedStringArray(types.keys())), lo, hi, tiles]]


func test_height_matches_physics() -> Array:
	var tw := _tw()
	await _step(2)
	var space := tw.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var max_err := 0.0
	var misses := 0
	for k in 400:
		var x := rng.randf_range(-19900, 19900)
		var z := rng.randf_range(-19900, 19900)
		if k < 40:   # auch auf Kachelgrenzen und Gitterlinien
			x = -20000.0 + 2500.0 * rng.randi_range(1, 15) + (0.0 if k % 2 == 0 else rng.randf_range(-30, 30))
			z = rng.randf_range(-19900, 19900)
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 2000, z), Vector3(x, -500, z), Layers.WORLD)
		var r := space.intersect_ray(q)
		if r.is_empty():
			misses += 1
			continue
		max_err = maxf(max_err, absf(r.position.y - tw.height_at(x, z)))
	var ok := misses == 0 and max_err < 0.01
	return [ok, "400 Raycasts: max. Abweichung height_at %.4f m, Fehltreffer %d" % [max_err, misses]]


func test_world_ground_provider() -> Array:
	var tw := _tw()
	var p: Vector3 = tw.airfield(1).center
	var h := WorldGround.height_at(p.x + 300, p.z + 2000)
	var ok := WorldGround.provider == tw and absf(h - tw.height_at(p.x + 300, p.z + 2000)) < 1e-4
	return [ok, "WorldGround nutzt TerrainWorld: %s" % ok]


func test_spawn_on_airfield() -> Array:
	var tw := _tw()
	var a := Aircraft.create(load(FIGHTER), false)
	world.add_child(a)
	a.place_on_ground(tw.runway_spawn(), TerrainWorld.RUNWAY_DIR)
	var p0 := a.global_position
	await _step(300)
	var moved := p0.distance_to(a.global_position)
	var agl := a.global_position.y - tw.height_at(a.global_position.x, a.global_position.z)
	var ok := moved < 0.5 and a.telemetry().wheels_in_contact >= 2 and agl > 0.3 and agl < 4.0
	return [ok, "5 s nach Spawn auf Platz Blau: Weg %.3f m, Räder %d, Höhe über Grund %.2f m" % [moved, a.telemetry().wheels_in_contact, agl]]


func test_terrain_takeoff_landing() -> Array:
	# Start auf Platz Blau bis 60 m über Grund, dann Anflug und Landung auf demselben Platz.
	var tw := _tw()
	var a := Aircraft.create(load(FIGHTER), false)
	world.add_child(a)
	a.place_on_ground(tw.runway_spawn(), TerrainWorld.RUNWAY_DIR)
	var crashed := [false]
	a.crashed.connect(func(_x): crashed[0] = true)
	var c: Vector3 = tw.airfield(0).center
	var thr := tw.runway_start(0)
	var st := {"phase": 0}
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		var pos := ac.global_position
		var agl := pos.y - tw.height_at(pos.x, pos.z)
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0)
		i.throttle = 1.0
		i.flaps = 0.5
		i.yaw = Autopilot.hold_heading(ac.global_transform.basis, -t.angular_velocity_local.y, TerrainWorld.RUNWAY_DIR)
		i.pitch = -0.2 if t.airspeed < 30.0 else 0.35
		if agl > 60.0:
			st.phase = 1
		)
	var liftoff := -1.0
	for f in 60 * 40:
		await get_tree().physics_frame
		if f > 60 and a.telemetry().wheels_in_contact == 0 and liftoff < 0.0:
			liftoff = a.telemetry().airspeed
		if st.phase >= 1:
			break
	var took_off: bool = st.phase >= 1 and not crashed[0]
	# Landung: Anflug aus 60 m Höhe über der Schwelle, 700 m vor der Piste (wie M1-Test)
	a.place(Transform3D(Basis.looking_at(TerrainWorld.RUNWAY_DIR, Vector3.UP), thr + Vector3(0, 60, 700)), 50.0, 0.3)
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		var pos := ac.global_position
		var agl := pos.y - tw.height_at(pos.x, pos.z)
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.flaps = 1.0
		var want_vs := -3.0 if agl > 6.0 else -0.8
		if t.on_ground:
			i.throttle = 0.0
			i.pitch = 0.6
			i.brakes = 0.6 if t.airspeed < 25.0 else 0.0
		else:
			i.throttle = clampf(0.25 + (42.0 - t.airspeed) * 0.05, 0.0, 1.0) if agl > 6.0 else 0.0
			i.pitch = clampf((want_vs - t.climb_rate) * 0.12, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0)
		i.yaw = 0.0)
	var touchdown_pos := Vector3.INF
	for f in 60 * 60:
		await get_tree().physics_frame
		var t := a.telemetry()
		if t.on_ground and touchdown_pos == Vector3.INF:
			touchdown_pos = a.global_position
		if touchdown_pos != Vector3.INF and t.airspeed < 1.0:
			break
	var on_rwy: bool = touchdown_pos != Vector3.INF and absf(a.global_position.x - c.x) < 25.0 and absf(a.global_position.z - c.z) < 480.0
	var up := a.global_transform.basis.y.y
	var ok: bool = took_off and liftoff > 0.0 and on_rwy and a.telemetry().airspeed < 1.0 and up > 0.9 and not crashed[0]
	return [ok, "Abheben bei %.0f km/h; Landung: steht=%s auf Piste=%s, aufrecht %.2f, Crash=%s" % [kmh(liftoff), a.telemetry().airspeed < 1.0, on_rwy, up, crashed[0]]]
