extends SceneTree
## Screenshots des Geländes zur Sichtprüfung (Paket 12).
## Aufruf (aus game/): xvfb-run -s "-screen 0 1280x720x24" godot --rendering-driver opengl3
##   --path . --script res://world/terrain/terrain_screens.gd -- <ausgabeordner>

var _tw: TerrainWorld
var _cam: Camera3D
var _out := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	root.size = Vector2i(1280, 720)
	_tw = TerrainWorld.new()
	root.add_child(_tw)
	_cam = Camera3D.new()
	_cam.far = 30000.0
	_cam.fov = 70.0
	root.add_child(_cam)
	_shots.call_deferred()


func _shots() -> void:
	if OS.has_environment("LOD_ONLY"):
		var keep := int(OS.get_environment("LOD_ONLY"))
		for t in _tw.terrain_root.get_children():
			for l in 3:
				var mi := t.get_node_or_null("LOD%d" % l) as MeshInstance3D
				if mi:
					mi.visible = l == keep
					mi.visibility_range_begin = 0.0
					mi.visibility_range_end = 0.0
	var c: Vector3 = _tw.airfield(0).center
	var thr := _tw.runway_start(0)
	# Luftbild: ~800 m über Grund südlich vom Platz Blau, Blick nach Nordosten zum Talzug
	await _shot("luft", c + Vector3(-1500, 800, 3500), c + Vector3(4000, 0, -6000))
	# Vom Flugplatz: Augenhöhe Cockpit an der Schwelle, Blick die Piste entlang
	await _shot("flugplatz", thr + Vector3(-14, 2.5, 25), thr + Vector3(10, 30, -900))
	if OS.has_environment("TOPDOWN"):
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = 12000.0
		_cam.far = 40000.0
		await _shot("oben", c + Vector3(0, 6000, 0.01), c)
	quit(0)


func _shot(name: String, pos: Vector3, look: Vector3) -> void:
	_cam.global_position = pos
	_cam.look_at(look, Vector3.UP)
	for i in 12:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_jpg(_out.path_join("terrain_%s.jpg" % name), 0.88)
	print("Screenshot ", name)
