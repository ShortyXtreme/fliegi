extends SceneTree
## M3-Screenshots (Paket 15): Figur neben dem Flugzeug am Abstellplatz mit Tankwagen,
## rote KI beim Start.
## Aufruf: xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/screenshot_m3.gd -- out_dir

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
	img.convert(Image.FORMAT_RGB8)
	var p := out_dir.path_join(name)
	if name.ends_with(".jpg"):
		img.save_jpg(p, 0.85)
	else:
		img.save_png(p)
	print("gespeichert: ", p)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var game: Game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	await _frames(60)
	game.hud._help.visible = false
	var pl := game.player_aircraft
	# Tankwagen neben die Maschine, dann aussteigen
	var ops: AirfieldOps = game.blue_ops
	var spot = ops.dispatch.vehicle_spot(pl, false)
	ops.truck.place(spot, pl.global_transform.basis.get_euler().y)
	Input.action_press("eject_hold")
	await _frames(75)
	Input.action_release("eject_hold")
	await _frames(10)
	var ch := game.crew
	# Figur seitlich vor die Maschine, Blick auf Flugzeug und Wagen
	var side := pl.global_transform.basis.x
	var fwd := -pl.global_transform.basis.z
	var p := pl.global_position + side * 4.0 + fwd * 5.0
	ch.global_position = Vector3(p.x, WorldGround.height_at(p.x, p.z), p.z)
	var to := pl.global_position - ch.global_position
	ch.heading = atan2(-to.x, -to.z) + 0.6
	game.session.crew.look_yaw = ch.heading
	game.session.crew.look_pitch = -0.25
	await _frames(40)
	await _shot("integration_figur_tankwagen.png")
	# Rote KI am Boden beim Start: Kamera auf die erste rote Maschine, die gerade losrollt/abhebt
	var e: Aircraft = game.ai_aircrafts[0]
	var br: AIPilotBrain = game.scenario.brains[0]
	if br.airfield != null:
		br.airfield.scramble_timeout = 0.0
	var t := 0
	while t < 60 * 120 and e.telemetry().height_agl < 8.0:
		await physics_frame
		t += 1
	game.session.apply_view(e.pilot_seat)   # Verfolgerkamera auf die KI-Maschine
	game.cam.target = e
	await _frames(30)
	await _shot("integration_ki_start.png")
	quit(0)
