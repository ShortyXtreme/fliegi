class_name Game
extends Node3D
## Hauptszene M3: Gelände (TerrainWorld), Spieler am Abstellplatz von Platz Blau (Parkbremse,
## Startzustand nach MatchRules), Szenario „Luftkampf 1 gegen 3“ (world/combat_scenario.gd,
## Gegner starten am Boden von Platz Rot). Bodenbetrieb je Platz (AirfieldOps): Lager, Bunker,
## Wagen, 2 KI-Mechaniker. Der Mensch ist eine PlayerSession (Flug / zu Fuß / Fahren).
## Wer welchen Sitz bekommt, entscheidet der Server (offline: wir selbst, Peer 1).
## Umschalten auf die alte Testwelt: Startoption `-- --testwelt` (ohne Gegner-Szenario
## nur mit einem kreisenden KI-Flugzeug wie in M1).

const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"
const TERRAIN_SCENE := "res://world/terrain/terrain_world.tscn"

## Gelände statt TestWorld (Standard an).
static var use_terrain := true
## M3.2: Tutorial-Szene (ruhig: keine roten Angreifer, kein Alarm, Übungsziel). Auch per --tutorial.
static var tutorial_mode := false
var tutorial: Tutorial
## M3.3: Geräusche
var sound: SoundDirector

var world: Node3D
var player_aircraft: Aircraft
## Erstes KI-Flugzeug (Kompatibilität M1-Tests); alle: ai_aircrafts.
var ai_aircraft: Aircraft
var ai_aircrafts: Array[Aircraft] = []
var player: PlayerController
## Erster KI-Pilot (AIPilotBrain; in der Testwelt AIController).
var ai: Controller
var cam: CameraRig
var hud: Hud
var projectiles: ProjectileSystem
var weapon_fx: WeaponFx
var spawn_manager: SpawnManager
var scenario: CombatScenario
var origin_shifter: OriginShifter
## M3 (Paket 0b): Sitzwechsel und Bodenjobs (nur Server). Die Spieler-Maschine bleibt bis
## Paket 14 voll startklar auf der Piste; PlayerSession verdrahtet erst Paket 14.
var seat_service: SeatService
var job_board: JobBoard
## M3 Paket 14
var session: PlayerSession
var crew: CrewCharacter
var crew_camera: CrewCamera
var player_service: PlayerService
var turnaround: Turnaround
## AirfieldOps je Platzindex (nur Gelände).
var airfields := {}
var blue_ops: AirfieldOps
var alarm_interval := Vector2(720.0, 900.0)
var _alarm_next := -1.0
var _was_airborne := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Fenstertitel mit Version; config/name bleibt „Flugkern M2“, damit der Ordner
	# user:// (Einstellungen, Logs) zwischen M2 und M2.1 gleich bleibt.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Flugkern %s" % Hud.VERSION)
	CombatEvents.reset()
	GroundEvents.reset()
	GameAudio.setup()
	MatchRules.load_ground_config()
	ProjectileSystem.reset_targets()
	var terrain := use_terrain and not "--testwelt" in OS.get_cmdline_user_args() \
			and ResourceLoader.exists(TERRAIN_SCENE)
	if terrain:
		world = (load(TERRAIN_SCENE) as PackedScene).instantiate()
	else:
		world = TestWorld.new()
	world.name = "World"
	add_child(world)
	projectiles = ProjectileSystem.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	weapon_fx = WeaponFx.new()
	weapon_fx.name = "WeaponFx"
	add_child(weapon_fx)
	spawn_manager = SpawnManager.new()
	spawn_manager.name = "SpawnManager"
	add_child(spawn_manager)
	seat_service = SeatService.new()
	seat_service.name = "SeatService"
	add_child(seat_service)
	job_board = JobBoard.new()
	job_board.name = "JobBoard"
	add_child(job_board)
	var data: AircraftData = load(FIGHTER)

	player_aircraft = Aircraft.create(data)
	player_aircraft.name = "PlayerAircraft"
	player_aircraft.nation_id = Nations.BLUE
	player_aircraft.set_meta("display_name", "Blau 1")
	add_child(player_aircraft)
	# M3.3: Geräusche (hängt sich an alle Flugzeuge, Wagen, Figuren und Ereignisse)
	sound = SoundDirector.new()
	sound.player = player_aircraft
	add_child(sound)

	player = PlayerController.new()
	player.name = "PlayerController"
	add_child(player)
	player.exit_on_ground = true
	session = PlayerSession.new()
	session.name = "PlayerSession"
	session.adopt_flight(player)
	session.seat_service = seat_service
	add_child(session)
	player_service = PlayerService.new()
	player_service.name = "PlayerService"
	player_service.board = job_board
	add_child(player_service)
	turnaround = Turnaround.new()
	turnaround.board = job_board
	turnaround.realism = MatchRules.ground_realism

	if terrain:
		scenario = CombatScenario.new()
		scenario.name = "Scenario"
		add_child(scenario)
		scenario.setup(self, world)
		if is_tutorial():
			scenario.enemy_count = 0
		scenario.spawn_enemies(data, spawn_manager)
		ai_aircrafts = scenario.enemies
		if not ai_aircrafts.is_empty():
			ai_aircraft = ai_aircrafts[0]
			ai = scenario.brains[0]
		_setup_airfields()
	else:
		_spawn_test_ai(data)
	player_service.attach(player_aircraft)
	for a in ai_aircrafts:
		player_service.attach(a)
	_spawn_crew()

	if Authority.is_server():
		var lay := _player_layout()
		if lay != null:
			spawn_manager.register_ground(player_aircraft, player, lay)
			spawn_manager.spawn_on_ground(player_aircraft, lay, MatchRules.StartKind.FIRST)
			player.reset_state(0.0)
		else:
			_place_player_on_ground()
			spawn_manager.register(player_aircraft, player, func(): _on_reset(false))
		_board_player_seat()
		spawn_manager.respawned.connect(_on_respawned)

	cam = CameraRig.new()
	cam.name = "CameraRig"
	cam.target = player_aircraft
	cam.player = player
	add_child(cam)

	hud = Hud.new()
	hud.aircraft = player_aircraft
	hud.player = player
	hud.camera_rig = cam
	add_child(hud)

	crew_camera = CrewCamera.new()
	crew_camera.name = "CrewCamera"
	add_child(crew_camera)
	session.camera_rig = cam
	session.crew_camera = crew_camera
	session.hud = hud
	_setup_ground_hud()
	session.context_changed.connect(_on_context_changed)
	session.apply_view(player_aircraft.pilot_seat)
	GroundCrewBrain.player_probe = _player_positions
	_alarm_next = _rng.randf_range(alarm_interval.x, alarm_interval.y)

	# Floating Origin (Paket 13): Schalter, Standard aus (FLOATING_ORIGIN=1 schaltet ein)
	origin_shifter = OriginShifter.new()
	origin_shifter.name = "OriginShifter"
	origin_shifter.focus = player_aircraft   # (zu Fuß bleibt die Maschine in der Nähe)
	add_child(origin_shifter)

	player.camera_next_requested.connect(cam.next_mode)
	player.debug_toggle_requested.connect(hud.toggle_debug)
	player.debug_forces_requested.connect(hud.toggle_forces)
	player.help_toggle_requested.connect(hud.toggle_help)
	player.reset_requested.connect(_on_reset)
	player.gear_toggled.connect(hud.on_gear_toggled)
	GameSettings.apply_runtime(self)   # M3.2: Menü-Einstellungen (Flugmodus, Radar, Maus)
	if is_tutorial():
		_alarm_next = -1.0
		start_tutorial()
	_print_diagnostics()
	_print_ground_diagnostics()
	if Selbsttest.requested():
		var st := Selbsttest.new()
		st.name = "Selbsttest"
		st.game = self
		add_child(st)
	if scenario != null:
		print("Flugkern %s: Luftkampf 1 gegen %d, KI-Stufe %s" % [Hud.VERSION,
				scenario.enemy_count, scenario.difficulty_name()])


func is_tutorial() -> bool:
	return tutorial_mode or "--tutorial" in OS.get_cmdline_user_args()


func start_tutorial() -> Tutorial:
	if tutorial != null and is_instance_valid(tutorial):
		return tutorial
	tutorial = Tutorial.new()
	tutorial.game = self
	add_child(tutorial)
	print("Tutorial gestartet")
	return tutorial


## M2.2: Diagnosezeile je Flugzeug (Hitbox-Zonen, Waffen, Herkunft der Marker), damit
## fehlende Trefferzonen/Waffen im Tester-Log sofort auffallen.
func _print_diagnostics() -> void:
	var all: Array[Aircraft] = [player_aircraft]
	all.append_array(ai_aircrafts)
	for a in all:
		var h: HitboxSet = a.damage.hitboxes if a.damage != null else null
		var src := h.markers.source if h != null and h.markers != null else "-"
		var registered := ProjectileSystem.targets().any(func(t): return t.node == a)
		print("Diagnose %s: Hitbox-Zonen %d (Radius %.1f m), Waffen %d, Marker-Quelle %s, Ziel angemeldet %s" % [
				a.name, h.zones.size() if h != null else 0, h.bounding_radius if h != null else 0.0,
				a.weapons.gun_count(), src, str(registered)])
	print("Diagnose " + GameAudio.diagnostics())


## M1-Verhalten (Testwelt): ein KI-Flugzeug kreist über dem Platz.
func _spawn_test_ai(data: AircraftData) -> void:
	ai_aircraft = Aircraft.create(data)
	ai_aircraft.name = "AIAircraft"
	ai_aircraft.nation_id = Nations.RED
	add_child(ai_aircraft)
	ai_aircrafts = [ai_aircraft]
	var b := Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP)
	ai_aircraft.place(Transform3D(b, Vector3(900, 350, -1200)), 85.0, 0.8, false)
	var c := AIController.new()
	c.name = "AIController"
	c.cruise_altitude = 350.0
	c.circle_center = Vector3(0, 0, -1200)
	c.circle_radius = 900.0
	add_child(c)
	ai = c
	if Authority.is_server():
		ai_aircraft.pilot_seat.possess(c)
		spawn_manager.register(ai_aircraft, c, func():
			ai_aircraft.place(Transform3D(b, Vector3(900, 350, -1200)), 85.0, 0.8, false))


func _runway_spawn(i: int) -> Vector3:
	if world is TerrainWorld:
		return (world as TerrainWorld).runway_spawn(i, scenario.blue_field if scenario else 0)
	return (world as TestWorld).runway_spawn(i)


# --- M3 Paket 14: Bodenbetrieb ---------------------------------------------------

func _setup_airfields() -> void:
	if not (world is TerrainWorld):
		return
	var tw := world as TerrainWorld
	for i in tw.airfield_count():
		var lay := tw.airfield_layout(i)
		if lay == null or lay.parking_count() == 0:
			continue
		var ops := AirfieldOps.new()
		add_child(ops)
		ops.setup(lay, job_board, self, [player_aircraft] if lay.nation_id == Nations.BLUE else [])
		airfields[i] = ops
		if i == (scenario.blue_field if scenario != null else 0):
			blue_ops = ops
	if scenario != null:
		scenario.spawn_enemies_on_ground(spawn_manager, tw.airfield_layout(scenario.red_field))


func _player_layout() -> AirfieldLayout:
	if world is TerrainWorld and scenario != null:
		return (world as TerrainWorld).airfield_layout(scenario.blue_field)
	return null


## Spielerfigur (Mechaniker-Modell), sitzt zu Beginn im Cockpit.
func _spawn_crew() -> void:
	crew = CrewCharacter.new()
	crew.name = "PlayerCrew"
	crew.nation_id = Nations.BLUE
	add_child(crew)
	if ResourceLoader.exists(AirfieldOps.CREW_MODEL):
		crew.apply_model((load(AirfieldOps.CREW_MODEL) as PackedScene).instantiate())
	crew.global_position = player_aircraft.global_position


## Figur sitzt im Pilotensitz (Rider), der FlightController steuert.
func _board_player_seat() -> void:
	var s := player_aircraft.pilot_seat
	seat_service.riders[s] = crew
	crew.on_entered_seat(s)
	session.take_seat(s)


func _setup_ground_hud() -> void:
	var gh := hud.ground_hud
	if gh == null:
		return
	gh.session = session            # Kontext lesen (NICHT session.ground_hud setzen)
	gh.character = crew
	gh.board = job_board
	gh.turnaround = turnaround
	gh.aircraft_list = [player_aircraft]
	if blue_ops != null:
		gh.depot = blue_ops.depot
		gh.bunker = blue_ops.bunker
		gh.dispatch = blue_ops.dispatch
		blue_ops.dispatch.follow_target = crew
	for ops in airfields.values():
		ops.dispatch.announced.connect(func(text, a):
			# M3.2: nur echte Landungen melden (nicht den Start am Abstellplatz)
			if hud.combat != null and ops == blue_ops and String(text).ends_with("gelandet"):
				hud.combat.kill_feed.add_text(a, text, a))


func _on_context_changed(ctx: int) -> void:
	if ctx != InputBindings.Context.FLIGHT and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	origin_shifter.focus = crew if ctx == InputBindings.Context.CREW else \
		(session.seat.vehicle if session.seat != null and session.seat.vehicle is Node3D else player_aircraft)
	if ctx == InputBindings.Context.CREW and session.seat != null and session.seat.vehicle == crew:
		# Ausgestiegen: Abfertigungszeit läuft, Bodenmarke aus
		if hud.ground_hud != null:
			hud.ground_hud.has_parking_target = false
		var a := player_aircraft
		if not turnaround.running and blue_ops != null and blue_ops.dispatch.is_parked(a) \
				and blue_ops.dispatch.needs_service(a):
			turnaround.start(a)


func _player_positions() -> Array:
	if session != null and session.seat != null and session.seat.vehicle is Node3D:
		return [(session.seat.vehicle as Node3D).global_position]
	return [player_aircraft.global_position]


func trigger_alarm(seconds := Turnaround.ALARM_DEFAULT_S) -> void:
	if turnaround == null or turnaround.alarm_active():
		return
	var src: FuelSource = blue_ops.dispatch.fuel_source() if blue_ops != null else null
	var st: AmmoStore = blue_ops.dispatch.ammo_store() if blue_ops != null else null
	turnaround.start_alarm(seconds, player_aircraft, src, st)
	if not turnaround.running:
		turnaround.start(player_aircraft)
	if hud.combat != null:
		hud.combat.kill_feed.add_text(null, "ALARM: Roter Verband im Anflug, %d:%02d min" % [
			int(seconds) / 60, int(seconds) % 60], player_aircraft)
	print("Alarmstart: %.0f s" % seconds)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("alarm_debug"):
		trigger_alarm()
	elif event.is_action_pressed("release_mouse") and not get_tree().paused:
		open_pause_menu()   # M3.2: Esc / Menu-Taste: Pausenmenü (gibt die Maus frei)


## M3.2: Pausenmenü (Fortsetzen, Steuerung, Einstellungen, Zum Hauptmenü, Beenden).
var pause_menu: GameMenu


func open_pause_menu() -> void:
	if pause_menu != null and is_instance_valid(pause_menu):
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause_menu = GameMenu.new()
	pause_menu.mode = GameMenu.Mode.PAUSE
	pause_menu.game = self
	pause_menu.resume_requested.connect(close_pause_menu)
	pause_menu.tutorial_quit_requested.connect(func():
		close_pause_menu()
		if tutorial != null and is_instance_valid(tutorial):
			tutorial.quit())
	pause_menu.main_menu_requested.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file(GameMenu.MENU_SCENE))
	add_child(pause_menu)
	get_tree().paused = true


func close_pause_menu() -> void:
	if pause_menu != null and is_instance_valid(pause_menu):
		pause_menu.queue_free()
	pause_menu = null
	get_tree().paused = false


func _physics_process(dt: float) -> void:
	if turnaround != null:
		turnaround.tick(dt)
		# Ohne Abfertigungsbedarf läuft die Zeit nicht weiter (z. B. Spieler startet ohne Jobs)
		if turnaround.running and turnaround.aircraft == player_aircraft and player_aircraft.seat_speed() > 5.0:
			turnaround.finish()
	if scenario != null and _alarm_next > 0.0:
		_alarm_next -= dt
		if _alarm_next <= 0.0:
			trigger_alarm()
			_alarm_next = _rng.randf_range(alarm_interval.x, alarm_interval.y)
	_update_parking_guide()


## Nach der Landung (Spieler im Cockpit, am Boden, langsam): gelbe Bodenmarke zum freien Platz.
func _update_parking_guide() -> void:
	var gh := hud.ground_hud if hud != null else null
	if gh == null or session.context != InputBindings.Context.FLIGHT:
		return
	var t := player_aircraft.telemetry()
	if not t.on_ground:
		if t.height_agl > 30.0:
			_was_airborne = true
		return
	var lay := _player_layout()
	if _was_airborne and lay != null and player_aircraft.seat_speed() < 30.0:
		_was_airborne = false
		var spot := spawn_manager.free_spot(lay, player_aircraft)
		if spot >= 0:
			gh.parking_target = lay.parking_transform(spot).origin
			gh.has_parking_target = true
	if gh.has_parking_target and player_aircraft.global_position.distance_to(gh.parking_target) < 6.0 \
			and player_aircraft.seat_speed() < 1.0:
		gh.has_parking_target = false


func _on_respawned(a: Node3D) -> void:
	if a != player_aircraft:
		return
	_was_airborne = false
	if session.seat == player_aircraft.pilot_seat or session.context == InputBindings.Context.FLIGHT:
		if player_aircraft.pilot_seat.controller != player:
			session.take_seat(player_aircraft.pilot_seat)
		player.reset_state(0.0)


func _print_ground_diagnostics() -> void:
	for i in airfields:
		print("Diagnose Boden ", airfields[i].diagnostics())
	var n := AirfieldOps.mesh_count(crew.visual) if crew != null else 0
	print("Diagnose Spielerfigur: Mesh %d, Animationen %d, AnimationTree %s" % [n,
		_anim_count(crew), str(crew != null and crew.anim_tree != null)])


static func _anim_count(c: CrewCharacter) -> int:
	if c == null or c.anim_tree == null:
		return 0
	var ap := c.anim_tree.get_node_or_null(c.anim_tree.anim_player) as AnimationPlayer
	return ap.get_animation_list().size() if ap != null else 0


func _exit_tree() -> void:
	if GroundCrewBrain.player_probe.is_valid() and GroundCrewBrain.player_probe.get_object() == self:
		GroundCrewBrain.player_probe = Callable()


func _place_player_on_ground() -> void:
	player_aircraft.place_on_ground(_runway_spawn(0), TestWorld.RUNWAY_DIR)
	player.reset_state(0.0)   # Gas 0 → Parkbremse an


func _on_reset(in_air: bool) -> void:
	if not Authority.is_server():
		return
	if in_air:
		var b := Basis.looking_at(TestWorld.RUNWAY_DIR, Vector3.UP)
		var p := _runway_spawn(0) + Vector3(0, 500, 0)
		player_aircraft.place(Transform3D(b, p), 90.0, 0.8, false)
		player.reset_state(0.8, false)
	else:
		_place_player_on_ground()
