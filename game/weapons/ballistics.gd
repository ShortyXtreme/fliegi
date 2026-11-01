class_name Ballistics
extends RefCounted
## Deterministische Außenballistik als reine Funktionen (Plan M2 §2).
## a = g − k·|v|·v, halbimplizites Euler-Verfahren mit SUBSTEPS Teilschritten je Tick.
## Dieselbe Rechnung nutzen ProjectileSystem (inline), HitValidator, LeadSolver, HUD und KI.

const GRAVITY := Vector3(0, -9.81, 0)
const SUBSTEPS := 2
## Tabellen für time_of_flight()/drop()/speed_at(): Schrittweite und Länge (m).
const TABLE_STEP := 25.0
const TABLE_RANGE := 2500.0

static var _tables := {}


## Ein Tick (dt) für ein Geschoss. Gibt [pos, vel] zurück.
static func step(pos: Vector3, vel: Vector3, k: float, dt: float) -> Array:
	return advance(pos, vel, k, dt, 1)


## n Ticks vorrechnen. Gibt [pos, vel] nach n Ticks zurück.
static func advance(pos: Vector3, vel: Vector3, k: float, dt: float, n: int) -> Array:
	var h := dt / SUBSTEPS
	for j in n * SUBSTEPS:
		vel += (GRAVITY - vel * (k * vel.length())) * h
		pos += vel * h
	return [pos, vel]


## Bahn tickweise rechnen, bis die Ebene durch plane_point (Normale plane_n) gekreuzt ist.
## Gibt {"point", "time", "vel"} (linear im Tick interpoliert) oder {} nach max_time zurück.
static func cross_plane(pos: Vector3, vel: Vector3, k: float, dt: float,
		plane_point: Vector3, plane_n: Vector3, max_time := 5.0) -> Dictionary:
	var t := 0.0
	var d0 := (pos - plane_point).dot(plane_n)
	while t < max_time:
		var r := advance(pos, vel, k, dt, 1)
		var d1: float = (r[0] - plane_point).dot(plane_n)
		if (d0 < 0.0 and d1 >= 0.0) or (d0 > 0.0 and d1 <= 0.0):
			var f := d0 / (d0 - d1)
			return {"point": pos.lerp(r[0], f), "time": t + f * dt, "vel": vel.lerp(r[1], f)}
		pos = r[0]
		vel = r[1]
		d0 = d1
		t += dt
	return {}


## Abschussrichtung (Einheitsvektor), mit der ein Geschoss von `from` mit Mündungsgeschwindigkeit
## v0 (plus Schützengeschwindigkeit) durch `to` fliegt – Fallkorrektur iterativ.
static func solve_direction(from: Vector3, to: Vector3, v0: float, k: float,
		shooter_vel := Vector3.ZERO, dt := 1.0 / 60.0, iterations := 6) -> Vector3:
	var los := (to - from).normalized()
	var dist := from.distance_to(to)
	var dir := los
	for i in iterations:
		var c := cross_plane(from, shooter_vel + dir * v0, k, dt, to, los)
		if c.is_empty():
			break
		var miss: Vector3 = to - c.point
		if miss.length() < 1e-4:
			break
		dir = (dir * dist + miss).normalized()
	return dir


## Flugzeit (s) bis zur Entfernung d bei waagerechtem Schuss (Tabelle, 60 Hz).
static func time_of_flight(d: float, v0 := 800.0, k := 7.0e-4) -> float:
	return _lookup(_table(v0, k)[0], d)


## Absinken (m, positiv) unter der Seelenachse in Entfernung d (Tabelle, 60 Hz).
static func drop(d: float, v0 := 800.0, k := 7.0e-4) -> float:
	return _lookup(_table(v0, k)[1], d)


## Restgeschwindigkeit (m/s) in Entfernung d.
static func speed_at(d: float, v0 := 800.0, k := 7.0e-4) -> float:
	return _lookup(_table(v0, k)[2], d)


static func _lookup(arr: PackedFloat32Array, d: float) -> float:
	var x := clampf(d / TABLE_STEP, 0.0, arr.size() - 1.001)
	var i := int(x)
	return lerpf(arr[i], arr[i + 1], x - i)


## [tof, drop, speed] je TABLE_STEP; Bahn mit dem Spiel-Integrator (60 Hz) gerechnet.
static func _table(v0: float, k: float) -> Array:
	var key := Vector2(v0, k)
	if _tables.has(key):
		return _tables[key]
	var n := int(TABLE_RANGE / TABLE_STEP) + 1
	var tof := PackedFloat32Array()
	var drp := PackedFloat32Array()
	var spd := PackedFloat32Array()
	tof.resize(n)
	drp.resize(n)
	spd.resize(n)
	spd[0] = v0
	var dt := 1.0 / 60.0
	var pos := Vector3.ZERO
	var vel := Vector3(0, 0, -v0)
	var t := 0.0
	var i := 1
	while i < n and t < 30.0:
		var r := advance(pos, vel, k, dt, 1)
		var p1: Vector3 = r[0]
		while i < n and -p1.z >= i * TABLE_STEP:
			var f := (i * TABLE_STEP + pos.z) / (pos.z - p1.z)
			tof[i] = t + f * dt
			drp[i] = -lerpf(pos.y, p1.y, f)
			spd[i] = vel.lerp(r[1], f).length()
			i += 1
		pos = p1
		vel = r[1]
		t += dt
	for j in range(i, n):
		tof[j] = tof[i - 1]
		drp[j] = drp[i - 1]
		spd[j] = spd[i - 1]
	var res := [tof, drp, spd]
	_tables[key] = res
	return res


## Deterministische Streuung: Richtung um gaußverteilte Winkel (sigma in rad) drehen.
## Seed = hash(shooter_id, gun_index, shot_index) – Server und Client rechnen gleich.
static func disperse(dir: Vector3, sigma: float, shooter_id: int, gun_index: int,
		shot_index: int) -> Vector3:
	if sigma <= 0.0:
		return dir
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([shooter_id, gun_index, shot_index])
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var right := dir.cross(up).normalized()
	up = right.cross(dir)
	return (dir + right * rng.randfn(0.0, sigma) + up * rng.randfn(0.0, sigma)).normalized()
