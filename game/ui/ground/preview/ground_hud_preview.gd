extends SceneTree
## Sichtprüfung Boden-HUD mit Fake-Daten (kein Teil des Spiels).
## xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1920x1080 --script res://ui/ground/preview/ground_hud_preview.gd -- <out_dir>

var out_dir := "user://"
var game: Game
var g: GroundHud
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	_run.call_deferred()


func _shot(file: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(file))
	print("gespeichert: ", out_dir.path_join(file))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _worker(nm: String) -> Node:
	var n := Node.new()
	n.name = nm
	game.add_child(n)
	return n


func _run() -> void:
	game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	await _frames(5)
	game.hud.toggle_help()
	var layout: AirfieldLayout = game.world.airfield_layout(0) if game.world.has_method("airfield_layout") else null
	var pxf := layout.parking_transform(0) if layout != null else Transform3D(Basis.IDENTITY, Vector3(0, 0, 300))
	var a := game.player_aircraft
	var nose := -pxf.basis.z
	a.place_on_ground(pxf.origin, nose, false)
	a.damage.fuel.set_fraction(0.38, 0.0)
	a.weapons.set_ammo_fraction(0.0)
	a.damage.apply_hit(DamageModel.Zone.WING_L, 40.0, null)
	# Lager, Jobs, Abfertigung
	var depot := FuelDepot.new()
	depot.draw(FuelSystem.GRADE_AVIATION, 1760.0)
	depot.draw(FuelSystem.GRADE_ERSATZ, 2650.0)
	var bunker := AmmoBunker.new()
	bunker.request(AmmoBunker.AMMO_792, 6500)
	var board := JobBoard.new()
	game.add_child(board)
	board.set_physics_process(false)
	var huber := _worker("Huber")
	var refuel := RefuelJob.new()
	refuel.target = a
	refuel.source = depot
	board.add_job(refuel)
	board.claim(0, refuel.id, huber)
	refuel.step_index = refuel.steps.find(&"pump")
	refuel.pumped = 142.0
	refuel.progress = 0.4
	var rl := RearmJob.new()
	rl.target = a
	rl.gun_index = 0
	board.add_job(rl)
	var rr := RearmJob.new()
	rr.target = a
	rr.gun_index = 1
	board.add_job(rr)
	var ta := Turnaround.new()
	ta.best_path = "user://preview_bestzeit.cfg"
	ta.save_best(141.0, 1)
	ta.running = true
	ta.elapsed = 74.0
	ta.helpers = 1
	# Figur neben der linken MG-Klappe
	var ch := CrewCharacter.new()
	game.add_child(ch)
	var right := nose.cross(Vector3.UP).normalized()
	var hatch := a.global_transform * ServiceMarkers.aircraft_point(a, "svc_gun_hatch_L")
	ch.global_position = hatch - right * 1.6 + nose * 0.4
	ch._snap_to_ground()
	ch.look_yaw = atan2(right.x, right.z) + PI
	board.claim(1, rl.id, ch)
	rl.step_index = rl.steps.find(&"belt")
	rl.progress = 0.6
	var it := Interactable.new()
	it.marker = "svc_gun_hatch_L"
	it.target = a
	it.add_action(&"belt", "Gurt einlegen", 3.0, CarryItem.CRATE)
	game.add_child(it)
	it.global_position = hatch
	ch.focus = it
	ch.set_physics_process(false)
	# Kamera über die Schulter
	cam = Camera3D.new()
	game.add_child(cam)
	cam.fov = 62
	cam.global_position = ch.global_position - right * 3.2 + nose * 2.6 + Vector3.UP * 1.9
	cam.look_at(hatch + nose * -1.0 + Vector3.UP * 0.4, Vector3.UP)
	cam.current = true
	game.cam.process_mode = Node.PROCESS_MODE_DISABLED
	# Boden-HUD
	g = GroundHud.create(game.hud)
	game.hud.add_child(g)
	g.character = ch
	g.board = board
	g.depot = depot
	g.bunker = bunker
	g.turnaround = ta
	g.aircraft_list = [a]
	g.set_context(InputBindings.Context.CREW)
	GroundEvents.bus().alarm_started.emit(167.4)
	await _frames(20)
	print("pos a=", a.global_position, " ch=", ch.global_position, " cam=", cam.global_position, " hatch=", hatch, " pxf=", pxf.origin, " status=", g.status.visible)
	# 1) Interaktion mit gehaltener Kiste (Hinweis, Ring), Statuspanel, Lager, Alarm
	ch.hold_progress = 0.6
	_override_action(ch, it)
	await _frames(4)
	await _shot("ground_1_interact.png")
	# 2) Befehlsrad
	g.wheel_override = 1
	await _frames(2)
	g.wheel.feed_mouse(Vector2(60, -60))
	await _frames(3)
	await _shot("ground_2_wheel.png")
	g.wheel.close_wheel(false)
	g.wheel_override = 0
	# 3) Pumpen am Tankdeckel + Lager leer daneben
	var cap := a.global_transform * ServiceMarkers.aircraft_point(a, "svc_fuel_cap")
	it.marker = "svc_fuel_cap"
	it.actions.clear()
	it.add_action(&"pump", "Pumpen", 0.0)
	it.actions[0]["continuous"] = true
	it.global_position = cap
	ch.hold_progress = 0.0
	ch.global_position = cap - right * 1.4
	ch._snap_to_ground()
	cam.global_position = ch.global_position - right * 3.0 + nose * 2.0 + Vector3.UP * 1.8
	cam.look_at(cap + Vector3.UP * 0.3, Vector3.UP)
	g.toggle_help()
	await _frames(4)
	await _shot("ground_3_pump_help.png")
	g.toggle_help()
	# 4) Im Cockpit nach der Landung: Bodenmarke + Pfeil zum Abstellplatz
	var land := pxf.origin + Vector3(80, 0, 140)
	a.place_on_ground(land, -nose, false)
	g.has_parking_target = true
	g.parking_target = pxf.origin
	g.set_context(InputBindings.Context.FLIGHT)
	game.cam.process_mode = Node.PROCESS_MODE_INHERIT
	cam.current = false
	game.cam.camera.current = true
	await _frames(30)
	await _shot("ground_4_flight_parking.png")
	quit()


## Fake: Figur „hat“ die Aktion (current_action liefert sie, Gegenstand vorhanden).
func _override_action(ch: CrewCharacter, it: Interactable) -> void:
	it.actions[0]["needs_item"] = &""
