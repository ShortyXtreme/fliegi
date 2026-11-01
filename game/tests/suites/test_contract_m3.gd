extends TestSuite
## Paket 0 (Vertragsschnitt M3, docs/m3_vertrag.md): Schnittstellen für den Bodenbetrieb
## sind vorhanden und ändern das M2-Verhalten nicht. Suite "fast".

const SUITE := "fast"


## Ersatz-Figur für Sitzwechsel-Tests (CrewCharacter kommt in Paket 4).
class FakeCrew extends Node3D:
	var crew_seat: Seat


func _crew(session: PlayerSession, pos: Vector3) -> FakeCrew:
	var ch := FakeCrew.new()
	world.add_child(ch)
	ch.global_position = pos
	ch.crew_seat = Seat.new()
	ch.crew_seat.role = Seat.Role.CREW
	ch.crew_seat.vehicle = ch
	ch.add_child(ch.crew_seat)
	if session != null:
		session.take_seat(ch.crew_seat)
	return ch


# --- 0a: Steuerung ---------------------------------------------------------------

func test_crew_intent_roundtrip() -> Array:
	var i := CrewIntent.new()
	i.move = Vector2(0.6, -0.8)
	i.look_yaw = 1.25
	i.look_pitch = -0.4
	i.sprint = true
	i.interact = true
	i.enter = true
	i.wheel_open = true
	i.wheel_choice = 5
	i.view_toggle = true
	var a := i.to_array()
	var j := CrewIntent.from_array(a)
	var ok := a.size() == 6 and j.move.is_equal_approx(i.move) and is_equal_approx(j.look_yaw, 1.25) \
		and is_equal_approx(j.look_pitch, -0.4) and j.sprint and j.interact and not j.drop \
		and j.enter and j.wheel_open and j.wheel_choice == 5 and j.view_toggle \
		and j.button_bits() == i.button_bits()
	var c := Controller.new()
	var n := c.compute_crew_intent(1.0 / 60.0)
	ok = ok and n.move == Vector2.ZERO and n.button_bits() == 0 and n.wheel_choice == -1
	c.free()
	var big := CrewIntent.new()
	big.move = Vector2(3, 4)
	ok = ok and is_equal_approx(big.clamp_values().move.length(), 1.0)
	ok = ok and Seat.Role.CREW > Seat.Role.BOMBARDIER and Seat.Role.has("DRIVER") and Seat.Role.has("PASSENGER")
	return [ok, "CrewIntent %s -> Bits %d, neutral ok, Rollen CREW/DRIVER/PASSENGER" % [a, j.button_bits()]]


## Je Kontext keine Doppelbelegung; jede Aktion gehört zu einem Kontext; Pflichttasten.
func test_binding_contexts() -> Array:
	InputBindings.setup()
	var dup := []
	var maps := {}
	for ctx in InputBindings.Context.values():
		var r: Array = load("res://tests/suites/test_contract_m2.gd").binding_map(ctx)
		maps[ctx] = r[0]
		dup.append_array(r[1])
	var orphan := []
	for act in InputMap.get_actions():
		if String(act).begins_with("ui_"):
			continue
		var found := false
		for ctx in InputBindings.Context.values():
			found = found or InputBindings.in_context(act, ctx)
		if not found:
			orphan.append(act)
	var crew: Dictionary = maps[InputBindings.Context.CREW]
	var drive: Dictionary = maps[InputBindings.Context.DRIVE]
	var flight: Dictionary = maps[InputBindings.Context.FLIGHT]
	var is_ := func(m: Dictionary, k: String, act: String) -> bool: return m.get(k, &"") == StringName(act)
	var ok: bool = dup.is_empty() and orphan.is_empty() \
		and is_.call(crew, "key:%d" % KEY_E, "crew_interact") and is_.call(crew, "btn:%d" % JOY_BUTTON_A, "crew_interact") \
		and is_.call(crew, "key:%d" % KEY_F, "crew_enter") \
		and is_.call(crew, "key:%d" % KEY_TAB, "crew_wheel") and is_.call(crew, "btn:%d" % JOY_BUTTON_LEFT_SHOULDER, "crew_wheel") \
		and is_.call(crew, "key:%d" % KEY_C, "crew_view_toggle") \
		and is_.call(drive, "key:%d" % KEY_J, "eject_hold") and is_.call(drive, "btn:%d" % JOY_BUTTON_DPAD_LEFT, "eject_hold") \
		and is_.call(flight, "key:%d" % KEY_J, "eject_hold") and is_.call(flight, "key:%d" % KEY_F, "flaps_cycle") \
		and is_.call(crew, "key:%d" % KEY_F1, "help_toggle") and is_.call(drive, "key:%d" % KEY_F1, "help_toggle")
	return [ok, "Belegungen Flug %d / zu Fuß %d / Fahren %d, Konflikte %s, ohne Kontext %s" % [
		flight.size(), crew.size(), drive.size(), dup if dup else "keine", orphan if orphan else "keine"]]


## SeatService: Rechte und Prüfungen beim Ein-/Aussteigen, Kontextwechsel der Session.
func test_seat_service_rights() -> Array:
	var a := _spawn(true)
	var ai := _seat(a, func(_ac, i: PilotIntent, _dt): i.brakes = 1.0)
	await _step(30)
	var svc := SeatService.new()
	world.add_child(svc)
	var session := PlayerSession.new()
	world.add_child(session)
	a.pilot_seat.entry_offset = Vector3(-1.5, 0.0, 0.5)
	var ch := _crew(session, a.global_position + Vector3(30, 0, 0))
	var R := SeatService.Result
	var res := []
	var ctx := [session.context]
	res.append(svc.request_enter(1, ch, a.pilot_seat))             # zu weit
	ch.global_position = a.pilot_seat.entry_position() + Vector3(0.5, 0, 0)
	res.append(svc.request_enter(2, ch, a.pilot_seat))             # fremder Peer
	Authority.simulate_client = true
	res.append(svc.request_enter(1, ch, a.pilot_seat))             # Client
	Authority.simulate_client = false
	var displaced := []
	svc.ai_displaced.connect(func(c, _s): displaced.append(c))
	res.append(svc.request_enter(1, ch, a.pilot_seat))             # ok, KI macht Platz
	var in_pilot := a.pilot_seat.controller == session.flight and ch.crew_seat.controller == null
	ctx.append(session.context)
	res.append(svc.request_exit(2, a.pilot_seat))                  # fremder Peer
	res.append(svc.request_exit(1, a.pilot_seat))                  # ok
	ctx.append(session.context)
	var back := ch.crew_seat.controller == session.crew and a.pilot_seat.controller == null \
		and ch.global_position.distance_to(a.pilot_seat.entry_position()) < 0.01 and ch.visible
	# Mensch im Sitz -> besetzt
	var other := ScriptedController.new()
	other.peer_id = 2
	a.add_child(other)
	a.pilot_seat.possess(other)
	res.append(svc.request_enter(1, ch, a.pilot_seat))             # besetzt
	# In der Luft und in Fahrt
	var b := _spawn(false, 600.0, 80.0, 0.8)
	b.pilot_seat.entry_offset = Vector3.ZERO
	ch.global_position = b.global_position
	res.append(svc.request_enter(1, ch, b.pilot_seat))             # in Fahrt
	var want := [R.TOO_FAR, R.BAD_PEER, R.NOT_SERVER, R.OK, R.BAD_PEER, R.OK, R.OCCUPIED, R.MOVING]
	var C := InputBindings.Context
	var ok := res == want and displaced == [ai] and in_pilot and back \
		and ctx == [C.CREW, C.FLIGHT, C.CREW]
	return [ok, "Ergebnisse %s (soll %s), KI verdrängt %d, Kontexte %s" % [
		res.map(SeatService.result_text), want.map(SeatService.result_text), displaced.size(), ctx]]


## Halte-Taste am Boden im Stand = Aussteigen (exit_requested), kein Notausstieg.
func test_exit_hold_on_ground() -> Array:
	var a := _spawn(true)
	var pc := PlayerController.new()
	pc.mouse_aim_enabled = false
	pc.exit_on_ground = true
	a.add_child(pc)
	a.pilot_seat.possess(pc)
	await _step(30)
	var ejects := []
	var exits := []
	a.eject_requested.connect(func(_ac, allowed): ejects.append(allowed))
	pc.exit_requested.connect(func(): exits.append(true))
	Input.action_press("eject_hold")
	await _step(75)
	Input.action_release("eject_hold")
	await _step(2)
	var ok := exits.size() == 1 and ejects.is_empty() and pc.exit_mode
	# Standard (M2): ohne exit_on_ground bleibt es der Notausstieg
	pc.exit_on_ground = false
	Input.action_press("eject_hold")
	await _step(75)
	Input.action_release("eject_hold")
	await _step(2)
	ok = ok and ejects.size() == 1 and exits.size() == 1
	return [ok, "Aussteigen %d, Notausstieg-Anfragen %s" % [exits.size(), ejects]]


func test_ground_events_bus() -> Array:
	var bus := GroundEvents.bus()
	var got := []
	bus.job_blocked.connect(func(id, r): got.append([id, r]))
	bus.job_added.emit(1, &"refuel", null)
	bus.job_progress.emit(1, &"pump", 0.5, null)
	bus.job_blocked.emit(1, &"depot_empty")
	bus.job_done.emit(1, null)
	bus.depot_changed.emit(null)
	bus.turnaround.emit(null, 100.0, 2)
	var ok := got == [[1, &"depot_empty"]]
	GroundEvents.reset()
	ok = ok and GroundEvents.bus() != bus
	return [ok, "GroundEvents-Signale, reset()"]


func test_match_rules_ground() -> Array:
	var M := MatchRules
	var ok := M.ground_realism == M.GroundRealism.STANDARD \
		and is_equal_approx(M.start_fuel(M.StartKind.FIRST), 0.5) and is_equal_approx(M.start_ammo(M.StartKind.FIRST), 1.0) \
		and is_equal_approx(M.start_fuel(M.StartKind.AFTER_LOSS), 0.15) and M.start_ammo(M.StartKind.AFTER_LOSS) == 0.0 \
		and M.start_fuel(M.StartKind.AFTER_LANDING) < 0.0 and M.start_ammo(M.StartKind.AFTER_LANDING) < 0.0
	var path := "user://test_m3_contract.cfg"
	var cf := ConfigFile.new()
	cf.set_value("m3", "bodenbetrieb", "authentisch")
	cf.save(path)
	M.load_ground_config(path, PackedStringArray())
	var from_cfg := M.ground_realism
	M.load_ground_config(path, PackedStringArray(["--boden=einfach"]))
	var from_arg := M.ground_realism
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ok = ok and from_cfg == M.GroundRealism.AUTHENTISCH and from_arg == M.GroundRealism.EINFACH \
		and M.parse_ground_realism("Vereinfacht") == 0 and M.parse_ground_realism("xyz") == -1
	M.reset()
	ok = ok and M.ground_realism == M.GroundRealism.STANDARD
	return [ok, "Stufe Standard, cfg -> %s, --boden= -> %s, Startzustände 50/100, 15/0, Rest" % [
		M.ground_realism_name(from_cfg), M.ground_realism_name(from_arg)]]


# --- 0b: Spielsysteme ------------------------------------------------------------

## place(refill=false) behält den Restzustand, ServiceState setzt Startzustände.
func test_place_refill_service() -> Array:
	var a := _spawn(true)
	var cap := a.damage.fuel.capacity[0] + a.damage.fuel.capacity[1]
	var guns := a.weapons.gun_count()
	a.damage.apply_hit(DamageModel.Zone.TAIL, 30.0, null)
	a.damage.fuel.set_fraction(0.22)
	a.weapons.set_ammo_fraction(0.0)
	var xf := a.global_transform
	a.place(xf, 0.0, 0.0, true, false)                           # Restzustand
	var keep := is_equal_approx(a.damage.fuel.fraction(), 0.22) and a.weapons.ammo() == 0 \
		and a.damage.hp_fraction(DamageModel.Zone.TAIL) < 1.0
	a.place(xf, 0.0, 0.0, true, false, ServiceState.for_start(MatchRules.StartKind.AFTER_LOSS))
	var loss := is_equal_approx(a.damage.fuel.fraction(), 0.15) and a.weapons.ammo() == 0 \
		and a.damage.hp_fraction(DamageModel.Zone.TAIL) == 1.0
	a.place(xf, 0.0, 0.0, true, false, ServiceState.for_start(MatchRules.StartKind.FIRST))
	var first := is_equal_approx(a.damage.fuel.fraction(), 0.5) and a.weapons.ammo() == a.weapons.ammo_max()
	a.damage.fuel.set_fraction(0.3)
	a.place(xf)                                                  # M2: voll
	var full := is_equal_approx(a.damage.fuel.fraction(), 1.0) and a.weapons.ammo() == a.weapons.ammo_max()
	var ok := keep and loss and first and full and guns > 0 and cap > 0.0
	return [ok, "Rest=%s, nach Abschuss 15 %%/0=%s, erste 50 %%/voll=%s, M2 voll=%s" % [keep, loss, first, full]]


## Mengen-Erhalt Lager -> Tank (Stub-Ebene) und Ersatzbenzin-Leistung.
func test_fuel_conservation_and_grade() -> Array:
	var a := _spawn(true)
	var f := a.damage.fuel
	f.set_fraction(0.1)
	var depot := FuelDepot.new()
	var sum0 := depot.total() + f.total()
	var moved := 0.0
	for k in 40:                                                 # 40 × 12 l, Tank läuft über
		var got := depot.draw(FuelSystem.GRADE_AVIATION, 12.0)
		var acc := f.add(got, FuelSystem.GRADE_AVIATION)
		depot.deposit(FuelSystem.GRADE_AVIATION, got - acc)
		moved += acc
	var sum1 := depot.total() + f.total()
	var cons := absf(sum1 - sum0) <= sum0 * 0.001 and is_equal_approx(f.fraction(), 1.0)
	f.set_fraction(0.0)
	f.add(100.0, FuelSystem.GRADE_ERSATZ)
	await _step(2)
	var p_ers := a.damage.modifiers.engine_power_mul
	f.add(100.0, FuelSystem.GRADE_AVIATION)
	await _step(2)
	var p_mix := a.damage.modifiers.engine_power_mul
	f.refill()
	await _step(2)
	var ok := cons and is_equal_approx(p_ers, 0.88) and is_equal_approx(p_mix, 0.94) \
		and is_equal_approx(a.damage.modifiers.engine_power_mul, 1.0)
	return [ok, "Summe %.1f -> %.1f l (umgefüllt %.1f l), Leistung Ersatz %.3f, 50/50 %.3f" % [
		sum0, sum1, moved, p_ers, p_mix]]


func test_repair_and_load_gun() -> Array:
	var a := _spawn(true)
	var d := a.damage
	d.apply_hit(DamageModel.Zone.TAIL, 60.0, null)
	var before := d.hp[DamageModel.Zone.TAIL]
	var r1 := d.repair(DamageModel.Zone.TAIL, 25.0)
	var r2 := d.repair(DamageModel.Zone.TAIL, 1000.0)
	d.apply_hit(DamageModel.Zone.WING_L, 10000.0, null)          # Flügelbruch
	var r3 := d.repair(DamageModel.Zone.WING_L, 50.0)
	Authority.simulate_client = true
	var a2 := _spawn(true)
	a2.damage.hp[DamageModel.Zone.TAIL] = 10.0
	var r4 := a2.damage.repair(DamageModel.Zone.TAIL, 5.0)
	Authority.simulate_client = false
	var w := a2.weapons
	w.set_ammo_fraction(0.0)
	var bunker := AmmoBunker.new({AmmoBunker.AMMO_792: 300})
	var t: StringName = w.magazines[0].ammo_type
	bunker.stock = {t: 300}
	var l1 := w.load_gun(0, bunker, 200)
	var l2 := w.load_gun(0, bunker, 10000)
	var cap := w.gun_capacity(0)
	var ok := is_equal_approx(r1, 25.0) and is_equal_approx(r2, d.hp_max[DamageModel.Zone.TAIL] - before - 25.0) \
		and r3 == 0.0 and r4 == 0.0 and l1 == 200 and l2 == mini(100, cap - 200) \
		and bunker.available(t) == 300 - l1 - l2 and w.gun_ammo(0) == l1 + l2 \
		and InfiniteAmmoStore.new().available(t) > 1000000
	return [ok, "Reparatur %.0f+%.0f HP, Flügelbruch %.0f, Client %.0f; Gurt %d+%d Schuss, Bunker Rest %d" % [
		r1, r2, r3, r4, l1, l2, bunker.available(t)]]


## Stubs aller neuen Klassen ladbar, Jobs/Board/Pistenvergabe mit festen Signaturen.
func test_stub_classes() -> Array:
	var board := JobBoard.new()
	world.add_child(board)
	var a := _spawn(true)
	var jobs := [RefuelJob.new(), RearmJob.new(), RepairJob.new(), LoadOrdnanceJob.new()]
	var ids := []
	for j in jobs:
		j.target = a
		ids.append(board.add_job(j))
	var blocked := []
	GroundEvents.bus().job_blocked.connect(func(id, r): blocked.append(r))
	board.request_step(1, ids[3], &"", 0.1)
	Authority.simulate_client = true
	var client_ok := board.request_step(1, ids[0], &"bring", 0.1) or board.add_job(RefuelJob.new()) != 0
	Authority.simulate_client = false
	var rc := RunwayControl.new()
	var b := _spawn(true)
	var rw := rc.request(a) and not rc.request(b)
	rc.release(a)
	rw = rw and rc.request(b)
	rc.free()
	var objs := [CrewCharacter.new(), CrewCamera.new(), FuelTruck.new(), AmmoCart.new(),
		GroundCrewBrain.new(), GroundHud.create(null), Interactable.new()]
	var seats_ok: bool = objs[0].crew_seat.role == Seat.Role.CREW and objs[2].driver_seat.role == Seat.Role.DRIVER \
		and objs[2].passenger_seat.role == Seat.Role.PASSENGER and objs[2].tank.available(FuelSystem.GRADE_AVIATION) == 2000.0 \
		and objs[3].store.available(AmmoBunker.AMMO_792) == 3000
	for o in objs:
		o.free()
	var ph := AirfieldPhases.new()
	var ok: bool = ids == [1, 2, 3, 4] and board.jobs_for(a).size() == 4 and jobs[0].steps.size() == 5 \
		and jobs[1].steps.size() == 4 and blocked == [&"not_available"] and not client_ok and rw and seats_ok \
		and ph.phase == AirfieldPhases.Phase.COMBAT and not ph.tick(a, PilotIntent.new(), 0.016) \
		and GroundCrewBrain.COMMAND_LABELS.size() >= 6 \
		and GroundRules.for_realism(MatchRules.GroundRealism.EINFACH).pump_lps == 30.0 \
		and GroundRules.for_realism().pump_lps == 6.0 \
		and GroundRules.for_realism(MatchRules.GroundRealism.AUTHENTISCH).pump_lps == 4.0
	return [ok, "Jobs %s, blockiert %s, Client abgelehnt %s, Piste exklusiv %s, Sitze %s" % [
		ids, blocked, not client_ok, rw, seats_ok]]


## Service-Marker: Namen fest, Ersatzpositionen plausibel, Einstieg am Pilotensitz.
func test_service_markers() -> Array:
	var a := _spawn(true)
	var pts := {}
	for m in ServiceMarkers.AIRCRAFT:
		pts[m] = ServiceMarkers.aircraft_point(a, m)
	var e: Vector3 = pts[ServiceMarkers.SVC_ENTRY]
	var ok: bool = pts[ServiceMarkers.SVC_GUN_HATCH_L].x < 0.0 and pts[ServiceMarkers.SVC_GUN_HATCH_R].x > 0.0 \
		and e.x < 0.0 and a.pilot_seat.entry_offset == e \
		and pts[ServiceMarkers.SVC_ENGINE].z < pts[ServiceMarkers.SVC_ENTRY].z \
		and a.service_point(ServiceMarkers.SVC_ENTRY).distance_to(a.global_transform * e) < 1e-3 \
		and ServiceMarkers.crate_slot(3) == "crate_slot_3"
	return [ok, "Marker %s" % pts]
