extends TestSuite
## Prüfung Boden: Fallschirm-Physik – Sinkrate (Meereshöhe, 3000 m), Öffnungsstoß, Drift im Wind,
## tiefer Ausstieg, Landung im Wasser.

const SUITE := "fast"


class Ground extends RefCounted:
	var h := 0.0
	var water := NAN
	func height_at(_x: float, _z: float) -> float:
		return h
	func water_level_at(_x: float, _z: float) -> float:
		return water


func _chute(pos: Vector3, vel: Vector3) -> Parachute:
	var p := Parachute.new()
	world.add_child(p)
	p.set_physics_process(false)
	p.global_position = pos
	p.velocity = vel
	return p


## Schritte bis zur Landung oder max_s; Rückgabe Zeit.
func _run(p: Parachute, max_s: float) -> float:
	var t := 0.0
	while not p.on_ground and t < max_s:
		p.step(1.0 / 60.0)
		t += 1.0 / 60.0
	return t


func test_sink_rate_and_altitude() -> Array:
	var g := Ground.new()
	WorldGround.set_provider(g)
	var lo := _chute(Vector3(0, 400, 0), Vector3(60, 0, 0))
	_run(lo, 40.0)
	var v0 := -lo.velocity.y
	var hi := _chute(Vector3(0, 3200, 0), Vector3(60, 0, 0))
	_run(hi, 40.0)
	var v3 := -hi.velocity.y
	var want3 := Parachute.SINK_RATE * sqrt(FlightModel.air_density(0.0) / FlightModel.air_density(hi.global_position.y))
	var ff := _chute(Vector3(0, 3000, 0), Vector3.ZERO)
	ff.age = -30.0                                       # 30 s freier Fall (Reißleine noch nicht)
	for k in 60 * 25:
		ff.step(1.0 / 60.0)
	var term := -ff.velocity.y
	WorldGround.clear_provider(g)
	var ok := absf(v0 - 6.0) < 0.3 and absf(v3 - want3) < 0.3 and v3 > v0 + 0.5 and term > 45.0 and term < 65.0
	return [ok, "Sinken offen: Meereshöhe %.2f m/s (Soll 5,5–7,5), %.0f m %.2f m/s (Soll %.2f), freier Fall %.0f m/s" % [
		v0, hi.global_position.y, v3, want3, term]]


func test_opening_shock() -> Array:
	var g := Ground.new()
	WorldGround.set_provider(g)
	var res := []
	for v in [0.0, 60.0, 100.0, 140.0]:
		var p := _chute(Vector3(0, 2000, 0), Vector3(v, 0, 0))
		_run(p, 8.0)
		res.append(p.opening_g)
	WorldGround.clear_provider(g)
	var ok: bool = res[1] > 2.5 and res[2] > res[1] and res[3] > 6.0 and res[3] < 13.0 and res[0] < res[1]
	return [ok, "Öffnungsstoß bei 0/60/100/140 m/s Absprungfahrt: %s g (AP3456: bis ≈ 9 g)" % [
		res.map(func(x): return "%.1f" % x)]]


func test_drift_with_wind() -> Array:
	var g := Ground.new()
	WorldGround.set_provider(g)
	Weather.set_steady(270.0, 7.0)                  # aus West -> nach Ost (+X)
	var p := _chute(Vector3(0, 800, 0), Vector3(0, 0, -50))
	_run(p, 15.0)
	var w := Weather.wind_at(p.global_position)
	var dv := Vector2(p.velocity.x - w.x, p.velocity.z - w.z).length()
	Weather.reset()
	WorldGround.clear_provider(g)
	var ok := dv < 0.3 and p.is_open()
	return [ok, "nach 15 s: Fahrt waagerecht %s, Wind %s, Abweichung %.2f m/s" % [
		Vector2(p.velocity.x, p.velocity.z).snapped(Vector2.ONE * 0.01), Vector2(w.x, w.z).snapped(Vector2.ONE * 0.01), dv]]


func test_low_bailout_and_water() -> Array:
	var g := Ground.new()
	WorldGround.set_provider(g)
	var res := []
	for h in [8.0, 30.0]:
		var p := _chute(Vector3(0, h, 0), Vector3(60, 0, 0))
		_run(p, 30.0)
		res.append([p.survives, p.landing_speed])
	g.h = -2.0
	g.water = 0.0
	var wp := _chute(Vector3(0, 300, 0), Vector3(60, 0, 0))
	_run(wp, 120.0)
	WorldGround.clear_provider(g)
	var ok: bool = not res[0][0] and res[1][0] and res[1][1] < 8.0 and wp.in_water and absf(wp.global_position.y) < 0.01 and wp.survives
	return [ok, "Ausstieg 60 m/s waagerecht: 8 m %s (%.1f m/s), 30 m %s (%.1f m/s); Wasser: im Wasser %s auf y %.2f, lebt %s" % [
		"lebt" if res[0][0] else "tot", res[0][1], "lebt" if res[1][0] else "tot", res[1][1],
		wp.in_water, wp.global_position.y, wp.survives]]
