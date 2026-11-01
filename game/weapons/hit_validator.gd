class_name HitValidator
extends RefCounted
## Server-Trefferprüfung (Plan M2 §2, Paket 5). Jeder Treffer – auch die eigenen des Servers
## und der KI – läuft als HitReport hier durch, bevor Schaden entsteht.
## Prüfungen: Schütze/Schuss bekannt, nicht doppelt, Abzugsphase (FireEvent) und Kadenz,
## Ziel bekannt und nicht der Schütze, Tick im Verlauf (TransformHistory, ≈ 1 s), Flugzeit,
## Nachrechnen der Bahn: Abstand Trefferpunkt ↔ Geschoss-Segment im Zielsystem
## ≤ tolerance + Latenzanteil, Zone durch die Hitboxen bestätigt.
## Schüsse meldet das ProjectileSystem (record_shot in spawn()); Ziele kommen aus
## ProjectileSystem.targets() mit ihrem Verlauf.

enum Result { OK, UNKNOWN_SHOOTER, UNKNOWN_SHOT, DUPLICATE, NO_FIRE_EVENT, CADENCE,
		UNKNOWN_TARGET, SELF_HIT, FUTURE_TICK, NO_HISTORY, BEFORE_SHOT, FLIGHT_TIME,
		OUTSIDE_TARGET, POSITION, ZONE }

## Positions-Toleranz (m), Plan: ≤ 3 m.
var tolerance := 3.0
## Latenzanteil: zusätzlich Zielgeschwindigkeit × Latenz × latency_factor, gedeckelt.
var latency_factor := 0.5
var max_latency_s := 0.25
## Schüsse so lange aufbewahren (s), danach unbekannt.
var keep_time := 2.0
var accepted := 0
var rejected := 0
## Ablehnungen je Result (Statistik).
var reasons := {}

static var current: HitValidator = null

## shooter_id -> {shot_id -> Shot}
var _shots := {}
var _dt := 1.0 / 60.0


class Shot:
	var shooter: WeakRef
	var gun := 0
	var tick := 0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var weapon: WeaponDef
	var used := false


class HitReport:
	var shooter_id := 0
	var shot_id := 0
	var target_id := 0
	var zone := -1
	var tick := 0
	var local_point := Vector3.ZERO
	## Latenz des meldenden Peers (s); Server/KI 0.
	var latency := 0.0

	func duplicate_report() -> HitReport:
		var r := HitReport.new()
		r.shooter_id = shooter_id
		r.shot_id = shot_id
		r.target_id = target_id
		r.zone = zone
		r.tick = tick
		r.local_point = local_point
		r.latency = latency
		return r

	func to_array() -> Array:
		return [shooter_id, shot_id, target_id, zone, tick, local_point]


func _init() -> void:
	var tps := Engine.physics_ticks_per_second
	_dt = 1.0 / float(tps if tps > 0 else 60)


func clear() -> void:
	_shots.clear()
	accepted = 0
	rejected = 0
	reasons.clear()


func record_shot(shooter: Node, gun: int, shot_id: int, tick: int, pos: Vector3, vel: Vector3,
		weapon: WeaponDef) -> void:
	var sid := ProjectileSystem.id_of(shooter)
	if sid == 0:
		return
	var per: Dictionary = _shots.get(sid, {})
	if per.is_empty():
		_shots[sid] = per
	var s := Shot.new()
	s.shooter = weakref(shooter)
	s.gun = gun
	s.tick = tick
	s.pos = pos
	s.vel = vel
	s.weapon = weapon
	per[shot_id] = s
	if per.size() > 512 and shot_id % 64 == 0:
		_prune(per, tick)


func _prune(per: Dictionary, now: int) -> void:
	var lim := int(keep_time / _dt)
	for k in per.keys():
		if now - (per[k] as Shot).tick > lim:
			per.erase(k)


func knows_shooter(shooter_id: int) -> bool:
	return _shots.has(shooter_id)


func shot(shooter_id: int, shot_id: int) -> Shot:
	var per: Dictionary = _shots.get(shooter_id, {})
	return per.get(shot_id)


## Prüft einen Bericht; bei OK wird der Schuss verbraucht. now = aktueller Server-Tick.
func validate(r: HitReport, now: int) -> int:
	var res := _check(r, now)
	if res == Result.OK:
		accepted += 1
		shot(r.shooter_id, r.shot_id).used = true
	else:
		rejected += 1
		reasons[res] = int(reasons.get(res, 0)) + 1
	return res


func _check(r: HitReport, now: int) -> int:
	if not _shots.has(r.shooter_id):
		return Result.UNKNOWN_SHOOTER
	var s := shot(r.shooter_id, r.shot_id)
	if s == null or s.weapon == null:
		return Result.UNKNOWN_SHOT
	if s.used:
		return Result.DUPLICATE
	var fr := _check_fire_event(r, s)
	if fr != Result.OK:
		return fr
	if r.target_id == r.shooter_id:
		return Result.SELF_HIT
	var t := ProjectileSystem.target_by_id(r.target_id)
	if t == null:
		return Result.UNKNOWN_TARGET
	if r.tick > now:
		return Result.FUTURE_TICK
	var n := r.tick - s.tick
	if n < 1:
		return Result.BEFORE_SHOT
	if n * _dt > s.weapon.lifetime():
		return Result.FLIGHT_TIME
	var x1 = t.history.at(r.tick)
	var x0 = t.history.at(r.tick - 1)
	if x1 == null or x0 == null:
		return Result.NO_HISTORY
	var boxes := t.boxes()
	if boxes == null:
		return Result.UNKNOWN_TARGET
	var br := float(boxes.bounding_radius)
	if r.local_point.length() > br + tolerance:
		return Result.OUTSIDE_TARGET
	# Bahn nachrechnen: Segment des Ticks r.tick
	var a := Ballistics.advance(s.pos, s.vel, s.weapon.ballistic_k, _dt, n - 1)
	var b := Ballistics.advance(a[0], a[1], s.weapon.ballistic_k, _dt, 1)
	var lp0: Vector3 = (x0 as Transform3D).affine_inverse() * (a[0] as Vector3)
	var lp1: Vector3 = (x1 as Transform3D).affine_inverse() * (b[0] as Vector3)
	var tspeed := (x1 as Transform3D).origin.distance_to((x0 as Transform3D).origin) / _dt
	var tol := tolerance + tspeed * minf(maxf(r.latency, 0.0), max_latency_s) * latency_factor
	if _dist_point_segment(r.local_point, lp0, lp1) > tol:
		return Result.POSITION
	var hit: Dictionary = boxes.intersect_segment(lp0, lp1)
	if hit.is_empty() or int(hit.get("zone", -1)) != r.zone:
		return Result.ZONE
	return Result.OK


## Abzugsphase und Kadenz (nur wenn der Schütze ein WeaponSystem mit FireEvents hat).
func _check_fire_event(r: HitReport, s: Shot) -> int:
	var node = s.shooter.get_ref()
	var ws = node.get("weapons") if node != null else null
	if not ws is WeaponSystem:
		return Result.OK
	var w: WeaponSystem = ws
	var ms := w.mounts()
	if s.gun < 0 or s.gun >= ms.size():
		return Result.NO_FIRE_EVENT
	var m: GunMountDef = ms[s.gun]
	var e := w.fire_event_at(m.group, s.tick)
	if e == null:
		return Result.NO_FIRE_EVENT
	var guns := 0
	for mm in ms:
		if mm.group == m.group:
			guns += 1
	if r.shot_id < e.shot_first or r.shot_id - e.shot_first >= \
			e.max_shots(m.weapon.shot_interval(), _dt, s.tick) * guns:
		return Result.CADENCE
	# Schüsse derselben Waffe im selben Tick nur, wenn die Kadenz die Tickrate übersteigt
	var per_tick := int(ceil(_dt / m.weapon.shot_interval()))
	var same := 0
	for k in _shots[r.shooter_id]:
		var o: Shot = _shots[r.shooter_id][k]
		if o.gun == s.gun and o.tick == s.tick:
			same += 1
	if same > per_tick:
		return Result.CADENCE
	return Result.OK


static func _dist_point_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var d := b - a
	var f := clampf((p - a).dot(d) / maxf(d.length_squared(), 1e-9), 0.0, 1.0)
	return p.distance_to(a + d * f)
