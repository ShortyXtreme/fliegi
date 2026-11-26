extends SceneTree
## M3.6-Screenshot: Piste mit Bodendetail (Reifenabrieb, Grasflecken, Wimpel, Ölflecken, Windsack).
## xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1280x720 --script res://tools/screenshot_m3_6_piste.gd -- <out_dir> [piste|vorfeld]

var out_dir := "user://"
var name_ := "piste"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		name_ = args[1]
	_run.call_deferred()


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if img.get_width() > 1600:
		img.resize(1600, int(1600.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join(n + ".png"))
	print("Screenshot ", out_dir.path_join(n + ".png"))


func _run() -> void:
	var game: Game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	for i in 90:
		await physics_frame
	game.hud.visible = false
	# Platz des Spielers (nächster Airfield-Knoten)
	var pa := game.player_aircraft.global_position
	var af: Node3D = null
	for n in game.find_children("Airfield*", "Node3D", true, false):
		if af == null or (n as Node3D).global_position.distance_to(pa) < af.global_position.distance_to(pa):
			af = n
	var tw: TerrainWorld = null
	for n in game.find_children("*", "TerrainWorld", true, false):
		tw = n
	var l: AirfieldLayout = tw.airfield_layout(int(String(af.name).trim_prefix("Airfield")))
	var s0 := l.runway_start.z
	var c := Camera3D.new()
	c.fov = 55.0
	c.far = 9000.0
	game.add_child(c)
	c.make_current()
	var from := Vector3(-7, 3.5, s0 - 25) if name_ == "piste" else l.parking_positions[1] + Vector3(-9, 5, 9)
	var at := Vector3(4, 0, s0 - 130) if name_ == "piste" else l.parking_positions[1] + Vector3(0, 0, -2)
	for i in 40:
		c.global_position = af.to_global(from)
		c.look_at(af.to_global(at), Vector3.UP)
		await process_frame
	await _shot("m3_6_" + name_)
	quit(0)
