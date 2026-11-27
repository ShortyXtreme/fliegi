extends SceneTree
## M3.8-Screenshots: Fluss aus der Luft, Wasser aus der Nähe, Brücke, Windsack.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1280x720 --script res://tools/screenshot_m3_8.gd -- <out_dir> <modus> [wind]
## Modus: fluss_luft, fluss_nah, bruecke, bruecke2, bach, windsack. wind: aus/schwach/normal/stark (Standard normal).

var out_dir := "user://"
var mode := "fluss_luft"
var wind := "normal"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		mode = args[1]
	if args.size() > 2:
		wind = args[2]
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
	Game.wind_override = wind
	var game: Game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	for i in 60:
		await physics_frame
	game.hud.visible = false
	var tw: TerrainWorld = null
	for n in game.find_children("*", "TerrainWorld", true, false):
		tw = n
	var o := tw.origin()
	var c := Camera3D.new()
	c.fov = 55.0
	c.far = 20000.0
	game.add_child(c)
	c.make_current()
	var from: Vector3
	var at: Vector3
	var net := tw.water_net
	var main: Dictionary = net.courses[0]
	var pts: PackedVector2Array = main.pts
	var bridges := tw.bridges
	match mode:
		"fluss_luft":
			# Hauptfluss-Schleife mit Bachmündung, 650 m über dem Tal
			var k := _nearest(pts, Vector2(-8000, -6500))
			var p := pts[k]
			var t := (pts[k + 10] - pts[k - 10]).normalized()
			var side := Vector2(-t.y, t.x)
			var cam := p - t * 1600.0 + side * 900.0
			from = Vector3(cam.x, tw.height_at_terrain(cam.x, cam.y) + 650.0, cam.y) + o
			at = Vector3(p.x + t.x * 400.0, float(main.level[k]), p.y + t.y * 400.0) + o
		"fluss_nah":
			var k := _nearest(pts, Vector2(-2500, -2600))
			var p := pts[k]
			var t := (pts[k + 4] - pts[k - 4]).normalized()
			var side := Vector2(-t.y, t.x)
			var cam := p + side * (float(main.hw[k]) + 6.0)
			var ground := tw.height_at_terrain(cam.x, cam.y)
			from = Vector3(cam.x, ground + 2.2, cam.y) + o
			var tgt := p + t * 110.0 - side * 12.0
			at = Vector3(tgt.x, float(main.level[k]) - 1.0, tgt.y) + o
		"bach":
			var sc: Dictionary = net.courses[1]
			var sp: PackedVector2Array = sc.pts
			var k := sp.size() / 2
			var p := sp[k]
			var t := (sp[k + 3] - sp[k - 3]).normalized()
			var side := Vector2(-t.y, t.x)
			var cam := p - t * 60.0 + side * 25.0
			from = Vector3(cam.x, tw.height_at_terrain(cam.x, cam.y) + 9.0, cam.y) + o
			at = Vector3(p.x + t.x * 40.0, float(sc.level[k]), p.y + t.y * 40.0) + o
		"bruecke", "bruecke2":
			var b: Node3D = bridges[0 if mode == "bruecke" else 1]
			var bx := b.global_transform.basis.x
			var bz := b.global_transform.basis.z
			from = b.global_position - bz * 150.0 + bx * 95.0 + Vector3(0, 22.0, 0)
			at = b.global_position + Vector3(0, 3.0, 0)
		"windsack":
			var ws: Node3D = game.find_children("Windsack*", "Node3D", true, false)[0]
			var w := Weather.wind_at(ws.global_position + Vector3(0, 7, 0))
			var side := Vector3(-w.z, 0, w.x).normalized() if w.length() > 0.1 else Vector3.RIGHT
			from = ws.global_position + side * 11.0 + Vector3(0, 4.5, 0) - w.normalized() * 3.0
			at = ws.global_position + Vector3(0, 6.0, 0) + w.normalized() * 1.5
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
	for i in 30:
		await process_frame
	print("Wind: ", Weather.describe())
	await _shot("m3_8_" + {"fluss_luft": "fluss_luft", "fluss_nah": "fluss_nah", "bruecke": "bruecke",
		"bruecke2": "bruecke_stein", "bach": "bach", "windsack": "windsack"}[mode])
	quit(0)


func _nearest(pts: PackedVector2Array, p: Vector2) -> int:
	var best := 10
	for i in range(10, pts.size() - 10):
		if pts[i].distance_to(p) < pts[best].distance_to(p):
			best = i
	return best
