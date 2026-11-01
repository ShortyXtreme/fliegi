extends TestSuite
## Paket 0 (Vertragsschnitt M2): prüft, dass alle Schnittstellen und Hooks vorhanden sind
## und im Neutralzustand das M1.1-Verhalten nicht verändern. Suite "fast".

const SUITE := "fast"


func test_nations_hostile() -> Array:
	var ok := Nations.is_hostile(Nations.BLUE, Nations.RED) and Nations.is_hostile(Nations.RED, Nations.BLUE) \
		and not Nations.is_hostile(Nations.BLUE, Nations.BLUE) and not Nations.is_hostile(Nations.NONE, Nations.RED) \
		and Nations.is_friendly(Nations.RED, Nations.RED)
	Nations.set_relation(Nations.BLUE, Nations.RED, Nations.Relation.NEUTRAL)
	ok = ok and not Nations.is_hostile(Nations.RED, Nations.BLUE)
	Nations.reset()
	var a := _spawn(false, 800.0, 80.0, 0.8)
	var b := _spawn(false, 900.0, 80.0, 0.8)
	b.nation_id = Nations.RED
	ok = ok and a.is_hostile_to(b) and not a.is_hostile_to(a) and a.entity_id != b.entity_id
	ok = ok and a.collision_layer == Layers.AIRCRAFT and a.collision_mask & Layers.WORLD != 0
	return [ok, "Diplomatie-Matrix, is_hostile, Aircraft.nation_id/entity_id, Layer"]


func test_combat_events_bus() -> Array:
	var bus := CombatEvents.bus()
	bus.log_enabled = true
	var a := _spawn(false, 800.0, 80.0, 0.8)
	var b := _spawn(false, 900.0, 80.0, 0.8)
	var got := []
	bus.aircraft_destroyed.connect(func(v, k, c): got.append([v, k, c]))
	bus.shot_fired.emit(a, 0, 1)
	bus.hit_confirmed.emit(a, b, DamageModel.Zone.WING_L, 12.5)
	bus.aircraft_damaged.emit(b, DamageModel.Zone.WING_L, 12.5, a)
	bus.aircraft_destroyed.emit(b, a, CombatEvents.Cause.WING_BROKEN)
	bus.pilot_ejected.emit(b, PilotRecord.new())
	bus.pilot_rescued.emit(PilotRecord.new(), null)
	var h1 := bus.log_hash()
	var ok: bool = got.size() == 1 and got[0][1] == a and bus.event_log.size() == 6 and h1 != 0
	CombatEvents.reset()
	ok = ok and CombatEvents.bus() != bus and CombatEvents.bus().event_log.is_empty()
	return [ok, "6 Signale, Ereignis-Log %d Einträge, Hash %d" % [bus.event_log.size(), h1]]


func test_spotting_formula() -> Array:
	var a := _spawn(false, 800.0, 80.0, 0.8)
	var b := _spawn(false, 900.0, 80.0, 0.8)
	b.nation_id = Nations.RED
	var arc := Spotting.spot_range(a, b, MatchRules.SpotMode.ARCADE)
	var real := Spotting.spot_range(a, b, MatchRules.SpotMode.REALISTIC)
	a.crew_level = 3
	var vet := Spotting.spot_range(a, b, MatchRules.SpotMode.REALISTIC)
	var r := RadarStation.new(b.global_position, 5000.0, Nations.BLUE)
	Spotting.register_radar(r)
	var radar := Spotting.spot_range(a, b, MatchRules.SpotMode.REALISTIC)
	r.operational = false
	var radar_off := Spotting.spot_range(a, b, MatchRules.SpotMode.REALISTIC)
	var ok := arc > real and is_equal_approx(vet, real * Spotting.LEVEL_SPOT_MUL) \
		and is_equal_approx(radar, vet + Spotting.RADAR_BONUS) and is_equal_approx(radar_off, vet) \
		and Spotting.can_spot(a, b)
	return [ok, "Arcade %.0f m, Realistisch %.0f m, Level 3 %.0f m, + Radar %.0f m" % [arc, real, vet, radar]]


## Neutrale Modifier ändern nichts; jeder Hook wirkt in die erwartete Richtung.
func test_flight_modifier_hooks() -> Array:
	var ref := _spawn(false, 1000.0, 80.0, 1.0)
	var mods: Array[Aircraft] = [_spawn(false, 1000.0, 80.0, 1.0), _spawn(false, 1000.0, 80.0, 1.0),
		_spawn(false, 1000.0, 80.0, 1.0), _spawn(false, 1000.0, 80.0, 1.0)]
	var all: Array[Aircraft] = [ref]
	all.append_array(mods)
	for k in all.size():
		all[k].global_position.x = k * 200.0
		_seat(all[k], func(_ac, i: PilotIntent, _dt): i.throttle = 1.0; i.gear_down = false)
	var wing_l := -1
	var htail := []
	for k in ref.data.surfaces.size():
		var n := ref.data.surfaces[k].name
		if n.begins_with("wing_L"):
			mods[0].flight.modifiers.lift[k] = 0.3
			wing_l = k
		if n.begins_with("htail"):
			htail.append(k)
	mods[1].flight.modifiers.engine_failed = true
	mods[2].flight.modifiers.engine_power_mul = 0.5
	for k in htail:
		mods[3].flight.modifiers.set_stuck(k, 1.0)   # Höhenruder klemmt voll gezogen
	await _step(120)
	var neutral: bool = ref.flight.modifiers.is_neutral() and ref.damage.modifiers == ref.flight.modifiers
	var roll_l: float = mods[0].angular_velocity.dot(-mods[0].global_basis.z)  # + = rollt rechts
	var ok_wing: bool = wing_l >= 0 and roll_l < -0.2  # linker Flügel ohne Auftrieb -> rollt nach links
	var ok_eng: bool = mods[1].telemetry().thrust < 1.0
	var ok_pow: bool = mods[2].telemetry().thrust < ref.telemetry().thrust * 0.8
	var ok_stuck: bool = mods[3].telemetry().commands.elevator < 0.5 \
		and mods[3].global_basis.z.y < ref.global_basis.z.y - 0.2   # Nase deutlich höher
	var ok: bool = neutral and ok_wing and ok_eng and ok_pow and ok_stuck
	return [ok, "neutral=%s Flügel-Rollrate %.2f, Motor aus %.0f N, 50 %% Leistung %.0f/%.0f N, Ruder klemmt=%s" % [
		neutral, roll_l, mods[1].telemetry().thrust, mods[2].telemetry().thrust, ref.telemetry().thrust, ok_stuck]]


func test_aircraft_combat_hooks() -> Array:
	var a := _spawn(false, 800.0, 80.0, 0.8)
	var ejects := []
	a.eject_requested.connect(func(ac, allowed): ejects.append(allowed))
	var fired := []
	a.weapons.trigger_changed.connect(func(g, p): fired.append([g, p]))
	var c := _seat(a, func(_ac, i: PilotIntent, _dt): i.throttle = 0.8)
	c.intent.fire_primary = true
	c.intent.eject = true
	await _step(5)
	c.intent.fire_primary = false
	await _step(2)
	var ok := a.weapons != null and a.damage != null and ejects == [false] \
		and fired == [[WeaponSystem.Group.PRIMARY, true], [WeaponSystem.Group.PRIMARY, false]]
	a.damage.apply_hit(DamageModel.Zone.ENGINE, 30.0, null)
	ok = ok and is_equal_approx(a.damage.hp_fraction(DamageModel.Zone.ENGINE), 0.75)
	a.place(a.global_transform, 80.0, 0.8)
	ok = ok and is_equal_approx(a.damage.hp_fraction(DamageModel.Zone.ENGINE), 1.0) \
		and ProjectileSystem.current == projectiles
	return [ok, "WeaponSystem/DamageModel verdrahtet, Eject-Flanke gesperrt=%s, Abzug %s" % [ejects, fired]]


## Keine Taste / kein Knopf / keine Achsrichtung gehört zwei Aktionen – je Eingabe-Kontext
## (M3: FLIGHT, CREW, DRIVE, jeweils inkl. GLOBAL). Hier geprüft: Kontext FLIGHT = M2-Belegung.
func test_binding_conflicts() -> Array:
	InputBindings.setup()
	var seen := {}
	var dup := []
	for ctx in InputBindings.Context.values():
		var r := binding_map(ctx)
		dup.append_array(r[1])
		if ctx == InputBindings.Context.FLIGHT:
			seen = r[0]
	var has := func(act: String, ev_key: String) -> bool: return seen.get(ev_key, &"") == StringName(act)
	var ok: bool = dup.is_empty() \
		and has.call("fire_primary", "axis:%d:1" % JOY_AXIS_TRIGGER_RIGHT) \
		and has.call("fire_secondary", "axis:%d:1" % JOY_AXIS_TRIGGER_LEFT) \
		and has.call("kb_yaw_left", "btn:%d" % JOY_BUTTON_LEFT_SHOULDER) \
		and has.call("kb_yaw_right", "btn:%d" % JOY_BUTTON_RIGHT_SHOULDER) \
		and has.call("throttle_up", "btn:%d" % JOY_BUTTON_DPAD_UP) \
		and has.call("throttle_down", "btn:%d" % JOY_BUTTON_DPAD_DOWN) \
		and has.call("gear_toggle", "btn:%d" % JOY_BUTTON_DPAD_RIGHT) \
		and has.call("eject_hold", "btn:%d" % JOY_BUTTON_DPAD_LEFT) \
		and has.call("fire_primary", "key:%d" % KEY_SPACE) \
		and has.call("eject_hold", "key:%d" % KEY_J) \
		and not seen.has("mouse:%d" % MOUSE_BUTTON_LEFT)
	return [ok, "%d Belegungen (Flug), Konflikte: %s" % [seen.size(), dup if not dup.is_empty() else "keine"]]


## Belegung eines Kontexts: [ereignis -> aktion, Konflikte].
static func binding_map(ctx: int) -> Array:
	var seen := {}
	var dup := []
	for act in InputBindings.actions_for(ctx):
		if not InputMap.has_action(act):
			continue
		for ev in InputMap.action_get_events(act):
			var key := ""
			if ev is InputEventKey:
				key = "key:%d" % ev.physical_keycode
			elif ev is InputEventJoypadButton:
				key = "btn:%d" % ev.button_index
			elif ev is InputEventJoypadMotion:
				key = "axis:%d:%d" % [ev.axis, signi(int(ev.axis_value))]
			elif ev is InputEventMouseButton:
				key = "mouse:%d" % ev.button_index
			if seen.has(key) and seen[key] != act:
				dup.append("%s:%s=%s/%s" % [InputBindings.CONTEXT_NAMES[ctx], key, seen[key], act])
			seen[key] = act
	return [seen, dup]


## PlayerController: Feuer über Aktion, Notausstieg erst nach 1 s Halten, Seitenruder über LB/RB-Aktion.
func test_player_fire_eject_hold() -> Array:
	var a := _spawn(false, 800.0, 80.0, 0.8)
	var pc := PlayerController.new()
	pc.mouse_aim_enabled = false
	a.add_child(pc)
	a.pilot_seat.possess(pc)
	var ejects := []
	a.eject_requested.connect(func(_ac, allowed): ejects.append(allowed))
	Input.action_press("fire_primary")
	Input.action_press("eject_hold")
	Input.action_press("kb_yaw_right")
	await _step(30)
	var fire_on := a.pilot_seat.intent.fire_primary
	var eject_early := a.pilot_seat.intent.eject or not ejects.is_empty()
	var yaw := a.pilot_seat.intent.yaw
	await _step(40)
	var eject_late := a.pilot_seat.intent.eject and ejects == [false]
	Input.action_release("fire_primary")
	Input.action_release("eject_hold")
	Input.action_release("kb_yaw_right")
	await _step(3)
	var released := not a.pilot_seat.intent.fire_primary and not a.pilot_seat.intent.eject \
		and pc.eject_hold_progress == 0.0
	var ok := fire_on and not eject_early and eject_late and released and yaw > 0.9
	return [ok, "Feuer=%s, Ausstieg nach 0,5 s=%s / nach 1,2 s=%s (gesperrt), Seitenruder %.2f" % [
		fire_on, eject_early, eject_late, yaw]]


func test_main_scene_combat_nodes() -> Array:
	var ps: PackedScene = load("res://world/main.tscn")
	var n := ps.instantiate() as Game
	get_tree().root.add_child(n)
	await _step(10)
	var ok := n.projectiles != null and ProjectileSystem.current == n.projectiles \
		and n.weapon_fx != null and not n.weapon_fx.enabled \
		and n.spawn_manager.entries.has(n.player_aircraft) \
		and n.hud.combat != null and n.hud.combat.get_parent() == n.hud \
		and Nations.is_hostile(n.player_aircraft.nation_id, n.ai_aircraft.nation_id)
	n.queue_free()
	await _step(2)
	return [ok, "Hauptszene: ProjectileSystem, WeaponFx (headless aus), SpawnManager, CombatHud, Blau gegen Rot"]
