extends SceneTree
## Sichtprüfung HUD + Effekte mit Fake-Daten (kein Teil des Spiels).
## xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1920x1080 --script res://ui/combat/preview/hud_preview.gd -- <out_dir>

var out_dir := "user://"
var game: Game


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	_run.call_deferred()


func _shot(file: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("gespeichert: ", out_dir.path_join(file))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	CombatHud.replace_legacy_text = true
	game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	await _frames(5)
	game.hud.toggle_help()
	var b := Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
	game.player_aircraft.place(Transform3D(b, Vector3(0, 800, 0)), 95.0, 0.85, false)
	game.player.reset_state(0.85)
	game.player.parking_brake = false
	game.ai_aircraft.place(Transform3D(b, Vector3(25, 812, -330)), 88.0, 0.8, false)
	await _frames(40)
	await _shot("hud_flight.png")
	quit(0)
