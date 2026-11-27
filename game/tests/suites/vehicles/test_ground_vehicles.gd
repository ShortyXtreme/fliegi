extends TestSuite
## Strang H, Paket 6: Fahrmodell (Höchstfahrt, Bremsen, Rückwärts, Lenken, Hang,
## Determinismus), Tankwagen befüllen am Lager (FuelDepot-Stub), Munitionswagen-Kisten.

const SUITE := "fast"


class Slope extends RefCounted:
	var grade := 0.1
	func height_at(x: float, _z: float) -> float:
		return grade * x


func _vehicle(v: GroundVehicle, pos: Vector3, yaw := 0.0) -> CrewTestUtil.FixedCrewController:
	world.add_child(v)
	v.place(pos, yaw)
	var c := CrewTestUtil.FixedCrewController.new()
	c.peer_id = 1
	v.add_child(c)
	v.driver_seat.possess(c)
	return c


func test_speed_brake_reverse() -> Array:
	var v := FuelTruck.new()
	var c := _vehicle(v, Vector3(0, 0, 300))
	c.pi.throttle = 1.0
	await _step(60 * 30)
	var vmax := v.speed
	var p0 := v.global_position
	c.pi.throttle = 0.0
	c.pi.brakes = 1.0
	var stop_t := 0
	while v.speed > 0.0 and stop_t < 600:
		await get_tree().physics_frame
		stop_t += 1
	var stop_d := v.global_position.distance_to(p0)
	await _step(15)                                # < REVERSE_DELAY: bleibt stehen
	var still := v.speed
	await _step(60 * 6)
	var rev := v.speed
	var ok: bool = vmax <= GroundVehicle.MAX_SPEED + 1e-4 and vmax > 9.0 and stop_d < 12.0 \
		and still == 0.0 and rev < -2.0 and rev >= -GroundVehicle.REVERSE_SPEED - 1e-4
	return [ok, "Höchstfahrt %.1f km/h, Bremsweg %.1f m in %.1f s, Stand %.2f, rückwärts %.1f km/h" % [
		vmax * 3.6, stop_d, stop_t / 60.0, still, rev * 3.6]]


func test_steering_circle() -> Array:
	var v := AmmoCart.new()
	var c := _vehicle(v, Vector3(100, 0, 100))
	c.pi.throttle = 0.4
	c.pi.yaw = 1.0                                  # rechts
	await _step(60 * 20)
	var s := v.speed
	var h0 := v.heading
	await get_tree().physics_frame
	var rate := wrapf(v.heading - h0, -PI, PI) * 60.0
	var r := absf(s / rate)
	var steer := v.steer
	var r_want := v.wheelbase / tan(absf(steer))
	var ok: bool = rate < 0.0 and absf(r - r_want) < 0.2 and r > 5.0 and r < 20.0
	return [ok, "Fahrt %.1f km/h, Gierrate %.3f rad/s (rechts), Wendekreis-Radius %.1f m (soll %.1f)" % [
		s * 3.6, rate, r, r_want]]


func _run_sequence() -> PackedFloat32Array:
	var v := FuelTruck.new()
	var c := _vehicle(v, Vector3(-200, 0, 0), 0.3)
	for k in 300:
		c.pi.throttle = 1.0 if k < 200 else 0.0
		c.pi.brakes = 1.0 if k >= 240 else 0.0
		c.pi.yaw = sin(k * 0.05)
		await get_tree().physics_frame
	var a := v.to_array()
	v.queue_free()
	await get_tree().physics_frame
	return a


func test_deterministic() -> Array:
	var a = await _run_sequence()
	var b = await _run_sequence()
	return [a == b and a[4] >= 0.0, "Lauf 1 %s, Lauf 2 %s" % [a, b]]


## Prüfung Boden: mit Hangabtrieb. 10 % mit Vollgas (vorher 60 % Gas, ohne Hangabtrieb), 30 % schafft
## der beladene Wagen nicht (Haftung ≈ 2,5 m/s²), bergab ohne Gas rollt er schneller.
func test_follows_slope() -> Array:
	var slope := Slope.new()
	WorldGround.set_provider(slope)
	var v := FuelTruck.new()
	var c := _vehicle(v, Vector3(20, 0, -50), -PI / 2)   # Front nach +X, bergauf
	c.pi.throttle = 1.0
	await _step(60 * 10)
	var p := v.global_position
	var nose := -v.global_transform.basis.z
	var up_v := v.speed
	var ok: bool = absf(p.y - 0.1 * p.x) < 0.01 and absf(nose.y - sin(atan(0.1))) < 0.01 and p.x > 45.0
	v.queue_free()
	slope.grade = 0.3
	var v2 := FuelTruck.new()
	var c2 := _vehicle(v2, Vector3(20, 0, -80), -PI / 2)
	c2.pi.throttle = 1.0
	await _step(60 * 5)
	var steep := v2.global_position.x - 20.0
	v2.queue_free()
	slope.grade = -0.1
	var v3 := FuelTruck.new()
	var c3 := _vehicle(v3, Vector3(20, 0, -110), -PI / 2)   # bergab
	c3.pi.throttle = 0.1
	await _step(60 * 4)
	c3.pi.throttle = 0.0
	await _step(60 * 4)
	var down_v := v3.speed
	WorldGround.clear_provider(slope)
	ok = ok and steep < 1.0 and down_v > 2.0
	return [ok, "10 %%: x %.1f m, %.1f km/h, Höhe %.2f (Boden %.2f), Nase hoch %.3f (soll %.3f); 30 %%: %.1f m in 5 s; 10 %% bergab rollend %.1f km/h" % [
		p.x, up_v * 3.6, p.y, 0.1 * p.x, nose.y, sin(atan(0.1)), steep, down_v * 3.6]]


## Prüfung Boden: Kurvengrenze – bei Höchstfahrt und vollem Einschlag höchstens MAX_LAT_ACCEL.
func test_lateral_limit() -> Array:
	var v := FuelTruck.new()
	var c := _vehicle(v, Vector3(-300, 0, 300))
	c.pi.throttle = 1.0
	await _step(60 * 20)
	c.pi.yaw = 1.0
	await _step(60 * 3)
	var h0 := v.heading
	await get_tree().physics_frame
	var rate := absf(wrapf(v.heading - h0, -PI, PI)) * 60.0
	var lat := absf(v.speed) * rate
	var ok := lat <= GroundVehicle.MAX_LAT_ACCEL + 0.05 and lat > 2.5 and v.speed > 9.0
	return [ok, "%.1f km/h, Radius %.1f m, Querbeschleunigung %.2f m/s² (max. %.1f; vorher ≈ 7)" % [
		v.speed * 3.6, v.speed / maxf(rate, 1e-4), lat, GroundVehicle.MAX_LAT_ACCEL]]


func test_fill_truck_at_depot() -> Array:
	var depot := FuelDepot.new()
	depot.position = Vector3(30, 0, 0)
	var t := FuelTruck.create(0.0)
	_vehicle(t, Vector3(30, 0, -10))
	t.depot = depot
	var AV := FuelSystem.GRADE_AVIATION
	var ER := FuelSystem.GRADE_ERSATZ
	var sum0 := depot.total() + t.tank.total()
	var far := FuelTruck.create(0.0)
	_vehicle(far, Vector3(300, 0, 0))
	var far_got := far.fill_from(depot, AV, 1.0)
	# Figur hält E an der Trommel 10 s
	await _step(2)
	var ch := CrewTestUtil.make_crew(world, t.fill_point.global_position + t.forward() * 0.0 + Vector3(0, 0, 1.0))
	CrewTestUtil.ctl(ch).ci.look_yaw = 0.0
	CrewTestUtil.ctl(ch).ci.interact = true
	await _step(600)
	CrewTestUtil.ctl(ch).ci.interact = false
	var after_hold := t.tank.available(AV)
	# Rest direkt: bis voll, Überschuss bleibt im Lager
	for k in 200:
		t.fill_from(depot, AV, 1.0)
	var full := t.tank.available(AV)
	var wrong := t.fill_from(depot, ER, 1.0)
	Authority.simulate_client = true
	var client := t.fill_from(depot, AV, 1.0)
	Authority.simulate_client = false
	var sum1 := depot.total() + t.tank.total()
	var ok: bool = far_got == 0.0 and absf(after_hold - 200.0) < 1.0 and full == FuelTruck.TANK_CAPACITY \
		and wrong == 0.0 and client == 0.0 and absf(sum1 - sum0) < 0.01 \
		and absf(depot.available(AV) - (FuelDepot.START_AVIATION - 2000.0)) < 0.01
	return [ok, "zu weit %.0f l, 10 s gehalten %.1f l (20 l/s), voll %.0f l, Ersatz %.0f, Client %.0f, Summe %.1f -> %.1f" % [
		far_got, after_hold, full, wrong, client, sum0, sum1]]


func test_ammo_cart_crates() -> Array:
	var cart := AmmoCart.new()
	_vehicle(cart, Vector3(-30, 0, 30))
	await _step(2)
	var slot := cart.slot_points[0]
	var ch := CrewTestUtil.make_crew(world, slot.global_position + Vector3(0, 0, 1.2))
	var c := CrewTestUtil.ctl(ch)
	await _step(2)
	var focus_ok := ch.focus != null and ch.focus.target == cart
	c.ci.interact = true
	await _step(2)
	c.ci.interact = false
	var crate: CarryItem = ch.carried
	var took: bool = crate != null and crate.kind == CarryItem.CRATE and crate.store.available(AmmoCart.AMMO) == 500 \
		and cart.crates == 5 and cart.store.available(AmmoCart.AMMO) == 2500
	crate.store.request(AmmoCart.AMMO, 120)        # 120 Schuss „geladen“
	await _step(2)
	c.ci.interact = true                           # zurücklegen
	await _step(2)
	c.ci.interact = false
	var back: bool = ch.carried == null and cart.store.available(AmmoCart.AMMO) == 2880 and cart.crates == 6
	var bunker := AmmoBunker.new()
	bunker.position = cart.global_position + Vector3(8, 0, 0)
	var got := cart.fill_from(bunker)
	var ok: bool = focus_ok and took and back and got == 120 and bunker.available(AmmoCart.AMMO) == AmmoBunker.START_792 - 120
	return [ok, "Fokus %s, Kiste genommen %s (Wagen %d Kisten), zurück %s (%d Schuss), am Bunker +%d" % [
		focus_ok, took, cart.crates, back, cart.store.available(AmmoCart.AMMO), got]]
