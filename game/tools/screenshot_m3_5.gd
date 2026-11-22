extends SceneTree
## M3.5-Screenshots: Befehlsrad (Ebene Mechaniker), Tutorial-Markierung, Schalterpanel, Warnlampen.
## xvfb-run -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1600x900 --script res://tools/screenshot_m3_5.gd -- <out_dir> [rad|markierung|schalter|lampen]

var out_dir := "user://"
var mode := "rad"
var game: Game


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		mode = args[1]
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if img.get_width() > 1600:
		img.resize(1600, int(1600.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join(n + ".png"))
	print("Screenshot ", out_dir.path_join(n + ".png"))


func _start(tutorial := false) -> void:
	CombatHud.replace_legacy_text = true
	game = load("res://world/main.tscn").instantiate()
	if tutorial:
		game.tutorial_mode = true
	root.add_child(game)
	await _frames(60)
	if game.hud._help.visible:
		game.hud.toggle_help()


## Aussteigen und die Figur neben den Tankdeckel stellen, Blick zur Maschine.
func _exit_near(marker: String, side_m := 2.4) -> void:
	var pa := game.player_aircraft
	Input.action_press("eject_hold")
	await _frames(75)
	Input.action_release("eject_hold")
	await _frames(10)
	var ch := game.crew
	var side := pa.global_transform.basis.x
	var pt := pa.service_point(marker)
	var p := pt - side * side_m + pa.global_transform.basis.z * 2.0
	ch.global_position = Vector3(p.x, WorldGround.height_at(p.x, p.z), p.z)
	var to := pt - ch.global_position
	ch.heading = atan2(-to.x, -to.z)
	game.session.crew.look_yaw = ch.heading
	game.session.crew.look_pitch = -0.15
	await _frames(90)


func _run() -> void:
	match mode:
		"rad":
			await _start()
			await _exit_near("svc_fuel_cap")
			var gh: GroundHud = game.hud.ground_hud
			gh.dispatch.call("command", GroundCrewBrain.Command.FUEL_ONLY, game.player_aircraft, gh.crew_list()[0])
			await _frames(240)
			gh.wheel_override = 1
			await _frames(3)
			gh.wheel.cycle_page(1)
			gh.wheel.feed_mouse(Vector2(70, -30))
			await _frames(3)
			await _shot("m3_5_befehlsrad")
	quit(0)
