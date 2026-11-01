extends TestSuite
## Paket 7: Wahrnehmung, Schwierigkeit und Grundverhalten der Kampf-KI.

const U := preload("res://tests/suites/ai/duel_util.gd")


func make_world() -> Node3D:
	return DuelArena.new(false)


func test_difficulty_levels() -> Array:
	var r := AIDifficulty.load_level("rekrut")
	var e := AIDifficulty.load_level("erfahren")
	var v := AIDifficulty.load_level("veteran")
	var ok := r != null and e != null and v != null \
		and is_equal_approx(r.reaction_time, 0.9) and is_equal_approx(e.reaction_time, 0.5) \
		and is_equal_approx(v.reaction_time, 0.25) and is_equal_approx(r.aim_error_mrad, 12.0) \
		and is_equal_approx(e.aim_error_mrad, 6.0) and is_equal_approx(v.aim_error_mrad, 2.5) \
		and is_equal_approx(r.g_use, 0.6) and is_equal_approx(v.g_use, 0.95) \
		and not r.has_maneuver(AIDifficulty.Maneuver.SPIRAL) \
		and v.has_maneuver(AIDifficulty.Maneuver.SPIRAL)
	return [ok, "Rekrut/Erfahren/Veteran geladen, Werte laut Plan"]


func test_perception_hostility_cones_delay() -> Array:
	MatchRules.spot_mode = 1  # Realistisch: Basis 3 km
	var me := U.spawn(world, Vector3(0, 1500, 0), Vector3.FORWARD, Nations.BLUE, 1)
	var foe_front := U.spawn(world, Vector3(0, 1500, -3500), Vector3.FORWARD, Nations.RED, 2)
	var foe_rear := U.spawn(world, Vector3(0, 1500, 2000), Vector3.FORWARD, Nations.RED, 3)
	var friend := U.spawn(world, Vector3(0, 1500, -500), Vector3.FORWARD, Nations.BLUE, 4)
	for a in [me, foe_front, foe_rear, friend]:
		a.freeze = true
	var p := AIPerception.new(me, 0.5)
	var dt := 1.0 / 60.0
	p.update(dt)
	var early := p.best_target() == null
	for i in 40:
		p.update(dt)
	var c: AIPerception.Contact = p.best_target()
	var front_known: bool = p.contacts.has(foe_front) and p.contacts[foe_front].known
	var rear_known: bool = p.contacts.has(foe_rear) and p.contacts[foe_rear].known
	var ok := early and c != null and c.node == foe_front and front_known \
		and not rear_known and not p.contacts.has(friend)
	return [ok, "Frontkegel %.0f m sieht 3,5 km, Heck %.0f m sieht 2 km nicht, Freund ignoriert, erst nach Reaktionszeit=%s" % [
		p.view_range(foe_front), p.view_range(foe_rear), early]]


func test_reaction_delay_buffer() -> Array:
	var me := U.spawn(world, Vector3(0, 1500, 0), Vector3.FORWARD, Nations.BLUE, 1)
	var foe := U.spawn(world, Vector3(0, 1500, -800), Vector3.FORWARD, Nations.RED, 2, 100.0)
	me.freeze = true
	var p := AIPerception.new(me, 0.5)
	for i in 60:
		await _step(1)
		p.update(1.0 / 60.0)
	var c: AIPerception.Contact = p.contacts[foe]
	var lag := c.pos.distance_to(foe.global_position)
	return [lag > 35.0 and lag < 65.0, "Wahrgenommene Lage hinkt %.1f m hinterher (≈ 0,5 s × 100 m/s)" % lag]


func test_pursuit_fires_and_hits() -> Array:
	var tgt := U.spawn(world, Vector3(0, 1500, -300), Vector3.FORWARD, Nations.RED, 2, 110.0)
	_seat(tgt, func(_a, i: PilotIntent, _dt): i.throttle = 0.7; i.gear_down = false)
	var me := U.spawn(world, Vector3(30, 1520, 0), Vector3.FORWARD, Nations.BLUE, 1, 130.0)
	var brain := U.brain(me, "veteran", 1)
	var hits := [0]
	CombatEvents.bus().hit_confirmed.connect(func(s, t, _z, _d): if s == me and t == tgt: hits[0] += 1)
	var fired_states := {}
	for k in 600:
		await _step(1)
		fired_states[brain.state] = true
		if hits[0] >= U.KILL_HITS:
			break
	var shots := me.weapons.ammo_max() - me.weapons.ammo()
	return [hits[0] >= U.KILL_HITS and fired_states.has(AIPilotBrain.State.FIRE),
			"%d Schuss, %d Ersatz-Treffer auf geradeaus fliegendes Ziel (ps %d/%d abgelehnt, Fehler %.1f°, d %.0f)" % [shots, hits[0], projectiles.hits_total, projectiles.hits_rejected, brain.aim_error_deg, me.global_position.distance_to(tgt.global_position)]]


func test_ground_avoid_from_dive() -> Array:
	var me := U.spawn(world, Vector3(0, 700, 0), Vector3(0, -1.7, -1), Nations.BLUE, 1, 140.0)
	var brain := U.brain(me, "rekrut", 2)
	var min_alt := INF
	var saw := false
	for k in 600:
		await _step(1)
		min_alt = minf(min_alt, me.global_position.y)
		saw = saw or brain.state == AIPilotBrain.State.GROUND_AVOID
	return [min_alt > 60.0 and saw, "60°-Sturz aus 700 m mit 140 m/s: tiefster Punkt %.0f m" % min_alt]


func test_ground_avoid_inverted() -> Array:
	var me := U.spawn(world, Vector3(0, 450, 0), Vector3(0, -0.6, -1), Nations.BLUE, 1, 120.0)
	me.global_transform.basis = me.global_transform.basis * Basis(Vector3.FORWARD, PI)
	U.brain(me, "erfahren", 3)
	var min_alt := INF
	for k in 600:
		await _step(1)
		min_alt = minf(min_alt, me.global_position.y)
	return [min_alt > 60.0, "Rückenflug-Sinkflug aus 450 m: tiefster Punkt %.0f m" % min_alt]


func test_evade_when_attacked() -> Array:
	var me := U.spawn(world, Vector3(0, 1500, 0), Vector3.FORWARD, Nations.BLUE, 1, 120.0)
	var foe := U.spawn(world, Vector3(0, 1500, 350), Vector3.FORWARD, Nations.RED, 2, 130.0)
	_seat(foe, func(_a, i: PilotIntent, _dt): i.throttle = 0.8; i.gear_down = false)
	var brain := U.brain(me, "erfahren", 4)
	var saw := false
	for k in 120:
		await _step(1)
		saw = saw or brain.state == AIPilotBrain.State.EVADE
	return [saw, "Feind 350 m am Heck → Ausweichen=%s" % saw]


func test_energy_and_retreat() -> Array:
	var me := U.spawn(world, Vector3(0, 1500, 0), Vector3.FORWARD, Nations.BLUE, 1, 50.0)
	var brain := U.brain(me, "erfahren", 5)
	var energy := false
	for k in 30:
		await _step(1)
		energy = energy or brain.state == AIPilotBrain.State.ENERGY
	for m in me.weapons.magazines:
		m.take(int(m.capacity * 0.95) if m.get("capacity") != null else 0)
	var low_ammo := float(me.weapons.ammo()) / me.weapons.ammo_max() < 0.1
	for k in 600:
		await _step(1)
		if brain.state == AIPilotBrain.State.RETREAT:
			break
	var retreat := brain.state == AIPilotBrain.State.RETREAT
	return [energy and (retreat or not low_ammo), "Energie bei 180 km/h=%s, Rückzug bei Munition < 10 %%=%s" % [energy, retreat]]
