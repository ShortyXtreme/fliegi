extends TestSuite
## M3 Paket 14: Hauptszene mit Bodenbetrieb. Start am Abstellplatz (MatchRules FIRST),
## Sitzwechsel Flug -> zu Fuß -> Fahren -> zu Fuß -> Flug über die echten Aktionen, Kamera/HUD-
## Kontext je Wechsel, KI startet am Boden, Bodenpersonal je Platz.


func _game() -> Game:
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	await _step(60)
	return g


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await _step(frames)
	Input.action_release(action)
	await _step(2)


func _cam_ok(g: Game, ctx: int) -> bool:
	var cur := get_viewport().get_camera_3d()
	if ctx == InputBindings.Context.FLIGHT:
		return cur != null and g.cam.is_ancestor_of(cur) or cur == g.cam.get_node_or_null("Camera3D")
	return cur == g.crew_camera.camera


func test_start_on_ground_state() -> Array:
	var g := await _game()
	var a := g.player_aircraft
	var t := a.telemetry()
	var fuel := a.damage.fuel.fraction()
	var ammo_full := a.weapons.ammo() == a.weapons.ammo_max()
	var lay: AirfieldLayout = g._player_layout()
	var near_spot := false
	for i in lay.parking_count():
		if a.global_position.distance_to(lay.parking_transform(i).origin) < 4.0:
			near_spot = true
	var ai_ground := g.ai_aircrafts.all(func(e): return e.telemetry().on_ground)
	var ops_ok := g.airfields.size() == 2 and g.airfields.values().all(func(o): return o.crews.size() == 2 \
		and o.truck != null and o.cart != null and o.dispatch.fuel_truck == o.truck)
	var hud_ok := g.hud.ground_hud != null and g.hud.ground_hud.session == g.session \
		and g.session.ground_hud == null and g.hud.ground_hud.dispatch == g.blue_ops.dispatch
	var ok := t.on_ground and near_spot and absf(fuel - 0.5) < 0.03 and ammo_full and ai_ground and ops_ok \
		and hud_ok and g.session.context == InputBindings.Context.FLIGHT and g.player.exit_on_ground
	g.queue_free()
	await _step(2)
	return [ok, "Boden %s, Abstellplatz %s, Treibstoff %.2f, Munition voll %s, KI am Boden %s, Plätze %s, HUD %s" % [
		t.on_ground, near_spot, fuel, ammo_full, ai_ground, ops_ok, hud_ok]]


func test_seat_switch_chain() -> Array:
	var g := await _game()
	var a := g.player_aircraft
	var log := []
	await _step(60)
	# 1) Aussteigen: J 1,2 s halten
	await _hold("eject_hold", 75)
	var c1 := g.session.context == InputBindings.Context.CREW and g.crew.visible and g.crew.in_seat == null
	var cam1 := _cam_ok(g, InputBindings.Context.CREW)
	log.append("aus %s/Kamera %s" % [c1, cam1])
	# 2) Zum Tankwagen gehen (versetzen) und F
	var truck: FuelTruck = g.blue_ops.truck
	g.crew.global_position = truck.driver_seat.entry_position()
	await _step(5)
	await _hold("crew_enter", 3)
	var c2 := g.session.context == InputBindings.Context.DRIVE and truck.driver_seat.controller == g.session.drive
	log.append("Wagen %s" % c2)
	# 3) Fahren: Gas 2 s, dann Handbremse halten 2 s: darf nicht rückwärts rollen
	Input.action_press("drive_throttle")
	await _step(120)
	Input.action_release("drive_throttle")
	Input.action_press("drive_handbrake")
	await _step(180)
	var sp := truck.speed
	Input.action_release("drive_handbrake")
	await _step(2)
	var c3 := sp > -0.05 and absf(sp) < 0.2
	log.append("Handbremse v=%.2f %s" % [sp, c3])
	# 4) Aussteigen aus dem Wagen
	await _hold("eject_hold", 75)
	var c4 := g.session.context == InputBindings.Context.CREW
	log.append("aus Wagen %s" % c4)
	# 5) Zurück zum Flugzeug und F
	g.crew.global_position = a.pilot_seat.entry_position()
	g.crew.look_yaw = 0.0
	await _step(5)
	await _hold("crew_enter", 3)
	var c5 := g.session.context == InputBindings.Context.FLIGHT and a.pilot_seat.controller == g.player \
		and not g.crew.visible
	var cam5 := _cam_ok(g, InputBindings.Context.FLIGHT)
	log.append("ein %s/Kamera %s" % [c5, cam5])
	g.queue_free()
	await _step(2)
	return [c1 and cam1 and c2 and c3 and c4 and c5 and cam5, ", ".join(log)]


func test_crew_model_and_points() -> Array:
	var g := await _game()
	var a := g.player_aircraft
	var pts := g.player_service.attach(a)
	var anim := Game._anim_count(g.crew)
	var meshes := AirfieldOps.mesh_count(g.crew.visual)
	var zones := a.damage.hitboxes.zones.size()
	var src: String = a.damage.hitboxes.markers.source
	var ok := pts.size() == 5 and anim >= 6 and meshes > 0 and zones == 9 and g.crew.anim_tree != null
	g.queue_free()
	await _step(2)
	return [ok, "Punkte %d, Animationen %d, Meshes %d, Hitbox-Zonen %d (%s)" % [pts.size(), anim, meshes, zones, src]]
