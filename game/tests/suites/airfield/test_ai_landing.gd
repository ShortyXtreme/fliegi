extends TestSuite
## M3 Paket 9b: KI ohne Munition fliegt zurück (RTB), Platzrunde, Landung, Einrollen
## bis zum Abstellplatz. Abnahme: 10 Seeds ≥ 8/10 ohne Schaden bis zum Abstellplatz.

const SUITE := "slow"
const TERRAIN_SCENE := "res://world/terrain/terrain_world.tscn"
const U := preload("res://tests/suites/airfield/airfield_util.gd")


func make_world() -> Node3D:
	return (load(TERRAIN_SCENE) as PackedScene).instantiate()


## Eine Rückkehr: [ok, Sekunden, Text]
func _run_landing(seed: int, spot: int, field := 1, block_s := 0.0) -> Array:
	var t := world as TerrainWorld
	var l := t.airfield_layout(field)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed) ^ 0x1a9d
	var a := Aircraft.create(load(U.FIGHTER), false)
	a.nation_id = l.nation_id
	world.add_child(a)
	var start := l.to_scene(Vector3(rng.randf_range(-2500, 2500), 0, rng.randf_range(-3500, 1500)))
	start.y = maxf(start.y, l.center.y) + rng.randf_range(350, 700)
	var fwd := Vector3.FORWARD.rotated(Vector3.UP, rng.randf_range(-PI, PI))
	a.place(Transform3D(Basis.looking_at(fwd, Vector3.UP), start), rng.randf_range(60, 80), 0.8, false)
	a.weapons.set_ammo_fraction(0.0)
	var br := AIPilotBrain.new()
	br.rng_seed = seed
	br.airfield = AirfieldPhases.new()
	br.airfield.auto_restart = false
	br.airfield.trace_enabled = true
	br.airfield.setup(l, RunwayControl.find_or_create(world, field), spot, AirfieldPhases.Phase.COMBAT)
	a.add_child(br)
	a.pilot_seat.possess(br)
	var ph := br.airfield
	var crashed := [false]
	a.crashed.connect(func(_x): crashed[0] = true)
	var hp0 := a.damage.health_fraction()
	var trace := OS.has_environment("TRACE")
	var done_t := -1.0
	var blocker := Node.new()
	world.add_child(blocker)
	var rc := RunwayControl.find_or_create(world, field)
	if block_s > 0.0:
		rc.request(blocker)
	var landed_blocked := false
	for f in 60 * 600:
		await get_tree().physics_frame
		if block_s > 0.0 and f / 60.0 >= block_s:
			rc.release(blocker)
		if rc.holds(blocker) and a.telemetry().on_ground:
			landed_blocked = true
		if trace and f % 60 == 0:
			print("  t=%3d %s" % [f / 60, U.trace_line(a, ph)])
		if ph.phase == AirfieldPhases.Phase.PARKED and a.linear_velocity.length() < 0.3:
			done_t = f / 60.0
			break
		if crashed[0] or a.damage.outcome == DamageModel.Outcome.CRASHED:
			break
	var spot_d := a.global_position.distance_to(l.parking_transform(spot).origin) - a.data.ground_height
	var dmg: bool = a.damage.health_fraction() < hp0 - 1e-4 or crashed[0]
	var ok: bool = done_t > 0.0 and not dmg and not landed_blocked and spot_d < 6.0 and a.global_transform.basis.y.y > 0.9
	var txt := "Seed %d: %s nach %.0f s, Platzabstand %.1f m, Schaden %s, Durchstarten %d, Phase %s [%s]" % [
		seed, "abgestellt" if done_t > 0 else "NICHT abgestellt", done_t if done_t > 0 else f_time(ph),
		spot_d, dmg, ph.go_arounds, ph.phase_name(), ",".join(ph.trace)]
	if trace:
		print(txt)
	a.queue_free()
	blocker.queue_free()
	var ga := []
	for e in ph.trace:
		if e.contains("Durchstarten"):
			ga.append(e.get_slice("(", 1).trim_suffix(")"))
	return [ok, done_t, txt, ga]


static func f_time(ph: AirfieldPhases) -> float:
	return ph._ticks / 60.0


func test_ai_landing_one() -> Array:
	var r := await _run_landing(_env_int("SEED", 1), _env_int("SPOT", 2))
	return [r[0], r[2]]


## Piste belegt: Durchstarten, keine Landung solange belegt; danach Landung (Platz Blau).
func test_ai_go_around_runway_busy() -> Array:
	var r := await _run_landing(7, 1, 0, 200.0)
	var ok: bool = r[0] and "Piste belegt" in r[3]
	return [ok, "Durchstarten: %s. %s" % [",".join(r[3]), r[2]]]


func test_ai_landing_10_seeds() -> Array:
	var good := 0
	var fails := []
	var worst := 0.0
	var gas := []
	for s in 10:
		var r := await _run_landing(200 + s, s % 6)
		gas.append_array(r[3])
		if r[0]:
			good += 1
			worst = maxf(worst, r[1])
		else:
			fails.append(r[2])
	return [good >= 8, "%d/10 Landungen bis zum Abstellplatz ohne Schaden, längste %.0f s, Durchstarten %d (%s). %s" % [
		good, worst, gas.size(), ",".join(gas), " | ".join(fails)]]


static func _env_int(n: String, d: int) -> int:
	return int(OS.get_environment(n)) if OS.has_environment(n) else d
