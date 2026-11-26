extends SceneTree
## M3.7-Screenshots: Boden, Vegetation, Spuren auf der Wiese.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1280x720 --script res://tools/screenshot_m3_7.gd -- <out_dir> <modus> [stufe]
## Modus: boden (Flugplatz, Boden-Perspektive), spuren (Piste), luft (500 m über Land),
##        wald (Waldrand aus der Nähe). Stufe: Vegetation aus/niedrig/mittel/hoch (Standard mittel).

var out_dir := "user://"
var mode := "boden"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		mode = args[1]
	if args.size() > 2:
		Vegetation.override_level = Vegetation.LEVELS.find(args[2])
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
	for i in 60:
		await physics_frame
	game.hud.visible = false
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
	c.far = 20000.0
	game.add_child(c)
	c.make_current()
	var from: Vector3
	var at: Vector3
	match mode:
		"boden":
			from = af.to_global(Vector3(45, 1.7, s0 - 40))
			at = af.to_global(Vector3(-120, 5, s0 - 300))
		"spuren":
			from = af.to_global(Vector3(0, 2.4, s0 - 8))
			at = af.to_global(Vector3(0, 0, s0 - 150))
		"luft":
			var p := af.to_global(Vector3(2500, 0, -3500))
			from = Vector3(p.x, tw.height_at(p.x, p.z) + 500.0, p.z)
			at = af.to_global(Vector3(4500, 0, -7000))
			at.y = tw.height_at(at.x, at.z)
		"oben":   # Kontrolle: senkrecht von oben (1.200 m)
			var p := af.to_global(Vector3(3500, 0, -5000))
			from = Vector3(p.x, tw.height_at(p.x, p.z) + 1200.0, p.z)
			at = Vector3(p.x, 0, p.z - 1.0)
		"wald":
			var e := _forest_edge(tw, af.global_position)
			from = e[0]
			at = e[1]
	var veg: Vegetation = tw.vegetation
	c.global_position = from
	c.look_at(at, Vector3.UP)
	if veg:
		veg.warm_up()
	for i in 400:
		c.global_position = from
		c.look_at(at, Vector3.UP)
		await process_frame
		if i > 60 and (veg == null or veg.settled()):
			break
	if veg:
		print("Vegetation: Stufe %s, Zellen %d, Instanzen %d" % [Vegetation.LEVELS[Vegetation.level], veg.cell_count(), veg.instance_count()])
	for i in 10:
		await process_frame
	await _shot("m3_7_" + {"boden": "flugplatz_boden", "spuren": "wiese_spuren", "luft": "luft", "wald": "wald", "oben": "oben"}[mode])
	quit(0)


## Waldrand nahe dem Platz: Kamera 45 m vor dem Rand (offenes Land), Blick zum Wald.
func _forest_edge(tw: TerrainWorld, center: Vector3) -> Array:
	var mask := tw.data.decode_mask()
	var res := mask.get_width()
	var px := tw.data.size_m / res
	var o := tw.origin()
	var c := center - o
	for r in range(20, 200):
		for k in 48:
			var a := TAU * k / 48.0
			var p := Vector2(c.x, c.z) + Vector2(cos(a), sin(a)) * r * px
			var d := Vector2(cos(a), sin(a))
			# Sonne im Rücken (Licht fällt Richtung +x/−z)
			if d.dot(Vector2(0.574, -0.819)) < 0.6:
				continue
			var f := _m(mask, p, tw, res)
			var f2 := _m(mask, p - d * 3.0 * px, tw, res)
			if f > 0.85 and f2 < 0.1:
				var cam := p - d * 1.8 * px
				var from := Vector3(cam.x, 0, cam.y) + o
				from.y = tw.height_at(from.x, from.z) + 2.2
				var at := Vector3(p.x, 0, p.y) + o
				at.y = tw.height_at(at.x, at.z) + 8.0
				return [from, at]
	return [center + Vector3(0, 3, 0), center + Vector3(100, 0, 0)]


func _m(mask: Image, p: Vector2, tw: TerrainWorld, res: int) -> float:
	var i := clampi(int((p.x + tw.data.size_m * 0.5) / tw.data.size_m * res), 0, res - 1)
	var j := clampi(int((p.y + tw.data.size_m * 0.5) / tw.data.size_m * res), 0, res - 1)
	return mask.get_pixel(i, j).r
