extends TestSuite
## Kampf-HUD (Paket 9) und Flug-Panel: Smoke-Tests headless mit Fake-Daten.

var _hud: Hud


func after_each() -> void:
	CombatHud.replace_legacy_text = false
	if _hud and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


func _make_hud(a: Aircraft) -> Hud:
	_hud = Hud.new()
	_hud.aircraft = a
	world.add_child(_hud)
	return _hud


func test_flight_panel_data() -> Array:
	var a := _spawn(false, 900.0, 80.0, 0.7)
	await _step(5)
	var d := FlightPanel.gather(a, null, null, false)
	var ok: bool = absf(d.speed_kmh - 288.0) < 25.0 and absf(d.altitude - 900.0) < 5.0 \
		and d.fps == -1 and d.gear >= 0.99 and d.has("warnings")
	# Fahrwerk draußen bei 288 km/h ist erlaubt; Warnliste ohne Überdrehzahl
	var dbg := FlightPanel.gather(a, null, null, true)
	return [ok and dbg.fps >= 0, "Fahrt %.0f km/h, Höhe %.0f m, Warnungen %s" % [d.speed_kmh,
		d.altitude, str(d.warnings)]]


func test_flight_panel_warnings() -> Array:
	var a := _spawn(false, 900.0, 110.0, 0.7)
	await _step(3)
	var d := FlightPanel.gather(a, null, null)
	var texts := []
	for w in d.warnings:
		texts.append(w[0])
	var over := texts.any(func(s): return String(s).begins_with("FAHRWERK ZU SCHNELL"))
	return [over, "Warnungen bei 396 km/h mit Fahrwerk: %s" % str(texts)]


func test_hud_contains_panel_and_hides_legacy() -> Array:
	var a := _spawn(false, 900.0, 80.0, 0.7)
	var h := _make_hud(a)
	await _step(2)
	var ok1: bool = h.combat != null and h.combat.flight_panel != null
	var info: Label = h.get("_info")
	# Paket 14: Hud schaltet das alte Text-HUD selbst ab (replace_legacy_text = true).
	return [ok1 and CombatHud.replace_legacy_text and not info.visible \
			and not h.combat.flight_panel.data.is_empty(),
		"Panel da: %s, altes Text-HUD sichtbar: %s" % [ok1, info.visible]]


func test_format_helpers() -> Array:
	var a := HudStyle.thousands(1250.0)
	var b := HudStyle.distance(846.0)
	var c := HudStyle.distance(1430.0)
	var ok := a == "1 250" and b == "850 m" and c == "1,4 km" and FlightPanel.dec(-2.26) == "-2,3"
	return [ok, "%s | %s | %s | %s" % [a, b, c, FlightPanel.dec(-2.26)]]


func _enemy_at(pos: Vector3) -> Aircraft:
	var e := Aircraft.create(load(FIGHTER), false)
	e.nation_id = Nations.RED
	world.add_child(e)
	e.place(Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), pos), 80.0, 0.7, false)
	return e


func test_contacts_spotting_modes() -> Array:
	var a := _spawn(false, 900.0, 80.0, 0.7)
	var near := _enemy_at(Vector3(0, 900, -2000))
	var far := _enemy_at(Vector3(0, 900, -4000))
	var friend := Aircraft.create(load(FIGHTER), false)
	world.add_child(friend)
	friend.place(Transform3D(Basis(), Vector3(200, 900, 0)), 80.0, 0.7, false)
	await _step(2)
	var arc := HudContacts.collect(a)
	var spotted_arc := arc.filter(func(c): return c.hostile and c.spotted).size()
	a.assist_mode = FlightAssist.Mode.REALISTIC
	var real := HudContacts.collect(a)
	var spotted_real := real.filter(func(c): return c.hostile and c.spotted).size()
	var friends := real.filter(func(c): return not c.hostile).size()
	var aids_off := not HudContacts.lead_allowed(a) and not HudContacts.radar_allowed(a)
	a.assist_mode = FlightAssist.Mode.ARCADE
	MatchRules.spot_mode = MatchRules.SpotMode.REALISTIC
	var lobby_real := HudContacts.collect(a).filter(func(c): return c.hostile and c.spotted).size()
	var ok: bool = arc.size() == 3 and spotted_arc == 2 and spotted_real == 1 and friends == 1 \
		and aids_off and lobby_real == 1
	near.free(); far.free(); friend.free()
	return [ok, "Arcade erkannt %d/2, Realistisch %d/1, Lobby-Realistisch %d/1, Hilfen aus %s" % [
		spotted_arc, spotted_real, lobby_real, aids_off]]


func test_lead_target_and_point() -> Array:
	var a := _spawn(false, 900.0, 90.0, 0.8)
	var e := _enemy_at(Vector3(40, 905, -350))
	e.linear_velocity = Vector3(-60, 0, -60)
	await _step(1)
	var cs := HudContacts.collect(a)
	var t := HudContacts.lead_target(a, cs)
	var lp := HudContacts.lead_point(a, t)
	var ok: bool = not t.is_empty() and t.node == e and not lp.is_empty()
	var ahead := false
	if ok:
		# Vorhalt liegt in Flugrichtung des Ziels (−x) vor dem Ziel
		var to_t: Vector3 = (t.pos - a.global_position).normalized()
		ahead = (lp.dir as Vector3).x < to_t.x
	e.free()
	return [ok and ahead, "Ziel gefunden %s, Vorhalt vor dem Ziel %s, Flugzeit %.2f s" % [ok, ahead,
		lp.get("time", -1.0)]]


func test_kill_feed_limit_and_expiry() -> Array:
	var f := KillFeed.new()
	var a := _spawn(false, 900.0, 80.0, 0.7)
	for i in 7:
		f.add_kill(a, null, CombatEvents.Cause.CRASH, null)
	var n1 := f.entries.size()
	f.tick(3.0)
	f.add_text(a, "ausgestiegen", a)
	f.tick(3.5)
	var n2 := f.entries.size()
	var txt: String = f.entries[0].left if n2 > 0 else ""
	f.free()
	return [n1 == 5 and n2 == 1 and txt == "Du", "max %d, nach 6,5 s %d (%s)" % [n1, n2, txt]]


func test_radar_and_heading() -> Array:
	var xf := Transform3D(Basis.looking_at(Vector3(1, 0, 0), Vector3.UP), Vector3.ZERO)  # Kurs Ost
	var cs := [{"pos": Vector3(1500, 0, 0), "hostile": true}, {"pos": Vector3(0, 300, 1500), "hostile": false},
		{"pos": Vector3(5000, 0, 0), "hostile": true}]
	var b := RadarLight.project(xf, cs, 3000.0)
	var hd := HudContacts.heading_of(Vector3(1, 0, 0))
	var ok: bool = b.size() == 2 and absf(b[0].y + 0.5) < 0.01 and absf(b[0].x) < 0.01 \
		and absf(b[1].x - 0.5) < 0.01 and absf(hd - 90.0) < 0.01
	return [ok, "Blips %s, Kurs Ost %.0f°" % [str(b), hd]]


func test_events_hit_kill_eject() -> Array:
	var a := _spawn(false, 900.0, 80.0, 0.7)
	var e := _enemy_at(Vector3(0, 900, -600))
	var h := _make_hud(a)
	await _step(2)
	var bus := CombatEvents.bus()
	bus.hit_confirmed.emit(e, a, 0, 10.0)        # fremder Treffer: keine Anzeige
	var other := h.combat.overlay.hit_t
	bus.hit_confirmed.emit(a, e, 0, 10.0)
	var hit := h.combat.overlay.hit_t
	bus.aircraft_destroyed.emit(e, a, CombatEvents.Cause.WING_BROKEN)
	var kill := h.combat.overlay.kill_t
	a.eject_requested.emit(a, false)
	var locked := h.combat.overlay.eject_locked_t
	var feed: Array = h.combat.kill_feed.entries
	var ok: bool = other == 0.0 and hit > 0.0 and kill > 0.0 and locked > 0.0 and feed.size() == 1 \
		and feed[0].left == "Du"
	e.free()
	return [ok, "Treffer %.2f, Abschuss %.2f, gesperrt %.1f, Feed %d" % [hit, kill, locked, feed.size()]]


func test_weapon_panel_data() -> Array:
	var a := _spawn(false, 900.0, 80.0, 0.7)
	a.damage.apply_hit(DamageModel.Zone.WING_L, 100.0, null)
	var d := WeaponPanel.gather(a)
	var g: Dictionary = d.groups[0] if d.groups.size() > 0 else {}
	var ok: bool = g.get("ammo", 0) > 0 and g.ammo == g.max and d.zones.size() == DamageModel.Zone.COUNT \
		and absf(d.zones[DamageModel.Zone.WING_L] - 0.5) < 0.01
	return [ok, "Gruppen %d, Munition %s/%s, Flügel L %.2f" % [d.groups.size(), g.get("ammo"),
		g.get("max"), d.zones[DamageModel.Zone.WING_L]]]
