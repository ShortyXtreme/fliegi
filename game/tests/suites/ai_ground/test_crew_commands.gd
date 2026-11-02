extends TestSuite
## M3 Paket 7b (Strang G): Befehlsrad-API, je Befehl ein Test, KI fährt Tankwagen/Munitionswagen.

const StubCrew := preload("res://tests/suites/ai_ground/stub_crew.gd")
const C := GroundCrewBrain.Command


func _setup(realism := MatchRules.GroundRealism.STANDARD, auto := false) -> Dictionary:
	var a := _spawn(true)
	a.damage.fuel.set_fraction(0.2)
	a.weapons.set_ammo_fraction(0.0)
	var tz := DamageModel.Zone.TAIL
	a.damage.hp[tz] = a.damage.hp_max[tz] * 0.7
	var board := JobBoard.new()
	board.rules = GroundRules.for_realism(realism)
	world.add_child(board)
	var disp := GroundCrewDispatch.new()
	disp.board = board
	disp.depot = FuelDepot.new()
	disp.store = AmmoBunker.new()
	disp.aircraft = [a] if auto else []
	disp.nation_id = a.nation_id
	var side := Vector3(a.global_transform.basis.x.x, 0.0, a.global_transform.basis.x.z).normalized()
	disp.depot_pos = a.global_position + side * -60.0
	disp.depot.position = disp.depot_pos
	disp.truck_pos = disp.depot_pos + Vector3(0, 0, 8)
	disp.crew_spawn = a.global_position + side * -20.0
	world.add_child(disp)
	var svc := SeatService.new()
	world.add_child(svc)
	return {a = a, board = board, disp = disp, side = side}


func _crew(s: Dictionary, mode: int, start: Vector3) -> GroundCrewBrain:
	var br := GroundCrewBrain.new()
	br.dispatch = s.disp
	br.board = s.board
	br.force_mode = mode
	br.sim_pos = start
	var c := StubCrew.new()
	world.add_child(c)
	c.global_position = start
	c.add_child(br)
	c.crew_seat.possess(br)
	return br


func _truck(s: Dictionary, liters := 2000.0) -> FuelTruck:
	var t := FuelTruck.create(liters)
	world.add_child(t)
	t.place(s.disp.truck_pos, 0.0)
	t.depot = s.disp.depot
	s.disp.fuel_truck = t
	return t


func _run(s: Dictionary, max_t: float, until: Callable = Callable()) -> float:
	var t := 0.0
	while t < max_t:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if until.is_valid():
			if until.call():
				break
		elif not s.board.jobs_for(s.a).is_empty() and s.board.is_serviced(s.a):
			break
	return t


func _state(a: Aircraft) -> Array:
	return [a.damage.fuel.fraction(), a.weapons.ammo(), a.damage.hp[DamageModel.Zone.TAIL]]


func _job_cmd(cmd: int) -> Array:
	var s := _setup()
	var br := _crew(s, 1, s.disp.crew_spawn)
	var before := _state(s.a)
	var ok_cmd := br.command(cmd, s.a)
	var t := await _run(s, 400.0)
	return [ok_cmd and t < 400.0, before, _state(s.a), t, s]


func test_wheel_api_and_client() -> Array:
	var e := GroundCrewBrain.wheel_entries()
	var s := _setup()
	var br := _crew(s, 1, s.disp.crew_spawn)
	Authority.simulate_client = true
	var c1 := br.command(C.FULL_SERVICE, s.a)
	var c2 := GroundCrewBrain.issue(C.FUEL_ONLY, s.a)
	Authority.simulate_client = false
	var bad := br.command(C.TRUCK_TO_ME, s.a)          # kein Tankwagen am Platz
	var ok: bool = e.size() == 8 and e[0].label == "Voll abfertigen" and e[7].label == "Zurück/Pause" \
		and not c1 and c2 == 0 and not bad and s.board.jobs.is_empty()
	return [ok, "%d Einträge, Client %s/%d, ohne Wagen %s" % [e.size(), c1, c2, bad]]


func test_cmd_full_service() -> Array:
	var r := await _job_cmd(C.FULL_SERVICE)
	var a: Aircraft = r[4].a
	var ok: bool = r[0] and r[2][0] > 0.99 and r[2][1] == a.weapons.ammo_max() \
		and is_equal_approx(r[2][2], a.damage.hp_max[DamageModel.Zone.TAIL])
	return [ok, "%.0f s: %s -> %s" % [r[3], r[1], r[2]]]


func test_cmd_fuel_only() -> Array:
	var r := await _job_cmd(C.FUEL_ONLY)
	var ok: bool = r[0] and r[2][0] > 0.99 and r[2][1] == 0 and r[2][2] == r[1][2]
	return [ok, "%.0f s: %s -> %s" % [r[3], r[1], r[2]]]


func test_cmd_ammo_only() -> Array:
	var r := await _job_cmd(C.AMMO_ONLY)
	var a: Aircraft = r[4].a
	var ok: bool = r[0] and r[2][0] < 0.21 and r[2][1] == a.weapons.ammo_max() and r[2][2] == r[1][2]
	return [ok, "%.0f s: %s -> %s" % [r[3], r[1], r[2]]]


func test_cmd_repair() -> Array:
	var r := await _job_cmd(C.REPAIR)
	var a: Aircraft = r[4].a
	var ok: bool = r[0] and r[2][0] < 0.21 and r[2][1] == 0 \
		and is_equal_approx(r[2][2], a.damage.hp_max[DamageModel.Zone.TAIL])
	return [ok, "%.0f s: %s -> %s" % [r[3], r[1], r[2]]]


func test_cmd_quick_service() -> Array:
	var r := await _job_cmd(C.QUICK_SERVICE)
	var a: Aircraft = r[4].a
	var ok: bool = r[0] and r[2][0] > 0.48 and r[2][0] < 0.52 and r[2][1] == a.weapons.ammo_max() \
		and r[2][2] == r[1][2]
	return [ok, "%.0f s: %s -> %s" % [r[3], r[1], r[2]]]


## „Tankwagen zu mir“: die nächste Figur geht zum Wagen, steigt ein, fährt ihn her, steigt aus.
func test_cmd_truck_to_me() -> Array:
	var s := _setup()
	var t := _truck(s)
	var me := Node3D.new()
	world.add_child(me)
	me.global_position = s.a.global_position + s.side * -15.0 + Vector3(0, 0, 25)
	var br := _crew(s, 0, s.disp.truck_pos + Vector3(4, 0, 0))
	var far := _crew(s, 0, s.a.global_position + s.side * 30.0)
	var n := GroundCrewBrain.issue(C.TRUCK_TO_ME, me, [far, br])
	var drove := [false]
	var tt := await _run(s, 60.0, func():
		drove[0] = drove[0] or br.in_vehicle() == t
		return drove[0] and br.in_vehicle() == null and br.command_kind == C.FULL_SERVICE)
	var d: float = Vector2(t.global_position.x - me.global_position.x, t.global_position.z - me.global_position.z).length()
	var ok: bool = n == 1 and drove[0] and d < GroundCrewBrain.TRUCK_STOP + 3.0 and t.seat_speed() < 0.5 \
		and br.in_vehicle() == null and far.in_vehicle() == null and t.driver_seat.controller == null
	return [ok, "angenommen %d, gefahren %s, %.1f s, Abstand %.1f m" % [n, drove[0], tt, d]]


func test_cmd_follow() -> Array:
	var s := _setup()
	var me := Node3D.new()
	world.add_child(me)
	me.global_position = s.disp.crew_spawn + Vector3(15, 0, 0)
	var br := _crew(s, 0, s.disp.crew_spawn)
	var ok_cmd := GroundCrewBrain.issue(C.FOLLOW, me, [br]) == 1
	await _step(60 * 8)
	me.global_position += Vector3(0, 0, 12)
	await _step(60 * 8)
	var d: float = br.position_now().distance_to(me.global_position)
	var ok: bool = ok_cmd and d < GroundCrewBrain.FOLLOW_DIST + 1.0 and br.job_id == 0
	return [ok, "Abstand %.1f m" % d]


## „Zurück/Pause“: Arbeit ruht, Figur geht zum Crew-Spawn; danach weiter mit Automatik.
func test_cmd_pause() -> Array:
	var s := _setup(MatchRules.GroundRealism.STANDARD, true)
	var br := _crew(s, 0, s.a.global_position + s.side * -6.0)
	await _step(60 * 3)
	s.disp.tick(0.0)
	var jobs0: int = s.board.open_jobs(s.a).size()
	br.command(C.PAUSE, null)
	var st0: Array = _state(s.a)
	await _step(60 * 15)
	var st1: Array = _state(s.a)
	var home: float = br.position_now().distance_to(s.disp.crew_spawn)
	var mine: int = s.board.open_jobs(s.a).filter(func(j): return j.worker == br.body()).size()
	br.command(C.FULL_SERVICE, null)
	await _run(s, 300.0)
	var ok: bool = jobs0 > 0 and st1[1] == st0[1] and is_equal_approx(st1[2], st0[2]) and home < 2.0 \
		and mine == 0 and s.board.is_serviced(s.a) and br.command_kind == C.FULL_SERVICE
	return [ok, "Jobs %d, Pause %s -> %s, am Spawn %.1f m, danach versorgt %s" % [jobs0, st0, st1, home,
		s.board.is_serviced(s.a)]]


## Automatik mit echtem Tankwagen: KI fährt ihn heran, koppelt den Schlauch, tankt aus dem Wagen.
func test_ai_drives_truck_for_refuel() -> Array:
	var s := _setup(MatchRules.GroundRealism.STANDARD, true)
	s.a.weapons.set_ammo_fraction(1.0)
	s.a.damage.hp[DamageModel.Zone.TAIL] = s.a.damage.hp_max[DamageModel.Zone.TAIL]
	var t := _truck(s)
	var br := _crew(s, 0, s.disp.truck_pos + Vector3(4, 0, 0))
	var f0: float = s.a.damage.fuel.total()
	var tank0 := t.tank.total()
	var coupled := [false]
	t.hose.coupled.connect(func(_x): coupled[0] = true)
	var tt := await _run(s, 240.0)
	var moved := tank0 - t.tank.total()
	var got: float = s.a.damage.fuel.total() - f0
	var cap: Vector3 = s.a.service_point(ServiceMarkers.SVC_FUEL_CAP)
	var ok: bool = s.board.is_serviced(s.a) and s.a.damage.fuel.fraction() > 0.99 and coupled[0] \
		and not t.hose.is_coupled() and absf(moved - got) <= tank0 * 0.001 + 1.0 \
		and t.global_position.distance_to(cap) < FuelTruck.HOSE_LENGTH and br.in_vehicle() == null
	return [ok, "%.0f s, aus Wagen %.1f l, im Tank +%.1f l, Schlauch gekoppelt %s, Wagen %.1f m vom Deckel" % [
		tt, moved, got, coupled[0], t.global_position.distance_to(cap)]]


## Authentisch, Sim-LOD: leerer Tankwagen wird erst am Lager befüllt, dann gefahren (Mengen-Erhalt).
func test_ai_fills_truck_authentisch() -> Array:
	var s := _setup(MatchRules.GroundRealism.AUTHENTISCH, true)
	s.a.weapons.set_ammo_fraction(1.0)
	s.a.damage.hp[DamageModel.Zone.TAIL] = s.a.damage.hp_max[DamageModel.Zone.TAIL]
	var t := _truck(s, 0.0)
	t.place(s.a.global_position + s.side * -30.0, 0.0)
	var br := _crew(s, 1, s.disp.crew_spawn)
	var sum0: float = s.disp.depot.total() + t.tank.total() + s.a.damage.fuel.total()
	var tt := await _run(s, 400.0)
	var spilled := 0.0
	for j in s.board.jobs_for(s.a):
		if j is RefuelJob:
			spilled += j.spilled
	var sum1: float = s.disp.depot.total() + t.tank.total() + s.a.damage.fuel.total() + spilled
	var ok: bool = s.board.is_serviced(s.a) and s.a.damage.fuel.fraction() > 0.99 and absf(sum1 - sum0) <= sum0 * 0.001 \
		and s.disp.depot.total() < FuelDepot.START_AVIATION + FuelDepot.START_ERSATZ - 200.0 and br.in_vehicle() == null
	return [ok, "%.0f s, Summe %.1f -> %.1f l, Wagen %.0f l" % [tt, sum0, sum1, t.tank.total()]]
