class_name Game
extends Node3D
## Hauptszene M1: Testwelt, Spieler-Flugzeug auf der Piste, KI-Flugzeug in der Luft.
## Wer welchen Sitz bekommt, entscheidet der Server (offline: wir selbst, Peer 1).
## M2 (Paket 0): Kampf-Infrastruktur ist angelegt (ProjectileSystem, WeaponFx,
## SpawnManager, Nationen). Das Szenario „1 gegen 3“ baut Paket 14 hier ein.

const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"

var world: TestWorld
var player_aircraft: Aircraft
var ai_aircraft: Aircraft
var player: PlayerController
var ai: AIController
var cam: CameraRig
var hud: Hud
var projectiles: ProjectileSystem
var weapon_fx: WeaponFx
var spawn_manager: SpawnManager


func _ready() -> void:
	CombatEvents.reset()
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
	var data: AircraftData = load(FIGHTER)

	player_aircraft = Aircraft.create(data)
	player_aircraft.name = "PlayerAircraft"
	player_aircraft.nation_id = Nations.BLUE
	add_child(player_aircraft)
	player_aircraft.place_on_ground(world.runway_spawn(0), TestWorld.RUNWAY_DIR)

	# KI-Flugzeug: anderes Farbschema, startet in der Luft und kreist über dem Platz
	var ai_data: AircraftData = data.duplicate()
	ai_data.body_color = Color(0.55, 0.22, 0.2)
	ai_data.accent_color = Color(0.9, 0.9, 0.85)
	ai_aircraft = Aircraft.create(ai_data)
	ai_aircraft.name = "AIAircraft"
	ai_aircraft.nation_id = Nations.RED
	add_child(ai_aircraft)
	var b := Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP)
	ai_aircraft.place(Transform3D(b, Vector3(900, 350, -1200)), 85.0, 0.8, false)

	player = PlayerController.new()
	player.name = "PlayerController"
	add_child(player)
	ai = AIController.new()
	ai.name = "AIController"
	ai.cruise_altitude = 350.0
	ai.circle_center = Vector3(0, 0, -1200)
	ai.circle_radius = 900.0
	add_child(ai)
	if Authority.is_server():
		player_aircraft.pilot_seat.possess(player)
		ai_aircraft.pilot_seat.possess(ai)
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

	player.camera_next_requested.connect(cam.next_mode)
	player.debug_toggle_requested.connect(hud.toggle_debug)
	player.help_toggle_requested.connect(hud.toggle_help)
	player.reset_requested.connect(_on_reset)
	player.gear_toggled.connect(hud.on_gear_toggled)
	player_aircraft.crashed.connect(func(_a): print("Crash! R = Neustart auf der Piste"))


func _on_reset(in_air: bool) -> void:
	if not Authority.is_server():
		return
	if in_air:
		var b := Basis.looking_at(TestWorld.RUNWAY_DIR, Vector3.UP)
		player_aircraft.place(Transform3D(b, TestWorld.RUNWAY_START + Vector3(0, 500, 0)), 90.0, 0.8, false)
		player.reset_state(0.8, false)
	else:
		player_aircraft.place_on_ground(world.runway_spawn(0), TestWorld.RUNWAY_DIR)
		player.reset_state(0.0)
