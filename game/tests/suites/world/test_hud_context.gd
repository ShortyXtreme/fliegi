extends TestSuite
## M3.5 Regression: Nach jedem Sitzwechsel (Flug ↔ zu Fuß ↔ Fahren) zeigen HUD und Tasten-Leiste
## nur den passenden Kontext – keine Flug-Infos (Flug-Panel, Flugtasten) zu Fuß oder im Wagen,
## kein Boden-HUD im Flug. Auch mit Tutorial (Tasten des Schritts) und mit offenem Befehlsrad.

const FLIGHT_KEYS := [&"throttle_up", &"brakes", &"gear_toggle", &"fire_primary", &"zoom_hold", &"flaps_cycle",
	&"camera_next", &"engine_toggle", &"magneto_toggle", &"master_toggle"]
const CREW_KEYS := [&"crew_enter", &"crew_sprint", &"crew_wheel", &"crew_view_toggle", &"crew_interact", &"crew_drop"]


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await _step(frames)
	Input.action_release(action)
	await _step(2)


func _keys(g: Game) -> Array:
	return g.hud.ground_hud.key_bar.entries.map(func(e): return e[0])


## Liefert [ok, Beschreibung] für den erwarteten Kontext.
func _check(g: Game, ctx: int, tag: String) -> Array:
	var keys := _keys(g)
	var combat_on: bool = g.hud.combat.visible and g.hud.combat.is_visible_in_tree()
	var fp_on: bool = combat_on and g.hud.combat.flight_panel.visible
	var legacy: bool = g.hud._info.visible or g.hud._warn.visible or g.hud._warn2.visible
	var status_on: bool = g.hud.ground_hud.crew_panel.visible
	var ok := true
	var C := InputBindings.Context
	if ctx == C.FLIGHT:
		ok = fp_on and not keys.any(func(k): return k in CREW_KEYS) and not status_on and g.session.context == ctx
	else:
		ok = not fp_on and not legacy and not keys.any(func(k): return k in FLIGHT_KEYS and \
			not (ctx == C.DRIVE and k == &"camera_next")) and g.session.context == ctx \
			and not g.hud._help.visible
	return [ok, "%s: Flug-Panel %s, Alt-Text %s, Tasten %s" % [tag, fp_on, legacy, str(keys)]]


func _chain(tutorial: bool) -> Array:
	Game.tutorial_mode = tutorial
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	Game.tutorial_mode = false
	await _step(60)
	var C := InputBindings.Context
	var res := []
	res.append(_check(g, C.FLIGHT, "Start"))
	await _hold("eject_hold", 75)
	await _step(3)
	res.append(_check(g, C.CREW, "ausgestiegen"))
	# Funkgerät auf/zu
	g.hud.ground_hud.toggle_radio()
	await _step(3)
	g.hud.ground_hud.toggle_radio()
	await _step(3)
	res.append(_check(g, C.CREW, "nach Funk"))
	var truck: FuelTruck = g.blue_ops.truck
	g.crew.global_position = truck.driver_seat.entry_position()
	await _step(5)
	await _hold("crew_enter", 3)
	await _step(3)
	res.append(_check(g, C.DRIVE, "Wagen"))
	await _hold("eject_hold", 75)
	await _step(3)
	res.append(_check(g, C.CREW, "aus Wagen"))
	var a := g.player_aircraft
	g.crew.global_position = a.pilot_seat.entry_position()
	await _step(5)
	await _hold("crew_enter", 3)
	await _step(3)
	res.append(_check(g, C.FLIGHT, "eingestiegen"))
	await _hold("eject_hold", 75)
	await _step(3)
	res.append(_check(g, C.CREW, "wieder aus"))
	g.queue_free()
	await _step(2)
	var ok := res.all(func(r): return r[0])
	return [ok, " | ".join(res.filter(func(r): return not r[0]).map(func(r): return r[1])) if not ok else "alle %d Wechsel sauber" % res.size()]


func test_hud_context_switches() -> Array:
	return await _chain(false)


func test_hud_context_switches_tutorial() -> Array:
	return await _chain(true)
