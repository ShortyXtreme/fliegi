extends SceneTree
## M3.13-Screenshots: echte Texturen (Boden, Rinde, Holz) und HDRI-Himmel.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1280x720 --script res://tools/screenshot_m3_13.gd -- <out_dir> <modus> [stufe] [bedeckt]
## Modus: flugplatz, wiese_nah, wald, ufer, luft, halle, sonne (Kontrolle: Blick zur Sonne).
## Stufe: Texturqualität niedrig/mittel/hoch (Standard mittel). bedeckt: 0..1 (Standard Wetter = 0).

var out_dir := "user://"
var mode := "flugplatz"
var suffix := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		mode = args[1]
	if args.size() > 2:
		GroundTextures.set_level_name(args[2])
		if args[2] != "mittel":
			suffix = "_" + args[2]
	if args.size() > 3:
		TerrainWorld.overcast_override = float(args[3])
		suffix += "_bedeckt"
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
	Game.wind_override = "aus"
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
		"flugplatz":
			from = af.to_global(Vector3(45, 1.7, s0 - 40))
			at = af.to_global(Vector3(-120, 5, s0 - 300))
		"wiese_nah":
			# Rand der Graspiste: platt gefahrene Bahn (dirt_floor) im Gras, Blick schräg nach unten
			from = af.to_global(Vector3(14, 1.7, s0 - 20))
			at = af.to_global(Vector3(2, 0, s0 - 34))
		"luft":
			var p := af.to_global(Vector3(2500, 0, -3500))
			from = Vector3(p.x, tw.height_at(p.x, p.z) + 500.0, p.z)
			at = af.to_global(Vector3(4500, 0, -7000))
			at.y = tw.height_at(at.x, at.z)
		"wald":
			var e := _forest_inside(tw, af.global_position)
			from = e[0]
			at = e[1]
		"ufer":
			var e := _bank(tw)
			from = e[0]
			at = e[1]
		"halle":
			var h: Node3D = game.find_children("hangar", "Node3D", true, false)[0]
			var fwd := h.global_transform.basis.z
			var side := h.global_transform.basis.x
			from = h.global_position + fwd * 22.0 + side * 13.0 + Vector3(0, 2.0, 0)
			at = h.global_position + fwd * 6.0 + Vector3(0, 3.5, 0)
		"sonne":
			from = af.to_global(Vector3(0, 30, s0))
			at = from + tw.sun.global_transform.basis.z * 100.0
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
	print("Diagnose ", GroundTextures.diagnostics())
	print("Sonne ", tw.sun.rotation_degrees, " Bedeckung ", tw.overcast)
	await _shot("m3_13_" + mode + suffix)
	quit(0)


## Im Wald nahe dem Platz (im Baum-Radius): Kamera 2 m über dem Waldboden, Blick in den Wald, leicht abwärts.
func _forest_inside(tw: TerrainWorld, center: Vector3) -> Array:
	var mask := tw.data.decode_mask()
	var res := mask.get_width()
	var px := tw.data.size_m / res
	var o := tw.origin()
	var c := center - o
	for r in range(20, 200):
		for k in 48:
			var a := TAU * k / 48.0
			var d := Vector2(cos(a), sin(a))
			if d.dot(Vector2(0.574, -0.819)) < 0.5:
				continue
			var p := Vector2(c.x, c.z) + d * r * px
			if _m(mask, p, tw, res) > 0.9 and _m(mask, p + d * 2.0 * px, tw, res) > 0.9 \
					and _m(mask, p - d * 2.0 * px, tw, res) < 0.2:
				var cam := p + d * 0.6 * px
				var from := Vector3(cam.x, 0, cam.y) + o
				from.y = tw.height_at(from.x, from.z) + 2.0
				var tgt := cam + d * 25.0
				var at := Vector3(tgt.x, 0, tgt.y) + o
				at.y = tw.height_at(at.x, at.z) + 0.5
				return [from, at]
	return [center + Vector3(0, 3, 0), center + Vector3(100, 0, 0)]


## Am Hauptfluss: Kamera auf flachem Ufer, Blick schräg über Ufer/Schlamm zum Wasser.
func _bank(tw: TerrainWorld) -> Array:
	var o := tw.origin()
	var main: Dictionary = tw.water_net.courses[0]
	var pts: PackedVector2Array = main.pts
	var best := 10
	for i in range(10, pts.size() - 10):
		if pts[i].distance_to(Vector2(-2500, -2600)) < pts[best].distance_to(Vector2(-2500, -2600)):
			best = i
	var p := pts[best]
	var t := (pts[best + 4] - pts[best - 4]).normalized()
	var side := Vector2(-t.y, t.x)
	var cam := p + side * (float(main.hw[best]) + 9.0)
	var from := Vector3(cam.x, tw.height_at_terrain(cam.x, cam.y) + 2.0, cam.y) + o
	var tgt := p + t * 28.0 + side * (float(main.hw[best]) * 0.6)
	var at := Vector3(tgt.x, float(main.level[best]) - 0.5, tgt.y) + o
	return [from, at]


func _m(mask: Image, p: Vector2, tw: TerrainWorld, res: int) -> float:
	var i := clampi(int((p.x + tw.data.size_m * 0.5) / tw.data.size_m * res), 0, res - 1)
	var j := clampi(int((p.y + tw.data.size_m * 0.5) / tw.data.size_m * res), 0, res - 1)
	return mask.get_pixel(i, j).r
