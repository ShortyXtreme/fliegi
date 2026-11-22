extends SceneTree
## M3.5-Screenshots (Agent B): „klappen“ = Munitionsklappe + Tankdeckel am Spielerflugzeug offen,
## „absturz“ = abstürzendes Flugzeug mit abgerissenem Flügel.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1280x720 --script res://tools/screenshot_m3_5.gd -- <out_dir> <name>

var out_dir := "user://"
var name_ := "klappen"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		name_ = args[1]
	_run.call_deferred()


func _run() -> void:
	var game: Game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	for i in 90:
		await physics_frame
	game.hud.visible = false
	if game.get("ground_hud") != null and game.ground_hud:
		game.ground_hud.visible = false
	if name_ == "absturz":
		await _absturz(game)
	else:
		await _klappen(game)
	quit(0)


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if img.get_width() > 1600:
		img.resize(1600, int(1600.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join(n + ".png"))


func _cam(game: Node, from: Vector3, at: Vector3, fov := 50.0) -> Camera3D:
	var c := Camera3D.new()
	c.fov = fov
	c.far = 9000.0
	game.add_child(c)
	c.global_position = from
	c.look_at(at, Vector3.UP)
	c.make_current()
	for i in 40:
		await process_frame
	return c


func _klappen(game: Game) -> void:
	var a := game.player_aircraft
	var xf := a.global_transform
	for k in ["gun_hatch_L", "gun_hatch_R", "fuel_cap"]:
		a.set_service_part_open(k, true)
	for i in 70:
		await process_frame
	# Spiel: links = -X, Nase -Z. Kamera links hinten oberhalb des Flügels.
	var target := xf * Vector3(-1.9, 0.0, 0.0)
	await _cam(game, xf * Vector3(-4.6, 2.4, 2.6), target, 45.0)
	await _shot("m3_5_klappen_offen")
	a.set_service_part_open("gun_hatch_L", false)
	a.set_service_part_open("gun_hatch_R", false)
	for i in 70:
		await process_frame
	await _cam(game, xf * Vector3(-3.2, 0.9, -0.2), xf * Vector3(-0.6, 0.0, -1.3), 40.0)
	await _shot("m3_5_tankstutzen")


func _absturz(game: Game) -> void:
	var a := game.player_aircraft
	var p := a.global_position + Vector3(0, 450, 0)
	a.place(Transform3D(Basis.looking_at(Vector3(1, 0, 0), Vector3.UP), p), 85.0, 0.8, false)
	for i in 30:
		await physics_frame
	a.damage.start_fire(DamageModel.Zone.FUEL_L)
	for i in 60:
		await physics_frame
	a.damage.apply_hit(DamageModel.Zone.WING_L, 1000.0, null)
	for i in 55:
		await physics_frame
	var c := Camera3D.new()
	c.fov = 50.0
	c.far = 9000.0
	game.add_child(c)
	c.make_current()
	var xf := a.global_transform
	c.global_position = xf.origin + Vector3(-14, 7, 22)
	c.look_at(xf.origin + Vector3(-6, 0, 0), Vector3.UP)
	await _shot("m3_5_absturz_fluegel_ab")
	# bis zum Aufschlag weiterfallen lassen, dann die Absturzstelle
	for i in 60 * 30:
		await physics_frame
		if a.damage.outcome != DamageModel.Outcome.FLYING:
			break
	for i in 70:
		await physics_frame
	var g := a.global_position
	c.global_position = g + Vector3(-45, 18, 40)
	c.look_at(g + Vector3(0, 6, 0), Vector3.UP)
	await _shot("m3_5_absturzstelle")
