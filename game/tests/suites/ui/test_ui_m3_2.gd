extends TestSuite
## M3.2 UI: Epochen-Theme, Tastensymbole aus der Belegung, Tasten-Leiste je Kontext,
## Hilfe-Tafel, Waffen-Panel im Ruhezustand aus, im Kampf bzw. nach Änderung ein.


func test_theme_palette_loaded() -> Array:
	var p := HudStyle.palette
	var ok := p != null and p.theme != null and HudStyle.VALUE == p.value and HudStyle.theme() == p.theme
	return [ok, "Palette: %s" % (p.epoch_name if p else "keine")]


func test_glyph_tokens_from_bindings() -> Array:
	InputBindings.setup()
	var t := [KeyGlyphs.token(&"crew_wheel", false), KeyGlyphs.token(&"crew_wheel", true),
		KeyGlyphs.token(&"fire_primary", false), KeyGlyphs.token(&"fire_primary", true),
		KeyGlyphs.token(&"eject_hold", true), KeyGlyphs.token(&"throttle_up", false)]
	var ok: bool = t == ["Tab", "LB", "Leertaste", "RT", "Kreuz ←", "Shift"]
	var groups := KeyGlyphs.parse("Shift / Strg")
	ok = ok and groups.size() == 2 and KeyGlyphs.parse("Kreuz ↑ ↓")[0] == ["Kreuz ↑ ↓"]
	return [ok, "Symbole %s" % str(t)]


func test_key_bar_entries_per_context() -> Array:
	var C := InputBindings.Context
	var acts := func(st: Dictionary) -> Array:
		return KeyBar.entries_for(st).map(func(e): return e[0])
	var near: Array = acts.call({"ctx": C.CREW, "near_aircraft": true})
	var away: Array = acts.call({"ctx": C.CREW, "near_aircraft": false})
	var wheel: Array = acts.call({"ctx": C.CREW, "wheel_open": true})
	var park: Array = acts.call({"ctx": C.FLIGHT, "on_ground": true, "parking_brake": true, "speed_kmh": 0.0})
	var fight: Array = acts.call({"ctx": C.FLIGHT, "combat": true, "agl": 800.0, "eject_possible": true})
	var ok: bool = near.has(&"crew_enter") and not away.has(&"crew_enter") and away.has(&"crew_sprint") \
		and wheel.has(&"crew_wheel") and park.has(&"throttle_up") and park.has(&"eject_hold") \
		and fight.has(&"fire_primary") and fight.has(&"eject_hold")
	for l in [near, away, park, fight]:
		ok = ok and l.size() <= 6 and l.has(&"help_toggle")
	return [ok, "nah %s · weg %s · Kampf %s" % [str(near), str(away), str(fight)]]


func test_help_board_groups() -> Array:
	var ok := true
	var n := []
	for ctx in [InputBindings.Context.FLIGHT, InputBindings.Context.CREW, InputBindings.Context.DRIVE]:
		var gs := GroundHelp.groups(ctx)
		n.append(gs.size())
		ok = ok and gs.size() >= 3 and not GroundHelp.tips(ctx).is_empty()
	var titles := GroundHelp.groups(InputBindings.Context.FLIGHT).map(func(g): return g[0])
	ok = ok and titles.has("Fliegen") and titles.has("Kämpfen") and titles.has("Kamera")
	return [ok, "Gruppen je Kontext %s" % str(n)]


func test_weapon_panel_rest_and_combat() -> Array:
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	await _step(30)
	var pa := g.player_aircraft
	var b := Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
	var p0 := pa.global_position + Vector3(0, 900, 0)
	pa.place(Transform3D(b, p0), 90.0, 0.8, false)
	g.player.reset_state(0.8, false)
	g.player.parking_brake = false
	# Rote Maschinen weit weg: Ruhezustand
	for e in g.ai_aircrafts:
		e.place(Transform3D(b, p0 + Vector3(9000, 0, 9000)), 80.0, 0.8, false)
	await _step(90)
	var ch := g.hud.combat
	var rest := ch.weapon_panel.visible
	var bar := g.hud.ground_hud.key_bar.entries.map(func(e): return e[0])
	# Treffer am eigenen Flugzeug: Panel blendet ein
	pa.damage.apply_hit(DamageModel.Zone.TAIL, 30.0, null)
	await _step(30)
	var after_hit := ch.weapon_panel.visible
	g.queue_free()
	await _step(2)
	var ok := not rest and after_hit and not bar.has(&"fire_primary") and bar.has(&"help_toggle")
	return [ok, "Ruhe sichtbar %s, nach Treffer %s, Leiste %s" % [rest, after_hit, str(bar)]]
