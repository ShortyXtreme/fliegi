extends SceneTree
## M3.3-Screenshots: Hauptmenü mit Flugplatz-Kulisse, Einstellungen mit Lautstärkereglern.
## xvfb-run -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1600x900 --script res://tools/screenshot_m3_3.gd -- <out_dir>

var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	_run.call_deferred()


func _run() -> void:
	var m: MainMenu = load("res://ui/menu/main_menu.tscn").instantiate()
	root.add_child(m)
	for i in 150:
		await process_frame
	await _shot("m3_3_hauptmenue")
	m.menu.show_page("settings")
	for i in 6:
		m.menu.list.nav("down")
	for i in 20:
		await process_frame
	await _shot("m3_3_einstellungen_lautstaerke")
	quit(0)


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(1440, 810, Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join(n + ".png"))
