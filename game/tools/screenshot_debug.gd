extends SceneTree
## M2.1-Screenshot: Treffer-Debug-Modus (F3) im Luftkampf.
## Aufruf: xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/screenshot_debug.gd -- datei.png

var out := "user://debug_treffer.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var game: Game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	await _frames(40)
	game.hud.toggle_help()
	game.hud.toggle_debug()
	game.hud.hit_overlay.show_tracers = true
	var e: Aircraft = game.ai_aircrafts[0]
	var e2: Aircraft = game.ai_aircrafts[1]
	var pl := game.player_aircraft
	# Gegner für das Bild geradeaus fliegen lassen
	var sc := ScriptedController.new()
	sc.intent.throttle = 0.7
	sc.intent.gear_down = false
	game.add_child(sc)
	e.pilot_seat.possess(sc)
	e.assist_mode = FlightAssist.Mode.ARCADE
	var fwd := -e.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	e.place(Transform3D(Basis.looking_at(fwd, Vector3.UP), e.global_position), 100.0, 0.7, false)
	var xf := e.global_transform
	var ps := ScriptedController.new()
	ps.intent.throttle = 0.7
	ps.intent.gear_down = false
	game.add_child(ps)
	pl.pilot_seat.possess(ps)
	var p := xf.origin - fwd * 120.0 - Vector3.UP * 1.5
	pl.place(Transform3D(Basis.looking_at(fwd, Vector3.UP), p), 100.0, 0.7, false)
	# Erhaltene Treffer (Rot 2 von hinten links) über den normalen Weg einspielen
	e2.place(Transform3D(Basis.looking_at(fwd, Vector3.UP), p - fwd * 260.0 - xf.basis.x * 120.0),
			100.0, 0.7, false)
	await _frames(3)
	ps.intent.fire_primary = true
	await _frames(20)
	for k in 3:
		await _frames(5)
		var z: int = [DamageModel.Zone.TAIL, DamageModel.Zone.WING_L, DamageModel.Zone.FUEL_L][k]
		pl.damage.apply_hit(z, 12.0, e2)
		game.hud.hit_debug.on_hit_resolved(e2, pl, z, 12.0, pl.global_position, Vector3.ZERO, 0)
	await _frames(8)
	var rel := e.global_position - pl.global_position
	print("Abstand %.0f m, Winkel %.1f°" % [rel.length(), rad_to_deg((-pl.global_basis.z).angle_to(rel))])
	await process_frame
	var img := root.get_texture().get_image()
	ps.intent.fire_primary = false
	img.save_png(out)
	print("gespeichert: ", out, "  eigene Treffer ", game.hud.hit_debug.mine(50).size())
	quit(0)
