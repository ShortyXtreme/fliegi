extends SceneTree
## M2-Screenshots (Paket 14): Flugplatz Blau beim Start und Luftkampf mit Leuchtspur.
## Aufruf: xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/screenshot_m2.gd -- out_dir

var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name))
	print("gespeichert: ", out_dir.path_join(name))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var game: Game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	await _frames(60)
	game.hud._help.visible = false
	await _frames(5)
	await _shot("integration_flugplatz.png")
	# Luftkampf: Spieler 160 m hinter dem ersten Gegner, Feuer gedrückt
	var e: Aircraft = game.ai_aircrafts[0]
	var xf := e.global_transform
	var fwd := -xf.basis.z
	var p := xf.origin - fwd * 160.0 + Vector3.UP * 6.0 + xf.basis.x * 4.0
	game.player_aircraft.place(Transform3D(Basis.looking_at(fwd, Vector3.UP), p),
			e.linear_velocity.length(), 0.8, false)
	game.player.reset_state(0.8, false)
	await _frames(3)
	Input.action_press("fire_primary")
	await _frames(22)
	await _shot("integration_luftkampf.png")
	Input.action_release("fire_primary")
	quit(0)
