extends TestSuite
## Paket 6: Abschuss, Notausstieg gesperrt/erlaubt, Bauchlandung vs. Absturz,
## SpawnManager (Neustart ≤ 15 s, Wrack 30 s), PilotRecord (Agent B).

const SUITE := "fast"
const Z := DamageModel.Zone

var sm: SpawnManager
var respawns := 0


func before_each() -> void:
	respawns = 0
	sm = SpawnManager.new()
	world.add_child(sm)


func _reg(a: Aircraft, air := true) -> void:
	sm.register(a, null, func():
		respawns += 1
		if air:
			a.place(Transform3D(Basis.looking_at(TestWorld.RUNWAY_DIR, Vector3.UP), Vector3(0, 600, 0)), 80.0, 0.8, false)
		else:
			a.place_on_ground(world.runway_spawn(), TestWorld.RUNWAY_DIR))


func _count(cls_name: String) -> int:
	var n := 0
	for c in world.get_children():
		if c.get_script() != null and c.get_script().get_global_name() == cls_name and not c.is_queued_for_deletion():
			n += 1
	return n


func test_eject_locked_then_allowed() -> Array:
	var a := _spawn(false, 800.0, 80.0, 0.8)
	_reg(a)
	var asked := []
	a.eject_requested.connect(func(_a, allowed): asked.append(allowed))
	var ej := []
	CombatEvents.bus().pilot_ejected.connect(func(ac, p): ej.append(p))
	var c := _seat(a, func(_ac, i, _dt): i.throttle = 0.8)
	c.intent.eject = true
	await _step(3)
	c.intent.eject = false
	await _step(2)
	var locked := asked == [false] and ej.is_empty() and a.damage.pilot_aboard()
	a.damage.apply_hit(Z.ENGINE, 100.0, null)   # schwerer Motorschaden
	c.intent.eject = true
	await _step(3)
	var rec := a.pilot
	var ok: bool = locked and asked.size() == 2 and asked[1] and ej.size() == 1 and ej[0] == rec \
		and a.damage.is_destroyed and a.damage.destroy_cause == CombatEvents.Cause.EJECTED \
		and rec.alive and _count("Parachute") == 1
	# Neustart nach 15 s mit demselben (überlebenden) Piloten
	c.intent.eject = false
	await _step(int(MatchRules.respawn_delay * 60) + 5)
	ok = ok and respawns == 1 and a.pilot == rec and not a.damage.is_destroyed and a.damage.pilot_aboard()
	return [ok, "intakt gesperrt=%s, Motorschaden -> Ausstieg, Fallschirm, Neustart nach 15 s (%d), gleicher Pilot %s" % [locked, respawns, a.pilot == rec]]


func test_shootdown_event_and_respawn() -> Array:
	var a := _spawn(false, 800.0, 80.0, 0.8)
	var e := _spawn(false, 900.0, 80.0, 0.8)
	e.nation_id = Nations.RED
	e.global_position.x = 300.0
	_reg(a)
	var ev := []
	CombatEvents.bus().aircraft_destroyed.connect(func(v, k, cause): ev.append([v, k, cause]))
	var rec := a.pilot
	a.damage.apply_hit(Z.COCKPIT, 100.0, e)
	await _step(int(14.5 * 60))
	var waiting := respawns == 0 and sm.time_to_respawn(a) > 0.0
	await _step(40)
	var ok: bool = ev.size() == 1 and ev[0][0] == a and ev[0][1] == e and ev[0][2] == CombatEvents.Cause.PILOT_KILLED \
		and waiting and respawns == 1 and not rec.alive and a.pilot != rec and a.pilot.alive
	return [ok, "Abschuss gemeldet (Kredit an Gegner), wartet bei 14,5 s: %s, Neustart ≤ 15 s: %s, neuer Pilot: %s" % [waiting, respawns == 1, a.pilot != rec]]


func test_belly_landing_survives() -> Array:
	var a := _spawn(false, 3.0, 38.0, 0.0)
	a.global_position.y = a.data.ground_height - 0.3
	a.linear_velocity += Vector3.DOWN * 1.5
	a.flight.gear.extension = 0.0
	_reg(a, false)
	var out := []
	a.damage.grounded.connect(func(o): out.append(o))
	var rec := a.pilot
	var c := _seat(a, func(_ac, i, _dt): i.throttle = 0.0; i.gear_down = false)
	await _step(240)
	var ok: bool = out.size() >= 1 and out[0] == DamageModel.Outcome.BELLY_LANDED and rec.alive \
		and not a.damage.is_destroyed
	return [ok, "Ausgang %s, Pilot lebt %s, kein Abschuss %s" % [out, rec.alive, not a.damage.is_destroyed]]


func test_crash_wreck_and_new_pilot() -> Array:
	var a := _spawn(false, 60.0, 0.0, 0.0)
	a.global_transform.basis = Basis.looking_at(Vector3(0, -1, -1).normalized(), Vector3.UP)
	a.linear_velocity = Vector3(0, -1, -1).normalized() * 90.0
	_reg(a)
	var rec := a.pilot
	var ev := []
	CombatEvents.bus().aircraft_destroyed.connect(func(v, k, cause): ev.append(cause))
	await _step(120)
	var crashed: bool = a.damage.outcome == DamageModel.Outcome.CRASHED and not rec.alive \
		and ev == [CombatEvents.Cause.CRASH]
	await _step(int(MatchRules.respawn_delay * 60) + 5)
	var wreck_ok := _count("Wreck") == 1 and respawns == 1 and a.pilot != rec
	await _step(int((MatchRules.wreck_lifetime - MatchRules.respawn_delay) * 60) + 5)
	var gone := _count("Wreck") == 0
	var ok := crashed and wreck_ok and gone
	return [ok, "Absturz -> Pilot verloren %s, Wrack nach Neustart %s, Wrack weg nach 30 s %s" % [crashed, wreck_ok, gone]]


func test_ground_contact_after_hit_is_kill() -> Array:
	var a := _spawn(false, 3.0, 38.0, 0.0)
	var e := _spawn(false, 900.0, 80.0, 0.8)
	e.nation_id = Nations.RED
	a.global_position.y = a.data.ground_height - 0.3
	a.flight.gear.extension = 0.0
	a.damage.apply_hit(Z.TAIL, 5.0, e)
	var ev := []
	CombatEvents.bus().aircraft_destroyed.connect(func(v, k, cause): ev.append([k, cause]))
	_seat(a, func(_ac, i, _dt): i.throttle = 0.0; i.gear_down = false)
	await _step(240)
	var ok: bool = ev.size() == 1 and ev[0][0] == e and a.damage.outcome == DamageModel.Outcome.BELLY_LANDED
	return [ok, "Bodenberührung ≤ 30 s nach Treffer -> Abschuss für Gegner: %s" % [ev]]


func test_pilot_record_xp() -> Array:
	var p := PilotRecord.new()
	p.add_xp(50, "kill")
	p.add_xp(20, "assist")
	var pending := p.pending_total()
	var banked := p.bank_xp()
	p.add_xp(30)
	p.on_killed()
	var ok := pending == 70 and banked == 70 and p.xp_banked == 70 and p.xp_pending.is_empty() and not p.alive \
		and p.dispersion_mul() == 1.0 and p.spot_range_mul() == 1.0
	return [ok, "XP offen 70 -> gutgeschrieben %d, Tod verwirft offene XP" % banked]
