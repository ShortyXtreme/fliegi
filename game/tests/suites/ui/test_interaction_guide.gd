extends TestSuite
## M3.5: 3D-Interaktionshilfen (InteractionGuide): Positionen aus den svc_*-Markern (auch nach
## geänderter Markerlage), Automatik je Lage, Einstellung aus, Tutorial-Markierungen.


func test_marks_follow_markers() -> Array:
	var a := _spawn(true)
	var m := InteractionGuide.at_aircraft(a, ServiceMarkers.SVC_FUEL_CAP, "Tankstutzen")
	var p0: Vector3 = InteractionGuide.resolve(m)
	var want0 := a.global_transform * ServiceMarkers.aircraft_point(a, ServiceMarkers.SVC_FUEL_CAP)
	# Neue Markerlage (z. B. Tankstutzen seitlich am Rumpf): Markierung zieht mit
	var pts: Dictionary = a.damage.hitboxes.markers.points
	var old: Vector3 = pts.get(ServiceMarkers.SVC_FUEL_CAP, Vector3.ZERO)
	pts[ServiceMarkers.SVC_FUEL_CAP] = Vector3(-0.6, 0.2, -1.0)
	var p1: Vector3 = InteractionGuide.resolve(m)
	pts[ServiceMarkers.SVC_FUEL_CAP] = old
	var ok := p0.distance_to(want0) < 0.01 and p1.distance_to(a.global_transform * Vector3(-0.6, 0.2, -1.0)) < 0.01
	return [ok, "vorher %s, nach Markerwechsel %s" % [p0, p1]]


func test_auto_marks_and_setting() -> Array:
	var a := _spawn(true)
	var board := JobBoard.new()
	board.rules = GroundRules.for_realism(MatchRules.GroundRealism.STANDARD)
	world.add_child(board)
	a.damage.fuel.set_fraction(0.2)
	a.weapons.set_ammo_fraction(0.0)
	board.plan_service(a, FuelDepot.new(), AmmoBunker.new(), {})
	var truck := FuelTruck.create(2000.0)
	world.add_child(truck)
	truck.place(a.global_position + a.global_transform.basis.x * 8.0, 0.0)
	var cart := AmmoCart.new()
	world.add_child(cart)
	cart.place(a.global_position + a.global_transform.basis.x * 8.0 + Vector3(0, 0, 10), 0.0)
	var ch := CrewCharacter.new()
	world.add_child(ch)
	ch.global_position = a.global_position + a.global_transform.basis.x * 4.0
	var g := InteractionGuide.new()
	g.character = ch
	g.aircraft = a
	g.board = board
	g.truck = truck
	g.cart = cart
	world.add_child(g)
	await _step(3)
	var free_hand: Array = g.marks.map(func(x): return x.text)
	var item := CarryItem.new()
	item.kind = CarryItem.HOSE
	ch.carried = item
	await _step(2)
	var with_hose: Array = g.marks.map(func(x): return x.text)
	item.kind = CarryItem.CRATE
	await _step(2)
	var with_crate: Array = g.marks.map(func(x): return x.text)
	ch.carried = null
	InteractionGuide.enabled = false
	await _step(2)
	var off := g.marks.size()
	InteractionGuide.enabled = true
	item.free()
	var ok: bool = free_hand.has("Schlauch hier nehmen") and free_hand.has("Kiste hier holen") \
		and with_hose == ["Tankstutzen"] and with_crate.has("MG-Klappe links") and with_crate.has("MG-Klappe rechts") \
		and off == 0 and g.get_child_count() > 0
	return [ok, "frei %s, Schlauch %s, Kiste %s, aus %d" % [free_hand, with_hose, with_crate, off]]


## Tutorial: Schritt Tanken zeigt Schlauch und Tankstutzen, Schritt Munition Kiste und MG-Klappe,
## Einsteigen den Einstieg; der Tankwagen steht neben der Maschine (Schlauch reicht).
func test_tutorial_marks() -> Array:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Tutorial.PROGRESS_PATH))
	Game.tutorial_mode = true
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	Game.tutorial_mode = false
	await _step(30)
	var tu := g.tutorial
	var pa := g.player_aircraft
	Input.action_press(&"eject_hold")
	await _step(75)
	Input.action_release(&"eject_hold")
	await _step(30)
	var fuel: Array = g.guide.marks.map(func(x): return x.text)
	var cap := pa.global_transform * ServiceMarkers.aircraft_point(pa, ServiceMarkers.SVC_FUEL_CAP)
	var reach: bool = g.blue_ops.truck.hose.global_position.distance_to(cap) < FuelHose.HOSE_LENGTH
	tu.skip_step()
	await _step(3)
	var ammo: Array = g.guide.marks.map(func(x): return x.text)
	tu.skip_step()
	await _step(3)
	var entry: Array = g.guide.marks.map(func(x): return x.text)
	tu.quit()
	await _step(2)
	var after_override := g.guide.override.is_valid()
	g.queue_free()
	await _step(2)
	var ok: bool = fuel == ["Schlauch hier nehmen", "Tankstutzen"] and reach and ammo.has("Kiste hier holen") \
		and ammo.has("MG-Klappe links") and entry == ["Einstieg"] and not after_override
	return [ok, "Tanken %s (Schlauch reicht %s), Munition %s, Einsteigen %s" % [fuel, reach, ammo, entry]]
