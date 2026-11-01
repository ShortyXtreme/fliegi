extends TestSuite
## M3 Paket 2 (Strang G): JobBoard, RefuelJob, RearmJob, Regeln je Stufe.

const U := preload("res://tests/suites/ground_ops/job_util.gd")


## Zeiten je Stufe ±10 % gegen Plan §2 (Tanken 22 % -> voll, ein MG 0 -> voll), Spieler und KI.
func test_times_per_stage() -> Array:
	var lines := []
	var ok := true
	for r in 3:
		var a := _spawn(true)
		a.damage.fuel.set_fraction(0.22)
		a.weapons.set_ammo_fraction(0.0)
		var board := U.make_board(world, r)
		var depot := FuelDepot.new()
		var bunker := AmmoBunker.new()
		var l := a.damage.fuel.space()
		var exp_fuel: float = [1.0 + l / 30.0, 2.0 + l / 6.0 + 2.0, 3.0 + 2.0 + l / 4.0 + 2.0][r]
		var exp_mg: float = [3.0, 1.5 + 5.0 + 1.5, 1.5 + 5.0 + 1.5 + 2.0][r]
		var ids := board.plan_service(a, depot, bunker, {"repair": false})
		var tf := U.run_job(board, board.get_job(ids[0]))
		var tm := U.run_job(board, board.get_job(ids[1]))
		var ai := GroundCrewBrain.new()
		world.add_child(ai)
		var tm_ai := U.run_job(board, board.get_job(ids[2]), ai, 0)
		var ok_r := absf(tf / exp_fuel - 1.0) <= 0.1 and absf(tm / exp_mg - 1.0) <= 0.1 \
			and absf(tm_ai / (exp_mg / 0.8) - 1.0) <= 0.1 and board.is_serviced(a) \
			and is_equal_approx(a.damage.fuel.fraction(), 1.0) and a.weapons.ammo() == a.weapons.ammo_max()
		ok = ok and ok_r
		lines.append("%s: Tanken %.1f/%.1f s, MG %.1f/%.1f s, KI %.1f s" % [
			MatchRules.ground_realism_name(r), tf, exp_fuel, tm, exp_mg, tm_ai])
		a.queue_free()
		board.queue_free()
	return [ok, "; ".join(lines)]


## Simulierter Client und fremder Peer werden abgelehnt.
func test_client_rejected() -> Array:
	var a := _spawn(true)
	a.damage.fuel.set_fraction(0.5)
	var board := U.make_board(world, MatchRules.GroundRealism.STANDARD)
	var ids := board.plan_service(a, FuelDepot.new(), AmmoBunker.new(), {"ammo": false, "repair": false})
	var fuel0 := a.damage.fuel.total()
	var crew := GroundCrewBrain.new()
	crew.peer_id = 2                                   # fremder Mensch
	world.add_child(crew)
	board.claim(2, ids[0], crew)
	var wrong := board.request_step(1, ids[0], &"bring", 0.1)
	var right := board.request_step(2, ids[0], &"bring", 0.1)
	Authority.simulate_client = true
	var c1 := board.add_job(RefuelJob.new())
	var c2 := board.claim(2, ids[0], crew)
	var c3 := board.request_step(2, ids[0], &"attach", 0.1)
	board.tick(5.0)
	var c4 := board.plan_service(a, FuelDepot.new(), AmmoBunker.new())
	Authority.simulate_client = false
	var ok: bool = not wrong and right and c1 == 0 and not c2 and not c3 and c4.is_empty() \
		and is_equal_approx(a.damage.fuel.total(), fuel0) and board.get_job(ids[0]).current_step() == &"attach"
	return [ok, "fremder Peer %s, eigener %s, Client add/claim/step %d/%s/%s" % [wrong, right, c1, c2, c3]]


## Mengen-Erhalt über den Job; leeres Lager blockiert mit Hinweis, Nachfüllen hebt auf.
func test_conservation_and_blocking() -> Array:
	var a := _spawn(true)
	a.damage.fuel.set_fraction(0.1)
	a.weapons.set_ammo_fraction(0.0)
	var board := U.make_board(world, MatchRules.GroundRealism.STANDARD)
	var depot := FuelDepot.new({FuelSystem.GRADE_AVIATION: 100.0, FuelSystem.GRADE_ERSATZ: 0.0},
		{FuelSystem.GRADE_AVIATION: 8000.0, FuelSystem.GRADE_ERSATZ: 3000.0})
	var bunker := AmmoBunker.new({AmmoBunker.AMMO_792: 300})
	var reasons := []
	GroundEvents.bus().job_blocked.connect(func(_id, r): reasons.append(r))
	var sum0 := depot.total() + a.damage.fuel.total()
	var ids := board.plan_service(a, depot, bunker, {"repair": false})
	U.run_job(board, board.get_job(ids[0]))
	var sum1 := depot.total() + a.damage.fuel.total()
	var j2 := board.get_job(board.plan_service(a, depot, null, {"repair": false})[0])
	U.run_job(board, j2, null, 1, 1.0 / 60.0, 2.0)
	var blocked2 := j2.blocked_reason
	depot.deposit(FuelSystem.GRADE_ERSATZ, 50.0)
	board.tick(1.0)
	var unblocked := j2.blocked_reason == &""
	var ammo0 := bunker.available(AmmoBunker.AMMO_792)
	for k in range(1, ids.size()):
		U.run_job(board, board.get_job(ids[k]))
	var ammo_sum := bunker.available(AmmoBunker.AMMO_792) + a.weapons.ammo()
	var last: GroundJob = board.get_job(ids[ids.size() - 1])
	var ok: bool = absf(sum1 - sum0) <= sum0 * 0.001 and reasons.has(&"depot_empty") \
		and blocked2 == &"depot_empty" and unblocked and ammo_sum == ammo0 and reasons.has(&"store_empty") \
		and last.blocked_reason == &"store_empty" and GroundJob.block_text(&"depot_empty") == "Lager leer"
	return [ok, "Summe %.1f -> %.1f l, blockiert %s, aufgehoben %s, Munition %d -> %d, Gründe %s" % [
		sum0, sum1, blocked2, unblocked, ammo0, ammo_sum, reasons]]


## Authentisch: wer nicht abkoppelt, lässt überlaufen. Verlust gezählt, Summe stimmt.
func test_overflow_authentisch() -> Array:
	var a := _spawn(true)
	a.damage.fuel.set_fraction(0.9)
	var board := U.make_board(world, MatchRules.GroundRealism.AUTHENTISCH)
	var depot := FuelDepot.new()
	var sum0 := depot.total() + a.damage.fuel.total()
	var j: RefuelJob = board.get_job(board.plan_service(a, depot, null, {"repair": false})[0])
	for s in [&"bring", &"ground", &"attach"]:
		for k in 600:
			if j.current_step() != s:
				break
			board.request_step(1, j.id, s, 0.1)
	for k in 300:                                       # 30 s pumpen ohne Aufsicht
		board.tick(0.1)
	var sum1 := depot.total() + a.damage.fuel.total() + j.spilled
	var ok: bool = j.current_step() == &"pump" and j.spilled > 50.0 and absf(sum1 - sum0) <= sum0 * 0.001 \
		and is_equal_approx(a.damage.fuel.fraction(), 1.0) and j.grounded
	board.request_step(1, j.id, &"detach", 0.1)
	return [ok and j.current_step() == &"detach", "übergelaufen %.1f l, Summe %.1f -> %.1f" % [j.spilled, sum0, sum1]]


## Arbeitsschritte nur am Servicepunkt (Figur ≤ work_range).
func test_work_at_point() -> Array:
	var a := _spawn(true)
	a.weapons.set_ammo_fraction(0.0)
	var board := U.make_board(world, MatchRules.GroundRealism.STANDARD)
	var ids := board.plan_service(a, null, AmmoBunker.new(), {"repair": false})
	var j := board.get_job(ids[0])
	var body := Node3D.new()
	world.add_child(body)
	body.global_position = a.global_position + Vector3(40, 0, 0)
	board.claim(1, j.id, body)
	for k in 60:
		board.request_step(1, j.id, &"crate", 1.0 / 60.0)
	var far := board.request_step(1, j.id, &"hatch_open", 0.1)
	body.global_position = a.service_point(ServiceMarkers.SVC_GUN_HATCH_L)
	var near := board.request_step(1, j.id, &"hatch_open", 0.1)
	var ok: bool = j.current_step() == &"hatch_open" and not far and near and j.progress > 0.0
	return [ok, "fern %s, nah %s, Schritt %s %.2f" % [far, near, j.current_step(), j.progress]]
