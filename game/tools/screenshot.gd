extends SceneTree
## Rendert die Hauptszene und speichert Screenshots (für Sichtprüfung ohne Monitor).
## Aufruf: xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/screenshot.gd -- out_dir

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


func _run() -> void:
	var game: Game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	for i in 30:
		await process_frame
	await _shot("m1_runway_chase.png")
	game.hud.toggle_help()
	# Spieler in die Luft setzen, KI sichtbar machen
	var b := Basis.looking_at(Vector3(0.3, 0, -1), Vector3.UP)
	game.player_aircraft.place(Transform3D(b, Vector3(0, 300, 300)), 90.0, 0.8)
	game.player.reset_state(0.8)
	for i in 90:
		await process_frame
	await _shot("m1_air_chase.png")
	game.cam.next_mode()
	for i in 10:
		await process_frame
	await _shot("m1_cockpit.png")
	game.cam.next_mode()
	game.hud.toggle_debug()
	for i in 20:
		await process_frame
	await _shot("m1_orbit_debug.png")
	quit(0)
