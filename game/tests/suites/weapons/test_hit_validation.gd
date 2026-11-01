extends TestSuite
## Paket 5: FireEvent, TransformHistory, HitValidator – echte Treffer angenommen,
## Katalog gefälschter Berichte zu 100 % abgelehnt.

const P := preload("res://tests/suites/weapons/test_projectiles.gd")
const R := HitValidator.Result


func _box(pos: Vector3, size := Vector3(4, 4, 4), zone := 0) -> Node3D:
	var b := P.BoxNode.new()
	world.add_child(b)
	b.global_position = pos
	ProjectileSystem.register_target(b, P.TestBox.new(size, zone))
	return b


func test_transform_history() -> Array:
	var h := TransformHistory.new(64)
	for t in 100:
		h.record(1000 + t, Transform3D(Basis(), Vector3(t, 0, 0)))
	var ok := h.size() == 64 and h.newest_tick() == 1099 and h.oldest_tick() == 1036
	ok = ok and (h.at(1050) as Transform3D).origin.x == 50.0 and h.at(1035) == null \
			and h.at(1100) == null
	return [ok, "64 Einträge, %d..%d" % [h.oldest_tick(), h.newest_tick()]]


func test_fire_event_roundtrip() -> Array:
	var e := FireEvent.new()
	e.shooter_id = 3
	e.gun_group = 0
	e.tick_on = 100
	e.tick_off = 160
	var f := FireEvent.from_array(e.to_array())
	var n := f.max_shots(0.1, 1.0 / 60.0)
	return [f.contains(100) and f.contains(159) and not f.contains(160) and n == 11,
			"Phase 100–160, max. %d Schuss je Waffe" % n]


func test_fake_reports_rejected() -> Array:
	var v := projectiles.validator
	# Schütze A zielt auf Box B (250 m), Schütze C schießt ins Leere.
	var a := _spawn(false, 1500.0, 0.0, 0.0)
	a.freeze = true
	var c := _spawn(false, 1500.0, 0.0, 0.0)
	c.freeze = true
	c.global_position += Vector3(200, 0, 0)
	c.global_rotation = Vector3(0.5, 0, 0)    # nach oben
	var b := _box(a.global_transform * Vector3(0, 0.95, -250))
	var far := _box(a.global_transform * Vector3(0, 300, -250))
	var fire := [true]
	_seat(a, func(_a, i: PilotIntent, _dt): i.fire_primary = fire[0])
	_seat(c, func(_a, i: PilotIntent, _dt): i.fire_primary = fire[0])
	var hits_before := (b as P.BoxNode).hits
	await _step(20)
	fire[0] = false
	await _step(30)
	var genuine := (b as P.BoxNode).hits - hits_before
	if genuine < 4 or v.rejected != 0 or v.accepted != genuine:
		return [false, "echte Treffer %d, angenommen %d, abgelehnt %d %s" % [genuine,
				v.accepted, v.rejected, v.reasons]]
	var now := Engine.get_physics_frames()
	var aid := ProjectileSystem.id_of(a)
	var cid := ProjectileSystem.id_of(c)
	var bid := ProjectileSystem.id_of(b)
	# Vorlage: ein echter, schon verbrauchter Treffer von A (Schuss 0) – Tick aus Bahn
	var s0 := v.shot(aid, 0)
	var base := HitValidator.HitReport.new()
	base.shooter_id = aid
	base.shot_id = 0
	base.target_id = bid
	base.zone = 0
	var t_hit := int(round(250.0 / 790.0 * 60.0)) + s0.tick
	base.tick = t_hit
	var fakes := {}
	fakes["doppelt"] = base.duplicate_report()
	var r := base.duplicate_report(); r.shooter_id = 987654; fakes["Schütze unbekannt"] = r
	r = base.duplicate_report(); r.shot_id = a.weapons.shot_counter + 5; fakes["Schuss nie gefallen"] = r
	r = base.duplicate_report(); r.shot_id = -3; fakes["Schuss-ID negativ"] = r
	# Fehlschüsse von C (unverbraucht, echt) als gefälschte Treffer
	var cs := v.shot(cid, 1)
	var cbase := base.duplicate_report()
	cbase.shooter_id = cid
	cbase.shot_id = 1
	cbase.tick = cs.tick + 20
	fakes["Ziel nie in der Bahn"] = cbase.duplicate_report()
	r = cbase.duplicate_report(); r.target_id = 424242; fakes["Ziel unbekannt"] = r
	r = cbase.duplicate_report(); r.target_id = cid; fakes["Selbsttreffer"] = r
	r = cbase.duplicate_report(); r.tick = now + 5; fakes["Tick in der Zukunft"] = r
	r = cbase.duplicate_report(); r.tick = cs.tick; fakes["Tick = Schusstick"] = r
	r = cbase.duplicate_report(); r.tick = cs.tick - 10; fakes["vor dem Schuss"] = r
	r = cbase.duplicate_report(); r.tick = cs.tick + 300; fakes["Flugzeit überschritten"] = r
	r = cbase.duplicate_report(); r.local_point = Vector3(0, 40, 0); fakes["Punkt außerhalb Ziel"] = r
	r = cbase.duplicate_report(); r.target_id = ProjectileSystem.id_of(far); fakes["falsches Ziel"] = r
	r = cbase.duplicate_report(); r.latency = 5.0; fakes["hohe Latenz"] = r
	r = cbase.duplicate_report(); r.zone = 3; fakes["falsche Zone"] = r
	# Schüsse außerhalb einer Abzugsphase bzw. über der Kadenz (Server-Buchhaltung manipuliert)
	var w: WeaponDef = a.weapons.mounts()[0].weapon
	v.record_shot(a, 0, 5000, now - 2, Vector3.ZERO, Vector3.FORWARD * 800, w)
	r = base.duplicate_report(); r.shot_id = 5000; r.tick = now - 1; fakes["ohne Abzug"] = r
	for k in 4:
		v.record_shot(a, 0, 6000 + k, s0.tick, s0.pos, s0.vel, w)
	r = base.duplicate_report(); r.shot_id = 6003; fakes["über Kadenz"] = r
	# Rechte Lage, aber Tick ohne Verlauf (zu alt)
	r = cbase.duplicate_report(); r.tick = now - 200; fakes["Tick zu alt"] = r
	var passed: Array[String] = []
	for name in fakes:
		var res := v.validate(fakes[name], now)
		if res == R.OK:
			passed.append(name)
	if not passed.is_empty():
		return [false, "durchgelassen: %s" % ", ".join(passed)]
	return [true, "%d/%d Fälschungen abgelehnt, %d echte Treffer angenommen, 0 Fehlablehnungen" % [
			fakes.size(), fakes.size(), genuine]]


## Bewegtes Ziel mit Latenz-Toleranz: echter, ungenutzter Schuss, Bericht mit leicht
## verschobenem Punkt (2 m) wird angenommen, 8 m daneben abgelehnt.
func test_tolerance() -> Array:
	projectiles.validate_hits = false
	var v := projectiles.validator
	var a := _spawn(false, 1500.0, 0.0, 0.0)
	a.freeze = true
	var b := _box(a.global_transform * Vector3(0, 0.95, -250), Vector3(6, 6, 6))
	var fire := [true]
	_seat(a, func(_a, i: PilotIntent, _dt): i.fire_primary = fire[0])
	var ticks := {}
	CombatEvents.bus().hit_confirmed.connect(func(s, _t, _z, _d): ticks[ticks.size()] = Engine.get_physics_frames())
	await _step(3)
	fire[0] = false
	await _step(30)
	var aid := ProjectileSystem.id_of(a)
	var s0 := v.shot(aid, 0)
	if s0 == null or ticks.is_empty():
		return [false, "kein Schuss/Treffer"]
	var r := HitValidator.HitReport.new()
	r.shooter_id = aid
	r.shot_id = 0
	r.target_id = ProjectileSystem.id_of(b)
	r.zone = 0
	r.tick = ticks[0]
	var x0: Transform3D = ProjectileSystem.target_by_id(r.target_id).history.at(r.tick - 1)
	var n := r.tick - s0.tick
	var p := Ballistics.advance(s0.pos, s0.vel, s0.weapon.ballistic_k, 1.0 / 60.0, n - 1)
	r.local_point = x0.affine_inverse() * (p[0] as Vector3) + Vector3(0, 2, 0)
	var far := r.duplicate_report()
	far.local_point += Vector3(0, -2, 8)
	var res_far := v.validate(far, Engine.get_physics_frames())
	var res_ok := v.validate(r, Engine.get_physics_frames())
	return [res_ok == R.OK and res_far != R.OK, "2 m: %s, 8 m: %s" % [R.keys()[res_ok], R.keys()[res_far]]]
