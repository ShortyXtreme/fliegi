extends SceneTree
## M3.5-Screenshots: Befehlsrad (Ebene Mechaniker), Tutorial-Markierung, Schalterpanel, Warnlampen.
## xvfb-run -s "-screen 0 2560x1440x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1600x900 --script res://tools/screenshot_m3_5_boden.gd -- <out_dir> [rad|markierung|schalter|lampen]

var out_dir := "user://"
var mode := "rad"
var game: Game


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		mode = args[1]
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(n: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if img.get_width() > 1600:
		img.resize(1600, int(1600.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join(n + ".png"))
	print("Screenshot ", out_dir.path_join(n + ".png"))


func _start(tutorial := false) -> void:
	CombatHud.replace_legacy_text = true
	Game.tutorial_mode = tutorial
	game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	Game.tutorial_mode = false
	await _frames(60)
	if game.hud._help.visible:
		game.hud.toggle_help()


## Aussteigen und die Figur neben den Tankdeckel stellen, Blick zur Maschine.
func _exit_near(marker: String, side_m := 2.4) -> void:
	var pa := game.player_aircraft
	Input.action_press("eject_hold")
	await _frames(75)
	Input.action_release("eject_hold")
	await _frames(10)
	var ch := game.crew
	var side := pa.global_transform.basis.x
	var pt := pa.service_point(marker)
	var p := pt - side * side_m + pa.global_transform.basis.z * 2.0
	ch.global_position = Vector3(p.x, WorldGround.height_at(p.x, p.z), p.z)
	var to := pt - ch.global_position
	ch.heading = atan2(-to.x, -to.z)
	game.session.crew.look_yaw = ch.heading
	game.session.crew.look_pitch = -0.15
	await _frames(90)


func _run() -> void:
	match mode:
		"funk":
			await _start()
			await _exit_near("svc_fuel_cap")
			var gh: GroundHud = game.hud.ground_hud
			var pa := game.player_aircraft
			pa.damage.fuel.set_fraction(0.2)
			gh.toggle_radio()
			gh.radio.choose(1)                     # Kanal 1 Tankwart
			gh.radio.choose(3)                     # Volltanken
			await _frames(240)
			gh.toggle_radio()
			gh.radio.choose(1)                     # Kanalliste -> Kanal 1 (Befehle + Antwortzeilen)
			await _frames(3)
			await _shot("m3_5_funkgeraet")
			gh.radio.back()
			await _frames(3)
			await _shot("m3_5_funk_kanaele")
		"tasten":
			var m: MainMenu = load("res://ui/menu/main_menu.tscn").instantiate()
			root.add_child(m)
			await _frames(90)
			m.menu.show_page("keys")
			for i in 18:
				m.menu.list.nav("down")
			await _frames(20)
			await _shot("m3_5_tastenbelegung")
		"schalter":
			await _start()
			game.player.assist_mode = FlightAssist.Mode.REALISTIC
			var ec := EngineControl.find(game.player_aircraft)
			ec.set_master(true)
			ec.set_fuel_pump(true)
			ec.set_starter(true)
			await _frames(20)
			await _shot("m3_5_schalterpanel")
		"lampen":
			await _start()
			var pa := game.player_aircraft
			var b := Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
			pa.place(Transform3D(b, pa.global_position + Vector3(0, 600, 0)), 105.0, 0.9, true)
			game.player.reset_state(0.9, true)
			pa.damage.fuel.set_fraction(0.04)
			await _frames(40)
			await _shot("m3_5_warnlampen")
		"markierung":
			await _start(true)
			await _exit_near("svc_fuel_cap", 5.5)
			await _frames(30)
			await _shot("m3_5_tutorial_markierung")
	quit(0)
