extends SceneTree
## M3.4-Screenshots: Einstellungen in mehreren Auflösungen (Layout-Prüfung); mit Name „platz“
## Flugplatz Blau aus der Luft und am Boden.
## xvfb-run -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1280x720 --script res://tools/screenshot_m3_4.gd -- <out_dir> <name>

var out_dir := "user://"
var name_ := "m3_4_einstellungen"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		name_ = args[1]
	_run.call_deferred()


func _run() -> void:
	if name_ == "platz":
		await _platz()
		quit(0)
		return
	var m: MainMenu = load("res://ui/menu/main_menu.tscn").instantiate()
	root.add_child(m)
	for i in 90:
		await process_frame
	m.menu.show_page("settings")
	for i in 9:
		m.menu.list.nav("down")
	for i in 20:
		await process_frame
	await _shot(name_)
	quit(0)


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if img.get_width() > 1600:
		img.resize(1600, int(1600.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join(n + ".png"))


func _cam(game: Node, from: Vector3, at: Vector3, fov := 50.0) -> void:
	var c := Camera3D.new()
	c.fov = fov
	c.far = 9000.0
	game.add_child(c)
	c.global_position = from
	c.look_at(at, Vector3.UP)
	c.make_current()
	for i in 40:
		await process_frame


func _platz() -> void:
	var game: Game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	for i in 90:
		await physics_frame
	game.hud.visible = false
	var l: AirfieldLayout = game.world.airfield_layout(0)
	var w := func(x: float, y: float, z: float) -> Vector3:
		var p := l.to_scene(Vector3(x, 0, z))
		return p + Vector3(0, y, 0)
	await _cam(game, w.call(420.0, 320.0, 1050.0), w.call(-20.0, 0.0, 250.0), 55.0)
	await _shot("m3_4_platz_luft")
	await _cam(game, w.call(-300.0, 650.0, -200.0), w.call(-20.0, 0.0, 0.0), 60.0)
	await _shot("m3_4_platz_luft_ganz")
	await _cam(game, w.call(-30.0, 2.2, 700.0), w.call(10.0, 0.0, 300.0), 60.0)
	await _shot("m3_4_platz_boden_schwelle")
	await _cam(game, w.call(25.0, 2.0, 420.0), w.call(-90.0, 3.0, 640.0), 60.0)
	await _shot("m3_4_platz_boden_flugleitung")
