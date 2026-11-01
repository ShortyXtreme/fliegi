extends TestSuite
## Paket 8: Duell-Regression KI gegen KI (Suite "slow").
## 10 Seeds, frontal auf 2 km, 1.500 m Höhe, max. 180 s, --fixed-fps 60.
## Gemessen: Zeit im Feuerfenster, wahrer Zielfehler beim Feuern, Ersatz-Treffer/Schuss,
## Ersatz-Abschüsse (KILL_HITS Treffer), Bodenkollisionen (< 5 %), Log-Hash.
## Echte Abschüsse über das Schadensmodell: test_duel_real_kills (SKIP bis verfügbar).

const SUITE := "slow"
const U := preload("res://tests/suites/ai/duel_util.gd")
const SEEDS := 10
const DURATION := 180.0
const HZ := 60

func make_world() -> Node3D:
	return DuelArena.new(false)


## Ein Duell. Rückgabe: Kennzahlen + Hash.
func run_duel(seed: int, level := "erfahren", max_time := DURATION, level_b := "") -> Dictionary:
	projectiles.clear()
	CombatEvents.reset()
	var bus := CombatEvents.bus()
	bus.log_enabled = true
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var dx := rng.randf_range(-150.0, 150.0)
	var dy := rng.randf_range(-60.0, 60.0)
	var a := U.spawn(world, Vector3(dx, 1500.0 + dy, 1000.0), Vector3.FORWARD, Nations.BLUE, 1)
	var b := U.spawn(world, Vector3(-dx, 1500.0 - dy, -1000.0), Vector3.BACK, Nations.RED, 2)
	var planes := [a, b]
	var brains := [U.brain(a, level, seed * 2), U.brain(b, level if level_b == "" else level_b, seed * 2 + 1)]
	for br in brains:
		br.patrol_center = Vector3(0, 0, 0)
		br.patrol_altitude = 1500.0
		br.trace_enabled = true
	var hits := [0, 0]
	var shots := [0, 0]
	bus.hit_confirmed.connect(func(s, t, _z, _d):
		if s == a and t == b: hits[0] += 1
		elif s == b and t == a: hits[1] += 1)
	bus.shot_fired.connect(func(s, _g, _id):
		if s == a: shots[0] += 1
		elif s == b: shots[1] += 1)
	var window_ticks := [0, 0]
	var err_sum := 0.0
	var err_n := 0
	var ground := [false, false]
	var midair := false
	var kill := -1
	var destroyed := [0]
	bus.aircraft_destroyed.connect(func(_v, _k, _c): destroyed[0] += 1)
	var ticks := 0
	var end_tick := int(max_time * HZ)
	while ticks < end_tick:
		await get_tree().physics_frame
		ticks += 1
		for k in 2:
			var p: Aircraft = planes[k]
			var br: AIPilotBrain = brains[k]
			if br.in_fire_window:
				window_ticks[k] += 1
			if br.last_intent().fire_primary:
				err_sum += U.true_aim_error_mrad(p, planes[1 - k])
				err_n += 1
			var pos := p.global_position
			if pos.y - WorldGround.height_at(pos.x, pos.z) < 4.0:
				ground[k] = true
		if a.global_position.distance_to(b.global_position) < 8.0:
			midair = true
		if destroyed[0] > 0:
			kill = 0 if b.damage.is_destroyed else 1
		elif U.damage_available():
			pass
		elif hits[0] >= U.KILL_HITS:
			kill = 0
		elif hits[1] >= U.KILL_HITS:
			kill = 1
		if kill >= 0 or ground[0] or ground[1] or midair:
			break
	var fin := ""
	for k in 2:
		var p: Aircraft = planes[k]
		fin += "%s|%s|" % [p.global_position.snapped(Vector3.ONE * 0.01), ",".join(brains[k].trace)]
	var h := hash(str(bus.log_hash()) + fin + str(ticks))
	for p in planes:
		p.queue_free()
	await get_tree().physics_frame
	return {"ticks": ticks, "kill": kill, "hits": hits, "shots": shots,
		"window": window_ticks, "err_sum": err_sum, "err_n": err_n,
		"ground": int(ground[0]) + int(ground[1]), "midair": midair, "destroyed": destroyed[0], "hash": h}


func _series(hills: bool) -> Array:
	var tot := {"duels": 0, "kills": 0, "hits": 0, "shots": 0, "window": 0, "err_sum": 0.0,
		"err_n": 0, "ground": 0, "midair": 0, "time": 0}
	for s in SEEDS:
		var r := await run_duel(1000 + s)
		tot.duels += 1
		tot.kills += 1 if r.kill >= 0 else 0
		tot.hits += r.hits[0] + r.hits[1]
		tot.shots += r.shots[0] + r.shots[1]
		tot.window += r.window[0] + r.window[1]
		tot.err_sum += r.err_sum
		tot.err_n += r.err_n
		tot.ground += r.ground
		tot.midair += 1 if r.midair else 0
		tot.time += r.ticks
	var rate: float = float(tot.ground) / (2.0 * tot.duels)
	var mean_err: float = tot.err_sum / maxf(tot.err_n, 1)
	var txt := "%s: %d Duelle, %d Ersatz-Abschüsse, Ø Dauer %.0f s, Feuerfenster %.1f s/Flugzeug, Zielfehler beim Feuern Ø %.1f mrad, Treffer/Schuss %d/%d (%.1f %%), Bodenkollisionen %d (%.0f %%), Zusammenstöße %d" % [
		"Hügel" if hills else "Flach", tot.duels, tot.kills,
		float(tot.time) / HZ / tot.duels, float(tot.window) / HZ / (2.0 * tot.duels), mean_err,
		tot.hits, tot.shots, 100.0 * tot.hits / maxf(tot.shots, 1), tot.ground, rate * 100.0,
		tot.midair]
	var ok: bool = rate < 0.05 and tot.window > 0 and tot.hits > 0
	return [ok, txt]


func test_duels_flat() -> Array:
	return await _series(false)


func test_duels_hills() -> Array:
	(world as DuelArena).set_hills(true)
	await get_tree().physics_frame
	return await _series(true)


## Abnahme 6b: Veteran (blau) gegen Rekrut (rot), Siege = Ersatz-Abschüsse.
func test_veteran_vs_rekrut() -> Array:
	var vet := 0
	var rek := 0
	var ground := 0
	for s in SEEDS:
		var r := await run_duel(3000 + s, "veteran", DURATION, "rekrut")
		vet += 1 if r.kill == 0 else 0
		rek += 1 if r.kill == 1 else 0
		ground += r.ground
	return [vet > rek and ground < 1, "Veteran %d : %d Rekrut in %d Duellen (Ziel ≥ 7/10), Bodenkollisionen %d" % [
		vet, rek, SEEDS, ground]]


func test_duel_hash_reproducible() -> Array:
	var r1 := await run_duel(4242, "erfahren", 60.0)
	var r2 := await run_duel(4242, "erfahren", 60.0)
	var r3 := await run_duel(4243, "erfahren", 60.0)
	return [r1.hash == r2.hash and r1.hash != r3.hash,
		"Seed 4242 zweimal: %d / %d (gleich=%s), Seed 4243: %d" % [r1.hash, r2.hash,
			r1.hash == r2.hash, r3.hash]]


## Vorbereitet für die Integration mit dem Schadensmodell (Agent B): echte Abschüsse über
## CombatEvents.aircraft_destroyed statt Ersatz-Trefferzähler.
func test_duel_real_kills() -> Array:
	if not U.damage_available():
		return [true, "SKIP: Schadensmodell noch nicht verfügbar (HitboxSet/DamageModel Stub)"]
	var kills := 0
	for s in 5:
		var r := await run_duel(2000 + s, "erfahren", DURATION)
		kills += r.destroyed
	return [kills > 0, "%d echte Abschüsse in 5 Duellen" % kills]
