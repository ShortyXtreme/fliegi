extends SceneTree
## Feedback-Taste: Bildschirmfoto vom offenen Eingabefeld (docs/screens_m3/feedback_taste.png).
## xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1600x900 --script res://tools/screenshot_feedback.gd -- <ausgabe.png>
## Die erzeugten Feedback-Ordner landen in user://feedback_screenshot und werden gelöscht.

var out := "user://feedback_taste.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _run() -> void:
	InputBindings.setup()
	Feedback.base_dir_override = ProjectSettings.globalize_path("user://feedback_screenshot")
	var game: Game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	for i in 90:
		await physics_frame
	var fb := Feedback.instance
	fb.trigger()
	for i in 4:
		await process_frame
	fb.text = "Tankwagen bleibt am Hangar hängen"
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(out)
	print("Screenshot ", out)
	fb.finish(true)
	fb.wait_png()
	print("Feedback-Ordner ", fb.last_dir, " Dateien ", fb.last_files)
	quit(0)
