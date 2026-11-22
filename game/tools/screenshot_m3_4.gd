extends SceneTree
## M3.4-Screenshots: Einstellungen in mehreren Auflösungen (Layout-Prüfung).
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
