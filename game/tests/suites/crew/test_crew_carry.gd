extends TestSuite
## Strang H, Paket 5: Tragen (Gehtempo je Last), Ein-/Aussteigen über SeatService
## (Aussteigen nur im Stand), Schlauch 12 m.

const SUITE := "fast"


func _svc() -> SeatService:
	var svc := SeatService.new()
	world.add_child(svc)
	return svc


func test_carry_speed_and_drop() -> Array:
	var ch := CrewTestUtil.make_crew(world, Vector3(0, 0, 100))
	var c := CrewTestUtil.ctl(ch)
	var crate := CarryItem.make(CarryItem.CRATE)
	world.add_child(crate)
	crate.global_position = Vector3(0, 0, 99)
	await _step(2)
	var hint := ch.current_action()
	c.ci.interact = true                       # E: aufheben
	await _step(2)
	c.ci.interact = false
	var got: bool = ch.carried == crate and crate.holder == ch and not crate.pickup.enabled
	c.ci.move = Vector2(0, 1)
	c.ci.sprint = true                         # mit Kiste kein Sprint
	var p0 := ch.global_position
	await _step(180)
	var d := ch.global_position.distance_to(p0)
	var state := ch.anim_state
	c.ci.move = Vector2.ZERO
	c.ci.drop = true                           # G: ablegen
	await _step(2)
	var dropped: bool = ch.carried == null and crate.holder == null and crate.pickup.enabled \
		and absf(crate.global_position.y) < 0.01 and crate.global_position.distance_to(ch.global_position) < 1.0
	# Authentisch: 25-kg-Kiste, -35 %
	crate.apply_realism(MatchRules.GroundRealism.AUTHENTISCH)
	var want := 1.6 * 0.8 * 3.0
	var ok: bool = hint.get("id") == &"pick_up" and got and absf(d - want) < 0.2 \
		and state == CrewCharacter.AnimState.CARRY and dropped \
		and is_equal_approx(ch.current_max_speed(false), 1.6) \
		and is_equal_approx(crate.speed_mul, 0.65)
	return [ok, "aufgehoben %s, 3 s mit Kiste %.2f m (soll %.2f), abgelegt %s, Authentisch ×%.2f" % [
		got, d, want, dropped, crate.speed_mul]]


func test_enter_and_exit_only_when_stopped() -> Array:
	var svc := _svc()
	var v := GroundVehicle.new()
	world.add_child(v)
	v.global_position = Vector3(20, 0, 50)
	var ch := CrewTestUtil.make_crew(world, v.driver_seat.entry_position() + Vector3(-1.0, 0, 0.5))
	var c := CrewTestUtil.ctl(ch)
	ch.pick_up(CarryItem.make(CarryItem.TOOL))
	await _step(2)
	c.ci.enter = true                                   # F
	await _step(2)
	var inside: bool = ch.in_seat == v.driver_seat and v.driver_seat.controller == c \
		and not ch.visible and ch.collision_layer == 0 and ch.carried == null
	var R := SeatService.Result
	var res := []
	v.speed = 3.0                                       # fährt noch
	res.append(svc.request_exit(1, v.driver_seat))
	v.speed = 0.0
	res.append(svc.request_exit(2, v.driver_seat))      # fremder Peer
	res.append(svc.request_exit(1, v.driver_seat))
	var out: bool = ch.in_seat == null and ch.visible and ch.crew_seat.controller == c \
		and ch.global_position.distance_to(v.driver_seat.entry_position()) < 0.05 \
		and ch.collision_layer == Layers.CHARACTER
	await _step(2)
	var walks: bool = ch.process_mode == Node.PROCESS_MODE_INHERIT and ch.anim_state == CrewCharacter.AnimState.ENTER
	var ok: bool = inside and res == [R.MOVING, R.BAD_PEER, R.OK] and out and walks
	return [ok, "eingestiegen %s, Aussteigen %s, draußen %s" % [
		inside, res.map(SeatService.result_text), out]]


func test_hose_length() -> Array:
	var reel := Node3D.new()
	world.add_child(reel)
	reel.global_position = Vector3(0, 1.2, 0)
	var hose := FuelHose.new()
	reel.add_child(hose)
	var ch := CrewTestUtil.make_crew(world, Vector3(0, 0, 1.2))
	var c := CrewTestUtil.ctl(ch)
	await _step(2)
	var hint := ch.current_action()
	c.ci.interact = true
	await _step(2)
	c.ci.interact = false
	var got: bool = ch.carried == hose.end_item and not hose.stowed
	c.ci.look_yaw = PI                                  # nach +Z weglaufen
	c.ci.move = Vector2(0, 1)
	await _step(60 * 14)                                # 14 s × 1,36 m/s ≈ 19 m Wunsch
	var reach := Vector2(ch.global_position.x, ch.global_position.z).length()
	var pl := hose.polyline_length()
	var pts := hose.points()
	var ends_ok: bool = pts[0].distance_to(hose.reel_position()) < 1e-3 \
		and pts[pts.size() - 1].distance_to(hose.end_position()) < 1e-3
	# Ankoppeln an einen Anker, Anker 16 m wegziehen -> reißt ab
	var anchor := Node3D.new()
	world.add_child(anchor)
	anchor.global_position = Vector3(5, 1.5, 0)
	var cpl := hose.couple(anchor)
	var freed: bool = ch.carried == null and hose.is_coupled()
	var torn := [false]
	hose.overstretched.connect(func(): torn[0] = true)
	anchor.global_position = Vector3(16, 1.5, 0)
	await _step(2)
	hose.stow()
	var ok: bool = hint.get("label") == "Schlauch nehmen" and got and reach <= FuelHose.HOSE_LENGTH \
		and reach > 10.5 and pl <= FuelHose.HOSE_LENGTH + 1e-3 and ends_ok and cpl and freed \
		and torn[0] and not hose.is_coupled() and hose.stowed
	return [ok, "Reichweite %.2f m, Kurve %.2f m (%d Segmente), angekoppelt %s, abgerissen %s, eingerollt %s" % [
		reach, pl, pts.size() - 1, cpl, torn[0], hose.stowed]]
