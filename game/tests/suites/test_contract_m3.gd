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
