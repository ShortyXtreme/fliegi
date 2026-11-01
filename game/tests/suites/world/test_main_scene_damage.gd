extends TestSuite
## M2.1 Regression (Tester: „kein Schaden erhalten, Schadensskizze unverändert“):
## In der echten Hauptszene (main.tscn, Gelände, 1 gegen 3) bekommt ein passiver Spieler
## Treffer der KI, und die Schadensskizze (WeaponPanel) zeigt sie – auch nach Neustart.
## Umgekehrt machen Spieler-Treffer an der KI Schaden.

const MAX_SIM := 120.0


func _game() -> Game:
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	await _step(2)
	return g


## Spieler 4 km vor Platz Blau Richtung Rot, 1300 m über Grund, geradeaus, Gas 80 %.
func _place_passive(g: Game) -> void:
	var sc := ScriptedController.new()
	sc.intent.throttle = 0.8
	g.add_child(sc)
	g.player_aircraft.pilot_seat.possess(sc)
	var b: Vector3 = g.scenario.field_center(g.scenario.blue_field)
	var dir: Vector3 = g.scenario.field_center(g.scenario.red_field) - b
	dir.y = 0.0
	dir = dir.normalized()
	var p := b + dir * 4000.0
	p.y = WorldGround.height_at(p.x, p.z) + 1300.0
	g.player_aircraft.place(Transform3D(Basis.looking_at(dir, Vector3.UP), p), 110.0, 0.8, false)


## Wartet, bis der Spieler Schaden hat und die Skizze ihn zeigt. Rückgabe [Sekunden, Treffer].
func _wait_hit(g: Game) -> Array:
	var hits := [0]
	var cb := func(_s, t, _z, d):
		if t == g.player_aircraft and d > 0.0:
			hits[0] += 1
	CombatEvents.bus().hit_confirmed.connect(cb)
	var f := 0
	while f < int(MAX_SIM * 60.0):
		await get_tree().physics_frame
		f += 1
		if hits[0] > 0 and f % 10 == 0:
			await get_tree().process_frame
			if _sketch_damaged(g):
				break
	CombatEvents.bus().hit_confirmed.disconnect(cb)
	return [f / 60.0, hits[0]]


func _sketch_damaged(g: Game) -> bool:
	var z: PackedFloat32Array = g.hud.combat.weapon_panel.data.get("zones", PackedFloat32Array())
	for v in z:
		if v < 0.999:
			return true
	return false


func test_passive_player_takes_ai_hits() -> Array:
	var g: Game = await _game()
	_place_passive(g)
	var r: Array = await _wait_hit(g)
	var dmg := 1.0 - g.player_aircraft.damage.health_fraction()
	var sk := _sketch_damaged(g)
	var col := WeaponPanel.zone_color(0.95) != HudStyle.OK
	g.queue_free()
	await _step(2)
	return [r[1] > 0 and sk and col, "Hauptszene: erster Schaden nach %.1f s, %d Treffer, Schaden %.0f %%, Skizze zeigt Schaden %s, 95 %%-Farbe ≠ heil %s" % [
		r[0], r[1], dmg * 100.0, sk, col]]


func test_player_hit_after_restart() -> Array:
	var g: Game = await _game()
	_place_passive(g)
	var pl := g.player_aircraft
	pl.damage.apply_hit(DamageModel.Zone.TAIL, 30.0, g.ai_aircrafts[0])
	await _step(3)
	await get_tree().process_frame
	var before := _sketch_damaged(g)
	g.spawn_manager.respawn_now(pl)   # Neustart wie nach Abschuss
	await _step(3)
	await get_tree().process_frame
	var clean := not _sketch_damaged(g) and pl.damage.health_fraction() > 0.999
	_place_passive(g)
	var r: Array = await _wait_hit(g)
	var sk := _sketch_damaged(g)
	var same := g.hud.aircraft == pl and ProjectileSystem.target_by_id(ProjectileSystem.id_of(pl)) != null
	g.queue_free()
	await _step(2)
	return [before and clean and r[1] > 0 and sk and same,
		"vor Neustart Skizze beschädigt %s, nach Neustart heil %s, danach Treffer nach %.1f s (%d), Skizze %s, Ziel registriert %s" % [
		before, clean, r[0], r[1], sk, same]]


func test_player_hits_damage_ai() -> Array:
	var g: Game = await _game()
	var pl := g.player_aircraft
	var e := g.ai_aircrafts[0]
	var fwd := -e.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	e.place(Transform3D(Basis.looking_at(fwd, Vector3.UP), e.global_position), 100.0, 0.7, false)
	var sc := ScriptedController.new()
	sc.intent.throttle = 0.7
	sc.intent.fire_primary = true
	g.add_child(sc)
	pl.pilot_seat.possess(sc)
	pl.place(Transform3D(Basis.looking_at(fwd, Vector3.UP), e.global_position - fwd * 180.0), 100.0, 0.7, false)
	var dealt := [0.0]
	var cb := func(a, _z, d, at):
		if a == e and at == pl:
			dealt[0] += d
	CombatEvents.bus().aircraft_damaged.connect(cb)
	await _step(60)
	CombatEvents.bus().aircraft_damaged.disconnect(cb)
	var hf := e.damage.health_fraction()
	g.queue_free()
	await _step(2)
	return [dealt[0] > 0.0 and hf < 1.0, "Spieler → KI aus 180 m, 1 s Feuer: %.0f HP Schaden, KI-Zustand %.0f %%" % [dealt[0], hf * 100.0]]
