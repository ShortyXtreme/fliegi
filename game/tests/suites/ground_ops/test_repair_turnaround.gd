extends TestSuite
## M3 Paket 3 (Strang G): Reparatur light, Alarmstart, Abfertigungs-Wertung.

const U := preload("res://tests/suites/ground_ops/job_util.gd")
const TEST_BEST := "user://test_g_bestzeit.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TEST_BEST):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BEST))


## Reparaturrate je Stufe ±10 %, Grenzen: Flügelbruch, Abschuss, Werkzeugkiste (Authentisch).
func test_repair_limits() -> Array:
	var lines := []
	var ok := true
	for r in 3:
		var a := _spawn(true)
		var board := U.make_board(world, r)
		a.damage.apply_hit(DamageModel.Zone.TAIL, 60.0, null)
		var miss := a.damage.hp_max[DamageModel.Zone.TAIL] - a.damage.hp[DamageModel.Zone.TAIL]
		var ids := board.plan_service(a, null, null, {"fuel": false, "ammo": false})
		var j: RepairJob = board.get_job(ids[0])
		var t := U.run_job(board, j, null, 1, 1.0 / 60.0, 5.0 if r == 2 else 600.0)
		var blocked := j.blocked_reason
		if r == MatchRules.GroundRealism.AUTHENTISCH:
			j.toolbox = true
			t += U.run_job(board, j)
		var exp: float = miss / [25.0, 6.0, 3.0][r]
		var ok_r := ids.size() == 1 and absf(t / exp - 1.0) <= 0.1 and board.is_serviced(a) \
			and is_equal_approx(a.damage.hp[DamageModel.Zone.TAIL], a.damage.hp_max[DamageModel.Zone.TAIL]) \
			and (blocked == &"toolbox_missing") == (r == MatchRules.GroundRealism.AUTHENTISCH)
		ok = ok and ok_r
		lines.append("%s %.1f/%.1f s %s" % [MatchRules.ground_realism_name(r), t, exp, blocked])
		board.queue_free()
		a.queue_free()
	var b := _spawn(true)
	var board2 := U.make_board(world, MatchRules.GroundRealism.STANDARD)
	b.damage.apply_hit(DamageModel.Zone.WING_L, 10000.0, null)          # Flügelbruch
	var planned := board2.plan_service(b, null, null, {"fuel": false, "ammo": false})
	var wj := RepairJob.new()
	wj.target = b
	wj.zone = DamageModel.Zone.WING_L
	board2.add_job(wj)
	U.run_job(board2, wj, null, 1, 1.0 / 60.0, 1.0)
	var no_wing := planned.filter(func(id): return board2.get_job(id).zone == DamageModel.Zone.WING_L).is_empty()
	ok = ok and no_wing and wj.blocked_reason == &"not_repairable" and wj.repaired == 0.0
	return [ok, "; ".join(lines) + "; Flügelbruch %s" % wj.blocked_reason]


## Wertung nach Richtzeit, Bestzeit in user://, Ereignis, Helfer zählen, Ende bei fertig.
func test_turnaround_rating() -> Array:
	var a := _spawn(true)
	a.weapons.set_ammo_fraction(0.0)
	var board := U.make_board(world, MatchRules.GroundRealism.STANDARD)
	var ta := Turnaround.new()
	ta.best_path = TEST_BEST
	ta.board = board
	ta.realism = MatchRules.GroundRealism.STANDARD
	var got := []
	GroundEvents.bus().turnaround.connect(func(ac, s, h): got.append([ac, s, h]))
	var ids := board.plan_service(a, null, AmmoBunker.new(), {"repair": false})
	ta.start(a)
	var ai := GroundCrewBrain.new()
	world.add_child(ai)
	for id in ids:
		board.claim(0, id, ai)
	var t := 0.0
	while ta.running and t < 120.0:
		for j: GroundJob in board.open_jobs(a):
			board.request_step(0, j.id, j.current_step(), 0.1)
		ta.tick(0.1)
		t += 0.1
	var first_best := ta.last_best
	var ta2 := Turnaround.new()
	ta2.best_path = TEST_BEST
	ta2.realism = MatchRules.GroundRealism.STANDARD
	ta2.start(a)
	ta2.helpers = 1
	ta2.tick(500.0)
	ta2.finish()
	var s := [Turnaround.stars(80.0, 0, 1), Turnaround.stars(190.0, 0, 1), Turnaround.stars(240.0, 0, 1),
		Turnaround.stars(400.0, 0, 1), Turnaround.stars(95.0, 2, 1)]
	var ok: bool = not ta.running and got.size() == 2 and got[0][0] == a and got[0][2] == 1 \
		and absf(got[0][1] - ta.elapsed) < 0.01 and first_best and not ta2.last_best \
		and absf(ta.best_time(1, 1) - ta.elapsed) < 0.01 and s == [3, 2, 1, 0, 2] \
		and is_equal_approx(Turnaround.reference_time(2, 1), 100.0)
	return [ok, "Abfertigung %.1f s, Helfer %d, Sterne %d, Bestzeit %s/%s, Stufen %s" % [
		ta.elapsed, ta.helpers, ta.last_stars, first_best, ta2.last_best, s]]


## Alarmstart: Countdown, KI ×1,25, Schnellabfertigung (Munition zuerst, 50 % Tank), Ende.
func test_alarm_start() -> Array:
	var a := _spawn(true)
	a.damage.fuel.set_fraction(0.1)
	a.weapons.set_ammo_fraction(0.0)
	var board := U.make_board(world, MatchRules.GroundRealism.STANDARD)
	var ta := Turnaround.new()
	ta.best_path = TEST_BEST
	ta.board = board
	var ev := []
	GroundEvents.bus().alarm_started.connect(func(sec): ev.append(sec))
	GroundEvents.bus().alarm_ended.connect(func(okk): ev.append(okk))
	var ai := GroundCrewBrain.new()
	world.add_child(ai)
	var mul0 := board.work_mul_of(ai)
	var ids := ta.start_alarm(180.0, a, FuelDepot.new(), AmmoBunker.new())
	var mul1 := board.work_mul_of(ai)
	var fuel_j: RefuelJob = board.get_job(ids[0])
	var ammo_j: GroundJob = board.get_job(ids[1])
	ta.tick(100.0)
	var mid := ta.alarm_active() and is_equal_approx(ta.alarm_left, 80.0)
	ta.tick(100.0)
	var ok: bool = is_equal_approx(mul0, 0.8) and is_equal_approx(mul1, 1.0) and fuel_j.target_fraction == 0.5 \
		and ammo_j.priority > fuel_j.priority and fuel_j.priority >= GroundCrewBrain.Priority.ALARM \
		and mid and not ta.alarm_active() and ev == [180.0, false] and not board.alarm
	ta.start(a)
	ta.start_alarm(60.0)
	ta.finish()
	ok = ok and ev.size() == 4 and ev[3] == true
	return [ok, "KI %.2f -> %.2f, Ziel %.0f %%, Prio Munition %d > Tank %d, Ereignisse %s" % [
		mul0, mul1, fuel_j.target_fraction * 100.0, ammo_j.priority, fuel_j.priority, ev]]
