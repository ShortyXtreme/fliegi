extends TestSuite
## M3 Paket 7a (Strang G): KI-Bodenpersonal Automatik, Prioritäten, Propellerzone, Sim-LOD.

const StubCrew := preload("res://tests/suites/ai_ground/stub_crew.gd")
const TEST_SUITES := {"test_turnaround_totals": "slow"}


func after_each() -> void:
	GroundCrewBrain.player_probe = Callable()


## Baut Platz: Maschine abgestellt, Lager ~150 m, Personal am Tanklager (Plan §2: Wagen rollt dort los).
func _setup(realism: int, fuel := 0.22, tail_frac := 0.7, ammo := 0.0) -> Dictionary:
	var a := _spawn(true)
	a.damage.fuel.set_fraction(fuel)
	a.weapons.set_ammo_fraction(ammo)
	var tz := DamageModel.Zone.TAIL
	a.damage.hp[tz] = a.damage.hp_max[tz] * tail_frac
	var board := JobBoard.new()
	board.rules = GroundRules.for_realism(realism)
	world.add_child(board)
	var disp := GroundCrewDispatch.new()
	disp.board = board
	disp.depot = FuelDepot.new()
	disp.store = AmmoBunker.new()
	disp.aircraft = [a]
	disp.nation_id = a.nation_id
	var side := Vector3(a.global_transform.basis.x.x, 0.0, a.global_transform.basis.x.z).normalized()
	var back := Vector3(a.global_transform.basis.z.x, 0.0, a.global_transform.basis.z.z).normalized()
	disp.depot_pos = a.global_position + side * -100.0 + back * 113.0     # ~150 m
	disp.truck_pos = disp.depot_pos + side * 10.0
	disp.crew_spawn = disp.truck_pos + side * 3.0                        # Personal am Tanklager
	if board.rules.truck_at_spot:                                        # Vereinfacht: Wagen und Personal da
		disp.crew_spawn = a.global_position + side * -12.0
	world.add_child(disp)
	return {a = a, board = board, disp = disp}


func _free(s: Dictionary) -> void:
	for br in GroundCrewBrain.all.duplicate():
		var bd: Node = br.body()
		(bd if bd != null else br).queue_free()
	s.a.queue_free()
	s.board.queue_free()
	s.disp.queue_free()


func _crew(s: Dictionary, mode: int, with_body: bool, start: Vector3, player := false) -> GroundCrewBrain:
	var br := GroundCrewBrain.new()
	br.dispatch = s.disp
	br.board = s.board
	br.force_mode = mode
	br.sim_pos = start
	if player:
		br.work_mul = 1.0
		br.peer_id = 1
	if with_body:
		var c := StubCrew.new()
		world.add_child(c)
		c.global_position = start
		c.add_child(br)
		c.crew_seat.possess(br)
	else:
		world.add_child(br)
	return br


## Läuft echte Physik-Ticks, bis die Maschine versorgt ist. Rückgabe: Sekunden.
func _run_until_serviced(s: Dictionary, max_t: float) -> float:
	var ta := Turnaround.new()
	ta.board = s.board
	ta.best_path = "user://test_g_crew.cfg"
	ta.start(s.a)
	var t := 0.0
	while t < max_t:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		ta.tick(1.0 / 60.0)
		if not s.board.jobs_for(s.a).is_empty() and s.board.is_serviced(s.a):
			break
	return t


func _result(s: Dictionary, sum0: float) -> Dictionary:
	var a: Aircraft = s.a
	var sum1: float = s.disp.depot.total() + a.damage.fuel.total()
	return {
		fuel = a.damage.fuel.total(), ammo = a.weapons.ammo(),
		tail = a.damage.hp[DamageModel.Zone.TAIL], depot = s.disp.depot.total(),
		cons = absf(sum1 - sum0) <= sum0 * 0.001,
		full = a.damage.fuel.fraction() > 0.995 and a.weapons.ammo() == a.weapons.ammo_max() \
			and is_equal_approx(a.damage.hp[DamageModel.Zone.TAIL], a.damage.hp_max[DamageModel.Zone.TAIL]),
	}


## Abnahme 5: Die Automatik versorgt eine gelandete Maschine ohne Befehl (Figuren, volle Darstellung).
func test_auto_service_without_command() -> Array:
	var s := _setup(MatchRules.GroundRealism.STANDARD)
	var said := []
	s.disp.announced.connect(func(txt, _a): said.append(txt))
	var sum0: float = s.disp.depot.total() + s.a.damage.fuel.total()
	_crew(s, 0, true, s.disp.crew_spawn)
	_crew(s, 0, true, s.disp.crew_spawn + Vector3(1, 0, 0))
	var t := await _run_until_serviced(s, 400.0)
	var r := _result(s, sum0)
	var ok: bool = r.full and r.cons and said.size() == 1 and t < 400.0
	return [ok, "versorgt in %.1f s, Tank %.0f l, Munition %d, Heck %.0f, Erhalt %s, Meldung %s" % [
		t, r.fuel, r.ammo, r.tail, r.cons, said]]


## Sim-LOD liefert dasselbe Ergebnis wie die volle Darstellung (Mengen exakt, Zeit ±15 %).
func test_sim_lod_same_result() -> Array:
	var res := []
	for mode in [0, 1]:
		var s := _setup(MatchRules.GroundRealism.STANDARD)
		var sum0: float = s.disp.depot.total() + s.a.damage.fuel.total()
		_crew(s, mode, true, s.disp.crew_spawn)
		_crew(s, mode, true, s.disp.crew_spawn + Vector3(1, 0, 0))
		var t := await _run_until_serviced(s, 400.0)
		var r := _result(s, sum0)
		r.t = t
		res.append(r)
		_free(s)
		await _step(2)
	var f: Dictionary = res[0]
	var l: Dictionary = res[1]
	var ok: bool = f.full and l.full and f.cons and l.cons and absf(f.fuel - l.fuel) < 1.0 and f.ammo == l.ammo \
		and is_equal_approx(f.depot, l.depot) and is_equal_approx(f.tail, l.tail) and absf(l.t / f.t - 1.0) <= 0.15
	return [ok, "voll %.1f s / Sim-LOD %.1f s, Lager %.1f / %.1f l, Munition %d / %d" % [
		f.t, l.t, f.depot, l.depot, f.ammo, l.ammo]]


## Prioritäten: Alarm > Spieler-Maschine > KI-Maschine; Sim-LOD schaltet nach Abstand.
func test_priorities_and_lod_switch() -> Array:
	var s := _setup(MatchRules.GroundRealism.STANDARD)
	var ai_a := _spawn(true)
	ai_a.global_position = s.a.global_position + s.a.global_transform.basis.x * 30.0
	ai_a.damage.fuel.set_fraction(0.3)
	ai_a.weapons.set_ammo_fraction(1.0)
	s.disp.aircraft = [ai_a, s.a]
	s.disp.player_aircraft = [s.a]
	await _step(10)
	s.disp.tick(0.0)
	var br := _crew(s, 1, false, s.disp.crew_spawn)
	br.think(0.016)
	var first: GroundJob = s.board.get_job(br.job_id)
	var p_ok: bool = first != null and first.target == s.a
	Turnaround.quick_service(s.board, ai_a, s.disp.depot, s.disp.store)
	br._drop_focus()
	br.board.release(first.id, br)
	br.think(0.016)
	var second: GroundJob = s.board.get_job(br.job_id)
	var a_ok: bool = second != null and second.target == ai_a
	var far := [Vector3(0, 0, 5000)]
	var near := [s.disp.crew_spawn + Vector3(0, 0, 100)]
	var c2 := _crew(s, -1, true, s.disp.crew_spawn)
	GroundCrewBrain.player_probe = func(): return far
	c2.think(0.016)
	var lod_far: bool = c2.abstract_mode
	GroundCrewBrain.player_probe = func(): return near
	c2.think(0.016)
	var lod_near: bool = c2.abstract_mode
	var ok: bool = p_ok and a_ok and lod_far and not lod_near
	return [ok, "zuerst Spieler %s, Alarm vor Spieler %s, Sim-LOD fern %s / nah %s" % [p_ok, a_ok, lod_far, lod_near]]


## Propellerzone: läuft der Propeller (Pilot drin), verlässt das Personal die 5-m-Zone,
## gibt die Jobs an der Maschine frei und arbeitet nicht weiter.
func test_prop_zone() -> Array:
	var s := _setup(MatchRules.GroundRealism.STANDARD, 1.0, 1.0, 1.0)
	s.disp.fuel_target = 0.9
	var ez := DamageModel.Zone.ENGINE
	s.a.damage.hp[ez] = s.a.damage.hp_max[ez] * 0.5
	var e: Vector3 = s.a.service_point(ServiceMarkers.SVC_ENGINE)
	var br := _crew(s, 0, true, e + s.a.global_transform.basis.x * 3.0)
	await _step(180)
	var working := br.state == GroundCrewBrain.State.WORK
	var clear0 := GroundCrewBrain.zone_clear(s.a)
	var pilot := Controller.new()
	pilot.peer_id = 1
	s.a.add_child(pilot)
	s.a.pilot_seat.possess(pilot)
	var hp0: float = s.a.damage.hp[ez]
	var t := 0.0
	var clear1 := false
	while t < 8.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if GroundCrewBrain.zone_clear(s.a):
			clear1 = true
			break
	await _step(60)
	var hp1: float = s.a.damage.hp[ez]
	await _step(60)
	var mine: int = s.board.open_jobs(s.a).filter(func(j): return j.worker == br.body()).size()
	var ok: bool = working and not clear0 and clear1 and mine == 0 and is_equal_approx(hp1, s.a.damage.hp[ez]) \
		and br.state != GroundCrewBrain.State.WORK and GroundCrewBrain.prop_danger(s.a)
	return [ok, "arbeitet %s, Zone frei vorher %s, nach %.1f s %s, HP %.0f -> %.0f, eigene Jobs %d" % [
		working, clear0, t, clear1, hp0, s.a.damage.hp[ez], mine]]


## Abfertigungszeiten Plan §2 je Stufe (solo / Spieler + 2 KI) im Sim-LOD: höchstens Richtzeit +10 %
## (Abnahme 1). Die Schrittzeiten selbst prüft test_jobs.gd auf ±10 %.
func test_turnaround_totals() -> Array:
	var ok := true
	var lines := []
	for r in 3:
		for helpers in [0, 2]:
			var s := _setup(r)
			var sum0: float = s.disp.depot.total() + s.a.damage.fuel.total()
			_crew(s, 1, false, s.a.service_point(ServiceMarkers.SVC_ENTRY), true)
			for h in helpers:
				_crew(s, 1, false, s.disp.crew_spawn)
			var t := await _run_until_serviced(s, 900.0)
			var res := _result(s, sum0)
			var ref := Turnaround.reference_time(helpers, r)
			var ok_c: bool = res.full and res.cons and t <= ref * 1.1
			ok = ok and ok_c
			lines.append("%s/%d: %.0f s (Soll %.0f)%s" % [MatchRules.ground_realism_name(r), helpers, t, ref,
				"" if res.full else " unvollständig"])
			_free(s)
			await _step(2)
	return [ok, "; ".join(lines)]
