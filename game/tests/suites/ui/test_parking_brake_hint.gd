extends TestSuite
## M2.1 Regression: „PARKBREMSE“ erschien in der Luft (367 km/h, 1.445 m, Gas 0).
## Hinweis nur am Boden im Stand; in der Luft löst die Parkbremse sich selbst.


func _warn_texts(g: Game) -> String:
	var d := FlightPanel.gather(g.player_aircraft, g.player, g.cam, false)
	var s := ""
	for w in d.get("warnings", []):
		s += String(w[0]) + "|"
	return s


func test_parking_brake_only_on_ground() -> Array:
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	await _step(30)
	var ground := _warn_texts(g).contains("PARKBREMSE")
	var pl := g.player_aircraft
	# Luft, Gas 0, Parkbremse gesetzt (wie Neustart mit Gas 0), Spieler steuert
	var p := pl.global_position + Vector3(0, 1400, 0)
	pl.place(Transform3D(Basis.looking_at(TestWorld.RUNWAY_DIR, Vector3.UP), p), 100.0, 0.0, false)
	g.player.reset_state(0.0, false)
	await _step(1)
	var hint_air := _warn_texts(g).contains("PARKBREMSE")
	await _step(10)
	var released := not g.player.parking_brake and pl.pilot_seat.intent.brakes < 0.01
	# Fremder Controller im Sitz (Screenshot-Fall): Flag bleibt, Hinweis trotzdem aus
	var sc := ScriptedController.new()
	g.add_child(sc)
	pl.pilot_seat.possess(sc)
	g.player.parking_brake = true
	await _step(2)
	var hint_foreign := _warn_texts(g).contains("PARKBREMSE")
	g.queue_free()
	await _step(2)
	return [ground and not hint_air and released and not hint_foreign,
		"Boden im Stand: Hinweis %s; Luft: Hinweis %s, nach 10 Ticks gelöst %s; fremder Sitz: Hinweis %s" % [
		ground, hint_air, released, hint_foreign]]
