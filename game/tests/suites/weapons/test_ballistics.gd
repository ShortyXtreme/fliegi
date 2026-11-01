extends TestSuite
## Paket 1: Ballistik, Konvergenz, Absinken, Vorhalt (reine Funktionen, ohne Flugzeug).

const MG := "res://weapons/data/mg_t1.tres"
const LOADOUT := "res://weapons/data/loadout_fighter_t1.tres"
const DT := 1.0 / 60.0


## Unabhängige Kontrolle: Bahn tickweise rechnen, Kreuzung der Ebene z = plane_z suchen.
func _cross_z(pos: Vector3, vel: Vector3, k: float, plane_z: float) -> Vector3:
	for i in 600:
		var r := Ballistics.advance(pos, vel, k, DT, 1)
		var p1: Vector3 = r[0]
		if p1.z <= plane_z:
			return pos.lerp(p1, (pos.z - plane_z) / (pos.z - p1.z))
		pos = p1
		vel = r[1]
	return Vector3.INF


func test_convergence_250m() -> Array:
	var lo: WeaponLoadout = load(LOADOUT)
	var c := lo.sight_position + Vector3(0, 0, -lo.convergence)
	var worst := 0.0
	var dirs := lo.aim_directions()
	for i in lo.mounts.size():
		var m := lo.mounts[i]
		var hit := _cross_z(m.position, dirs[i] * m.weapon.muzzle_velocity,
				m.weapon.ballistic_k, c.z)
		worst = maxf(worst, hit.distance_to(c))
	var ok := lo.mounts.size() == 2 and worst <= 0.5
	return [ok, "%d Waffen, größte Abweichung am Konvergenzpunkt %.0f m: %.3f m (≤ 0,5)" % [
			lo.mounts.size(), lo.convergence, worst]]


## Referenz: RK4 mit 0,1 ms Schrittweite.
func _reference_drop(d: float, v0: float, k: float) -> Vector2:
	var p := Vector3.ZERO
	var v := Vector3(0, 0, -v0)
	var h := 1e-4
	var t := 0.0
	var acc := func(vv: Vector3) -> Vector3: return Ballistics.GRAVITY - vv * (k * vv.length())
	while -p.z < d:
		var k1v: Vector3 = acc.call(v)
		var k2v: Vector3 = acc.call(v + k1v * (h * 0.5))
		var k3v: Vector3 = acc.call(v + k2v * (h * 0.5))
		var k4v: Vector3 = acc.call(v + k3v * h)
		var dp := (v + (v + k1v * (h * 0.5)) * 2.0 + (v + k2v * (h * 0.5)) * 2.0 + (v + k3v * h)) * (h / 6.0)
		v += (k1v + k2v * 2.0 + k3v * 2.0 + k4v) * (h / 6.0)
		p += dp
		t += h
	return Vector2(-p.y, t)


func test_drop_500m() -> Array:
	var w: WeaponDef = load(MG)
	var ref := _reference_drop(500.0, w.muzzle_velocity, w.ballistic_k)
	var drop := Ballistics.drop(500.0, w.muzzle_velocity, w.ballistic_k)
	var tof := Ballistics.time_of_flight(500.0, w.muzzle_velocity, w.ballistic_k)
	var err := absf(drop - ref.x) / ref.x
	var vac := 0.5 * 9.81 * pow(500.0 / w.muzzle_velocity, 2)
	var v500 := Ballistics.speed_at(500.0, w.muzzle_velocity, w.ballistic_k)
	var ok := err <= 0.05 and drop > vac and v500 > 450.0 and v500 < 650.0
	return [ok, "Absinken 500 m: %.2f m (Referenz %.2f m, Abw. %.1f %%), Flugzeit %.3f s (Ref. %.3f), v = %.0f m/s, Vakuum %.2f m" % [
			drop, ref.x, err * 100.0, tof, ref.y, v500, vac]]


func test_lead_crossing_target() -> Array:
	var w: WeaponDef = load(MG)
	var sp := Vector3(0, 1000, 0)
	var sv := Vector3(0, 0, -120)
	var tp := Vector3(150, 1010, -350)
	var tv := Vector3(-110, 5, -60)
	var r := LeadSolver.solve(sp, sv, tp, tv, w.muzzle_velocity, w.ballistic_k)
	# Geschoss und Ziel tickweise laufen lassen, kleinsten Abstand (Segment) messen.
	var p := sp
	var v: Vector3 = sv + r.dir * w.muzzle_velocity
	var best := INF
	for i in 120:
		var s := Ballistics.advance(p, v, w.ballistic_k, DT, 1)
		var t0 := tp + tv * (i * DT)
		var t1 := tp + tv * ((i + 1) * DT)
		# Relativbewegung im Tick: Abstand Segment (Geschoss − Ziel) zum Ursprung.
		var a := p - t0
		var b: Vector3 = s[0] - t1
		var ab := b - a
		var f := clampf(-a.dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		best = minf(best, (a + ab * f).length())
		p = s[0]
		v = s[1]
	var q := LeadSolver.quick(sp, sv, tp, tv, w.muzzle_velocity, w.ballistic_k)
	var ang := rad_to_deg(r.dir.angle_to(q.dir))
	var ok: bool = r.valid and best < 0.5 and ang < 1.0
	return [ok, "Vorhalt: Flugzeit %.3f s, Fehlabstand %.3f m (< 0,5), Näherung weicht %.2f° ab" % [
			r.time, best, ang]]


func test_dispersion_deterministic() -> Array:
	var d := Vector3(0, 0, -1)
	var sigma := 0.002
	var same := Ballistics.disperse(d, sigma, 7, 1, 42) == Ballistics.disperse(d, sigma, 7, 1, 42)
	var diff := Ballistics.disperse(d, sigma, 7, 1, 42) != Ballistics.disperse(d, sigma, 7, 1, 43)
	var sum := 0.0
	var n := 400
	for i in n:
		var e := Ballistics.disperse(d, sigma, 3, 0, i)
		sum += e.x * e.x
	var std := sqrt(sum / n)
	var ok := same and diff and absf(std - sigma) < sigma * 0.2
	return [ok, "Streuung deterministisch=%s, verschieden je Schuss=%s, Std. %.2f mrad (Soll %.2f)" % [
			same, diff, std * 1000.0, sigma * 1000.0]]
