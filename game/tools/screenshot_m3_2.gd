extends SceneTree
## M3.2-UI-Screenshots aus der echten Hauptszene: Flug im Kampf, zu Fuß bei der Abfertigung,
## Befehlsrad, F1-Hilfe (zu Fuß und im Flug).
## xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1920x1080 --script res://tools/screenshot_m3_2.gd -- <out_dir> [präfix]

var out_dir := "user://"
var prefix := "ui_m3_2_"
var game: Game


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		prefix = args[1]
	if args.size() > 2 and args[2] == "menu":
		_run_menu.call_deferred()
	elif args.size() > 2 and args[2] == "tutorial":
		_run_tutorial.call_deferred()
	else:
		_run.call_deferred()


## Hauptmenü (kreisende Kamera über Platz Blau) und Pausenmenü im Spiel.
func _run_menu() -> void:
	var m: Node = load("res://ui/menu/main_menu.tscn").instantiate()
	root.add_child(m)
	for i in 120:
		await process_frame
	await _shot("g_hauptmenue")
	m.queue_free()
	CombatHud.replace_legacy_text = true
	game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	await _frames(60)
	game.open_pause_menu()
	game.pause_menu.list.nav("down")
	for i in 10:
		await process_frame
	await _shot("g_pausenmenue")
	quit(0)


## Tutorial: Schritt 3 „Zielen“ mit Übungsziel; dazu das Angebot beim ersten Start.
func _run_tutorial() -> void:
	CombatHud.replace_legacy_text = true
	Game.tutorial_mode = true
	game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	await _frames(30)
	var tu: Tutorial = game.tutorial
	var pa := game.player_aircraft
	var p0 := pa.global_position + Vector3(0, 650, 0)
	pa.place(Transform3D(Basis.looking_at(-pa.global_transform.basis.z, Vector3.UP), p0), 90.0, 0.8, false)
	game.player.reset_state(0.8)
	game.player.parking_brake = false
	game.player.gear_down = false
	tu.go_to(2)
	tu.done[0] = true
	tu._refresh()
	tu._target_angle += 0.5
	await _frames(90)
	await _shot("e_tutorial_zielen")
	quit(0)


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(1440, 810, Image.INTERPOLATE_LANCZOS)
	var p := out_dir.path_join(prefix + name + ".png")
	img.save_png(p)
	print("gespeichert: ", p)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _enemy(nm: String, pos: Vector3, dir: Vector3, id: int) -> Aircraft:
	var a := Aircraft.create(game.ai_aircraft.data)
	a.name = nm
	a.nation_id = Nations.RED
	a.entity_id = id
	game.add_child(a)
	a.place(Transform3D(Basis.looking_at(dir, Vector3.UP), pos), 85.0, 0.8, false)
	return a


func _run() -> void:
	CombatHud.replace_legacy_text = true
	game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	await _frames(60)
	if game.hud._help.visible:
		game.hud.toggle_help()
	var pa := game.player_aircraft
	var home := pa.global_transform
	# --- (a) Flug im Kampf ---
	var b := Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
	var p0 := pa.global_position + Vector3(0, 700, 0)
	pa.place(Transform3D(b, p0), 92.0, 0.85, false)
	game.player.reset_state(0.85)
	game.player.parking_brake = false
	game.player.gear_down = false
	var e2 := _enemy("Rot2", p0 + Vector3(40, 25, -320), Vector3(-0.15, 0, -1), 22)
	_enemy("Rot3", p0 + Vector3(-1400, 100, 600), Vector3(1, 0, 0), 23)
	await _frames(20)
	Input.action_press("fire_primary")
	await _frames(12)
	pa.damage.apply_hit(DamageModel.Zone.WING_L, 120.0, e2)
	pa.damage.apply_hit(DamageModel.Zone.TAIL, 60.0, e2)
	CombatEvents.bus().hit_confirmed.emit(pa, e2, DamageModel.Zone.ENGINE, 10.0)
	game.hud.combat.overlay.hit_t = 10.0
	await _frames(2)
	await _shot("a_flug_kampf")
	Input.action_release("fire_primary")
	await _frames(2)
	# F1 im Flug
	game.hud.toggle_help()
	await _frames(4)
	await _shot("d2_hilfe_flug")
	game.hud.toggle_help()
	# --- (b) zu Fuß neben dem Flugzeug, Abfertigung läuft ---
	e2.queue_free()
	pa.place_on_ground(home.origin, -home.basis.z, false)
	game.player.reset_state(0.0)
	pa.damage.apply_hit(DamageModel.Zone.WING_L, 60.0, null)
	await _frames(60)
	var ops: AirfieldOps = game.blue_ops
	var spot = ops.dispatch.vehicle_spot(pa, false)
	ops.truck.place(spot, pa.global_transform.basis.get_euler().y)
	Input.action_press("eject_hold")
	await _frames(75)
	Input.action_release("eject_hold")
	await _frames(10)
	var ch := game.crew
	var side := pa.global_transform.basis.x
	var cap := pa.to_global(ServiceMarkers.aircraft_point(pa, "svc_fuel_cap"))
	var p := cap - side * 2.2 - pa.global_transform.basis.z * 0.8
	ch.global_position = Vector3(p.x, WorldGround.height_at(p.x, p.z), p.z)
	var to := cap - ch.global_position
	ch.heading = atan2(-to.x, -to.z)
	game.session.crew.look_yaw = ch.heading
	game.session.crew.look_pitch = -0.1
	await _frames(120)
	await _shot("b_zu_fuss_abfertigung")
	# --- (c) Befehlsrad ---
	var gh: GroundHud = game.hud.ground_hud
	gh.wheel_override = 1
	await _frames(3)
	gh.wheel.feed_mouse(Vector2(60, -40))
	await _frames(3)
	await _shot("c_befehlsrad")
	gh.wheel_override = 0
	await _frames(3)
	gh.wheel_override = -1
	# --- (d) F1-Hilfe zu Fuß ---
	gh.toggle_help()
	await _frames(4)
	await _shot("d_hilfe_zu_fuss")
	quit(0)
