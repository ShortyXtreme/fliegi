extends TestSuite
## Paket 13: Floating Origin. Dieselbe Flugbahn mit und ohne Verschiebung muss absolut
## (WorldOrigin.to_abs) auf ≤ 1 cm übereinstimmen; Gelände-Abfragen bleiben richtig.

const SECONDS := 40


func make_world() -> Node3D:
	return TerrainWorld.new()


func _fly(shifter: OriginShifter) -> Array:
	var tw := world as TerrainWorld
	var start_abs: Vector3 = tw.airfield(0).center + Vector3(0, 900, 0)
	var a := Aircraft.create(load(FIGHTER), false)
	world.add_child(a)
	var b := Basis.looking_at(Vector3(1, 0, -1).normalized(), Vector3.UP)
	a.place(Transform3D(b, WorldOrigin.to_local(start_abs)), 110.0, 0.9)
	_seat(a, func(ac: Aircraft, i: PilotIntent, _dt: float) -> void:
		var t := ac.telemetry()
		i.assist_mode = FlightAssist.Mode.ARCADE
		i.gear_down = false
		i.throttle = 0.9
		# flache Kurve (~6° Querneigung) bei 900 m über dem Platz, steigend/sinkend geregelt
		i.roll = clampf((ac.global_transform.basis.x.y + 0.1) * 3.0, -1.0, 1.0)
		var want_vs := clampf((start_abs.y - ac.global_position.y) * 0.3, -10.0, 10.0)
		i.pitch = clampf((want_vs - t.climb_rate) * 0.08, -1.0, 1.0))
	if shifter:
		shifter.focus = a
	var track: Array[Vector3] = []
	for f in 60 * SECONDS:
		await get_tree().physics_frame
		if f % 30 == 29:
			track.append(WorldOrigin.to_abs(a.global_position))
		if OS.has_environment("TRACE") and f < 400 and f % 20 == 0:
			print("  f=%d abs=%s v=%s off=%s" % [f, WorldOrigin.to_abs(a.global_position), a.linear_velocity, WorldOrigin.offset])
	a.queue_free()
	await _step(1)
	return track


func test_origin_shift_trajectory() -> Array:
	var ref := await _fly(null)
	var sh := OriginShifter.new()
	sh.enabled = not OS.has_environment("NOSHIFT")
	sh.threshold = 1000.0   # absichtlich klein (Spiel: 4 km): mehrere Verschiebungen
	world.add_child(sh)
	var got := await _fly(sh)
	var max_dev := 0.0
	for k in mini(ref.size(), got.size()):
		max_dev = maxf(max_dev, (ref[k] as Vector3).distance_to(got[k]))
	var travelled: float = ref[0].distance_to(ref[ref.size() - 1])
	var ok := sh.shift_count >= 3 and max_dev <= 0.01 and ref.size() == got.size()
	var msg := "%d Verschiebungen in %d s (%.1f km Strecke), max. Bahnabweichung %.2f mm" % [
		sh.shift_count, SECONDS, travelled / 1000.0, max_dev * 1000.0]
	sh.queue_free()
	return [ok, msg]


func test_origin_shift_terrain_queries() -> Array:
	var tw := world as TerrainWorld
	var sh := OriginShifter.new()
	world.add_child(sh)
	var p_abs := Vector3(7300.4, 0, -6100.7)
	var h_abs := tw.height_at_terrain(p_abs.x, p_abs.z)
	sh.shift(Vector3(5000, 0, -4000))
	await _step(2)
	var p := WorldOrigin.to_local(p_abs)
	var h_scene := tw.height_at(p.x, p.z)
	var space := tw.get_world_3d().direct_space_state
	var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 2000, p.z), Vector3(p.x, -500, p.z), Layers.WORLD))
	var ray_err := absf(r.position.y - h_scene) if not r.is_empty() else INF
	var ground := absf(WorldGround.height_at(p.x, p.z) - h_scene)
	var spawn_ok := absf(WorldOrigin.to_abs(tw.runway_spawn()).z - (tw.airfield(0).center.z + TerrainWorld.RUNWAY_LENGTH * 0.5 - 30.0)) < 0.01
	sh.queue_free()
	var ok := absf(h_scene - h_abs) < 1e-3 and ray_err < 0.01 and ground < 1e-4 and spawn_ok
	return [ok, "Nach Verschiebung: height_at Δ %.4f m, Raycast Δ %.4f m, WorldGround Δ %.5f m, Spawn absolut=%s" % [
		absf(h_scene - h_abs), ray_err, ground, spawn_ok]]


func test_origin_shift_switch_default_off() -> Array:
	var sh := OriginShifter.new()
	world.add_child(sh)
	var a := Aircraft.create(load(FIGHTER), false)
	world.add_child(a)
	a.place(Transform3D(Basis.IDENTITY, Vector3(9000, 800, 0)), 100.0, 0.8)
	sh.focus = a
	await _step(5)
	var ok := not sh.enabled and sh.shift_count == 0 and WorldOrigin.offset == Vector3.ZERO
	sh.queue_free()
	return [ok, "Schalter Standard aus: enabled=%s, Verschiebungen %d" % [sh.enabled, sh.shift_count]]
