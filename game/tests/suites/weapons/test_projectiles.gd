extends TestSuite
## Paket 2: Kadenz, Munition, Ringpuffer, Treffer auf bewegte Testbox, Leistung.

const DT := 1.0 / 60.0


## Test-Hitbox: eine OBB (lokal zentriert) mit Zone 0. Vertrags-Schnittstelle wie HitboxSet.
class TestBox:
	var half := Vector3.ONE
	var bounding_radius := 0.0
	var zone := 0

	func _init(size := Vector3(2, 2, 2), z := 0) -> void:
		half = size * 0.5
		bounding_radius = half.length()
		zone = z

	func intersect_segment(p0: Vector3, p1: Vector3) -> Dictionary:
		var d := p1 - p0
		var t0 := 0.0
		var t1 := 1.0
		for ax in 3:
			if absf(d[ax]) < 1e-9:
				if absf(p0[ax]) > half[ax]:
					return {}
				continue
			var a := (-half[ax] - p0[ax]) / d[ax]
			var b := (half[ax] - p0[ax]) / d[ax]
			t0 = maxf(t0, minf(a, b))
			t1 = minf(t1, maxf(a, b))
			if t0 > t1:
				return {}
		return {"zone": zone, "t": t0, "point": p0 + d * t0}


class BoxNode:
	extends Node3D
	var hits := 0
	var last_zone := -1

	func apply_hit(zone: int, _dmg: float, _att: Node, _lp: Vector3) -> void:
		hits += 1
		last_zone = zone


func _box(pos: Vector3, size := Vector3(2, 2, 2)) -> BoxNode:
	var b := BoxNode.new()
	world.add_child(b)
	b.global_position = pos
	ProjectileSystem.register_target(b, TestBox.new(size))
	return b


func _mg() -> WeaponDef:
	return load("res://weapons/data/mg_t1.tres")


func test_cadence_and_ammo() -> Array:
	var a := _spawn(false, 1500.0, 100.0, 0.8)
	var shots := [0]
	a.weapons.fired.connect(func(_g, _s): shots[0] += 1)
	var fire := [true]
	_seat(a, func(_a, i: PilotIntent, _dt): i.fire_primary = fire[0])
	var mx := a.weapons.ammo_max()
	await _step(60)
	fire[0] = false
	await _step(10)
	var n1: int = shots[0]
	var ammo := a.weapons.ammo()
	# 600/min = 10/s je Waffe, 2 Waffen, 1 s Abzug → 20 (±1 Schuss je Waffe durch Tick-Raster)
	if n1 < 20 or n1 > 22:
		return [false, "Schüsse in 1 s: %d (erwartet 20–22)" % n1]
	if ammo != mx - n1:
		return [false, "Zähler %d ≠ %d − %d" % [ammo, mx, n1]]
	# leeres Magazin feuert nicht
	for m in a.weapons.magazines:
		m.count = 2
	fire[0] = true
	await _step(60)
	fire[0] = false
	await _step(2)
	var n2: int = shots[0] - n1
	if n2 != 4 or a.weapons.ammo() != 0:
		return [false, "leer: %d Schüsse, Rest %d" % [n2, a.weapons.ammo()]]
	var store := InfiniteAmmoStore.new()
	var got := a.weapons.rearm(store)
	if got != mx or a.weapons.ammo() != mx or int(store.issued[&"7.92mm"]) != mx:
		return [false, "Nachladen %d, Bestand %d" % [got, a.weapons.ammo()]]
	if a.weapons.fire_events.size() != 2 or a.weapons.fire_events[0].tick_off < 0:
		return [false, "FireEvents: %d" % a.weapons.fire_events.size()]
	return [true, "%d Schuss/s, Zähler %d/%d, Nachladen ok" % [n1, ammo, mx]]


func test_ring_buffer() -> Array:
	projectiles.set_physics_process(false)
	var w := _mg()
	var ends := [0]
	projectiles.impact.connect(func(_s, _p, _v, k, _t, _z): if k == ProjectileSystem.Impact.EXPIRED: ends[0] += 1)
	for i in 2100:
		projectiles.spawn(null, 0, i, Vector3(0, 1000, 0), Vector3(0, 0, -800), w)
	var ok: bool = projectiles.active_count() == ProjectileSystem.CAPACITY and ends[0] == 52
	projectiles.clear()
	return [ok and projectiles.active_count() == 0,
			"aktiv %d, überschrieben %d" % [ProjectileSystem.CAPACITY, ends[0]]]


func test_ground_impact() -> Array:
	projectiles.set_physics_process(false)
	projectiles.use_raycast = false   # nur WorldGround.height_at (Physik-Boden der Testwelt aus)
	var kind := [-1]
	projectiles.impact.connect(func(_s, _p, _v, k, _t, _z): kind[0] = k)
	projectiles.spawn(null, 0, 0, Vector3(0, 20, 0), Vector3(0, -800, 100), _mg())
	for t in 10:
		projectiles.step(DT, 100 + t)
	return [kind[0] == ProjectileSystem.Impact.GROUND and projectiles.active_count() == 0,
			"Einschlag Art %d" % kind[0]]


## Box fliegt 250 m/s quer und 250 m/s entgegen, Geschoss 800 m/s: relativ > 1.000 m/s,
## Box 2 m, Weg je Tick > 17 m. Ohne Abzug der Zielbewegung kein sicherer Treffer.
func test_hit_moving_box_high_speed() -> Array:
	projectiles.set_physics_process(false)
	var w := _mg()
	var b := _box(Vector3.ZERO)
	var bv := Vector3(250, 0, 250)
	var hits := 0
	var trials := 40
	var tick := Engine.get_physics_frames() + 1
	for k in trials:
		projectiles.clear()
		var hit_at := 0.4 + 0.013 * k          # Treffzeitpunkt variiert über die Tick-Phase
		var shot_from := Vector3(0, 1000, 0)
		var vel := Vector3(0, 0, -800)
		# Ort des Geschosses zur Zeit hit_at (gleiche Integration wie das System)
		var n := int(hit_at / DT)
		var r := Ballistics.advance(shot_from, vel, w.ballistic_k, DT, n)
		var r2 := Ballistics.advance(r[0], r[1], w.ballistic_k, DT, 1)
		var meet: Vector3 = (r[0] as Vector3).lerp(r2[0], (hit_at - n * DT) / DT)
		var b0 := meet - bv * hit_at
		var before := b.hits
		b.global_position = b0
		ProjectileSystem.register_target(b, TestBox.new())
		projectiles.step(DT, tick)   # Ziel-Vortick erfassen
		tick += 1
		projectiles.spawn(null, 0, k, shot_from, vel, w)
		var t := 0.0
		for s in 60:
			t += DT
			b.global_position = b0 + bv * t
			projectiles.step(DT, tick)
			tick += 1
			if projectiles.active_count() == 0:
				break
		if b.hits > before:
			hits += 1
	# Gegenprobe: 5 m daneben → kein Treffer
	projectiles.clear()
	var miss_before := b.hits
	b.global_position = Vector3(0, 1000, -300) - bv * 0.4
	projectiles.step(DT, tick)
	tick += 1
	projectiles.spawn(null, 0, 99, Vector3(5, 1000, 20), Vector3(0, 0, -800), w)
	for s in 60:
		b.global_position += bv * DT
		projectiles.step(DT, tick)
		tick += 1
	var false_hit := b.hits > miss_before
	return [hits == trials and not false_hit,
			"%d/%d Treffer bei %.0f m/s relativ, Fehltreffer: %s" % [hits, trials,
			(Vector3(0, 0, -800) - bv).length(), false_hit]]


func test_aircraft_fires_on_box() -> Array:
	var a := _spawn(false, 1500.0, 0.0, 0.0)
	a.freeze = true
	var b := _box(a.global_transform * Vector3(0, 0.95, -250), Vector3(4, 4, 4))
	var confirmed := [0]
	CombatEvents.bus().hit_confirmed.connect(func(_s, t, _z, _d): if t == b: confirmed[0] += 1)
	var fire := [true]
	_seat(a, func(_a, i: PilotIntent, _dt): i.fire_primary = fire[0])
	await _step(30)
	fire[0] = false
	await _step(40)
	var fired := a.weapons.ammo_max() - a.weapons.ammo()
	return [b.hits >= fired - 1 and fired >= 8 and confirmed[0] == b.hits,
			"%d Schuss, %d Treffer auf 250 m" % [fired, b.hits]]


func test_perf_1000_shots_8_targets() -> Array:
	projectiles.set_physics_process(false)
	var w := _mg()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var boxes: Array[BoxNode] = []
	for j in 8:
		boxes.append(_box(Vector3(rng.randf_range(-300, 300), 1000 + rng.randf_range(-50, 50),
				rng.randf_range(-600, -100)), Vector3(10, 3, 8)))
	var tick := Engine.get_physics_frames() + 1
	projectiles.step(DT, tick)
	tick += 1
	for i in 1000:
		var dir := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.05, 0.05), -1).normalized()
		projectiles.spawn(null, i % 2, i, Vector3(rng.randf_range(-20, 20), 1000, 0), dir * 800, w)
	var total := 0
	var worst := 0
	var n := 30
	projectiles.step(DT, tick)   # Aufwärmen
	tick += 1
	for s in n:
		for j in 8:
			boxes[j].global_position += Vector3(80, 0, 60) * DT
		projectiles.step(DT, tick)
		tick += 1
		total += projectiles.last_step_usec
		worst = maxi(worst, projectiles.last_step_usec)
	var avg := total / float(n) / 1000.0
	return [avg <= 4.0, "%.2f ms/Tick im Mittel (max %.2f), %d aktiv, %d Treffer" % [avg,
			worst / 1000.0, projectiles.active_count(), projectiles.hits_total]]


func test_read_interface() -> Array:
	projectiles.set_physics_process(false)
	var w := _mg()
	for i in 10:
		projectiles.spawn(null, 0, i, Vector3(0, 1000, 0), Vector3(0, 0, -800), w)
	projectiles.step(DT, Engine.get_physics_frames() + 1)
	var tr := projectiles.tracer_slots()
	var act := projectiles.active_slots()
	var s := act[3]
	var ok: bool = act.size() == 10 and tr.size() == 2 and projectiles.position(s).z < projectiles.prev_position(s).z \
			and projectiles.weapon_of(s) == w and projectiles.age(s) > 0.0
	return [ok, "aktiv %d, Leuchtspur %d" % [act.size(), tr.size()]]
