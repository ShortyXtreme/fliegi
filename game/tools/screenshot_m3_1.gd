extends SceneTree
## M3.1-Screenshots: Mechaniker in Ruhe (idle) neben dem Flugzeug; Platz mit den Gebäuden.
## Aufruf: xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/screenshot_m3_1.gd -- out_dir [idle|platz|alle]

var out_dir := "user://"
var which := "alle"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		which = args[1]
	_run.call_deferred()


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var p := out_dir.path_join(name)
	img.save_png(p)
	print("gespeichert: ", p)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _cam(game: Node, from: Vector3, at: Vector3, fov := 50.0) -> Camera3D:
	var c := Camera3D.new()
	c.fov = fov
	c.far = 8000.0
	game.add_child(c)
	c.global_position = from
	c.look_at(at, Vector3.UP)
	c.make_current()
	return c


func _run() -> void:
	var game: Game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	await _frames(60)
	game.hud.visible = false
	var pl := game.player_aircraft
	var ops: AirfieldOps = game.blue_ops
	# Personal ruht (keine Abfertigung): Gehirne aus
	for br in ops.brains:
		br.process_mode = Node.PROCESS_MODE_DISABLED
	if which in ["idle", "alle"]:
		var ch: CrewCharacter = ops.crews[0]
		var side := pl.global_transform.basis.x
		var fwd := -pl.global_transform.basis.z
		var p := pl.global_position - side * 6.5 + fwd * 1.0
		ch.global_position = Vector3(p.x, WorldGround.height_at(p.x, p.z), p.z)
		ch.heading = atan2(side.x, side.z)        # Blick vom Flugzeug weg (zur Kamera)
		await _frames(90)
		var head := ch.global_position + Vector3(0, 1.0, 0)
		var cam_p := head - side * 4.2 + fwd * 1.2 + Vector3(0, 0.4, 0)
		var c := _cam(game, cam_p, head + side * 1.5, 45.0)
		await _frames(20)
		await _shot("m3_1_mechaniker_idle.png")
		c.queue_free()
	if which == "anims":
		# Kontrolle: alle Animationen nebeneinander (Phase 30 %), Blick von vorn
		var base := pl.global_position + Vector3(0, 0, 40)
		base.y = WorldGround.height_at(base.x, base.z)
		var names := ["idle", "walk", "run", "carry", "hose", "lift", "work", "enter"]
		for i in names.size():
			var m: Node3D = (load("res://assets/ground/crew_mechanic.glb") as PackedScene).instantiate()
			game.add_child(m)
			m.global_position = base + Vector3((i - 3.5) * 1.3, 0, 0)
			m.rotation.y = PI
			var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
			ap.play(names[i])
			ap.seek(ap.current_animation_length * 0.3, true)
			ap.pause()
		_cam(game, base + Vector3(0, 1.1, 8.5), base + Vector3(0, 0.9, 0), 55.0)
		await _frames(10)
		await _shot("anims.png")
	if which in ["platz", "alle"]:
		var l: AirfieldLayout = ops.layout
		var at := l.to_scene(Vector3(-75, 0, 300))
		_cam(game, l.to_scene(Vector3(10, 0, 420)) + Vector3(0, 45, 0), at, 55.0)
		await _frames(30)
		await _shot("m3_1_platz.png")
	quit(0)
