class_name Game
extends Node3D
## Hauptszene M2: Gelände (TerrainWorld), Spieler auf Platz Blau (Parkbremse), Szenario
## „Luftkampf 1 gegen 3“ (world/combat_scenario.gd). Wer welchen Sitz bekommt, entscheidet
## der Server (offline: wir selbst, Peer 1).
## Umschalten auf die alte Testwelt: Startoption `-- --testwelt` (ohne Gegner-Szenario
## nur mit einem kreisenden KI-Flugzeug wie in M1).

const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"
const TERRAIN_SCENE := "res://world/terrain/terrain_world.tscn"

## Gelände statt TestWorld (Standard an).
static var use_terrain := true

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


func _ready() -> void:
	# Fenstertitel mit Version; config/name bleibt „Flugkern M2“, damit der Ordner
	# user:// (Einstellungen, Logs) zwischen M2 und M2.1 gleich bleibt.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Flugkern %s" % Hud.VERSION)
	CombatEvents.reset()
	GroundEvents.reset()
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

	player = PlayerController.new()
	player.name = "PlayerController"
	add_child(player)

	if terrain:
		scenario = CombatScenario.new()
		scenario.name = "Scenario"
		add_child(scenario)
		scenario.setup(self, world)
		scenario.spawn_enemies(data, spawn_manager)
		ai_aircrafts = scenario.enemies
		ai_aircraft = ai_aircrafts[0]
		ai = scenario.brains[0]
	else:
		_spawn_test_ai(data)
	_place_player_on_ground()

	if Authority.is_server():
		player_aircraft.pilot_seat.possess(player)
		spawn_manager.register(player_aircraft, player, func(): _on_reset(false))

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

	# Floating Origin (Paket 13): Schalter, Standard aus (FLOATING_ORIGIN=1 schaltet ein)
	origin_shifter = OriginShifter.new()
	origin_shifter.name = "OriginShifter"
	origin_shifter.focus = player_aircraft
	add_child(origin_shifter)

	player.camera_next_requested.connect(cam.next_mode)
	player.debug_toggle_requested.connect(hud.toggle_debug)
	player.debug_forces_requested.connect(hud.toggle_forces)
	player.help_toggle_requested.connect(hud.toggle_help)
	player.reset_requested.connect(_on_reset)
	player.gear_toggled.connect(hud.on_gear_toggled)
	_print_diagnostics()
	if Selbsttest.requested():
		var st := Selbsttest.new()
		st.name = "Selbsttest"
		st.game = self
		add_child(st)
	if scenario != null:
		print("Flugkern %s: Luftkampf 1 gegen %d, KI-Stufe %s" % [Hud.VERSION,
				scenario.enemy_count, scenario.difficulty_name()])


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
