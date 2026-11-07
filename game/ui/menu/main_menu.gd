class_name MainMenu
extends Node3D
## Hauptmenü (M3.2), Startszene. Hintergrund: die echte Welt, Kamera kreist langsam über Platz Blau.
## Startoptionen --tutorial, --selbsttest, --boden=, --ki=, --gegner=, --testwelt überspringen das Menü.

const ORBIT_RADIUS := 135.0
const ORBIT_HEIGHT := 36.0
const ORBIT_SPEED := 0.025

var menu: GameMenu
var cam: Camera3D
## M3.3: Flugplatz-Kulisse (AirfieldOps.setup_decor)
var decor: AirfieldOps
var _center := Vector3.ZERO
var _a := 0.6


static func skip_requested(args: PackedStringArray = OS.get_cmdline_user_args(),
		engine_args: PackedStringArray = OS.get_cmdline_args()) -> bool:
	if "--selbsttest" in engine_args:
		return true
	for a in args:
		if a in ["--tutorial", "--selbsttest", "--testwelt"] or a.begins_with("--boden=") \
				or a.begins_with("--ki=") or a.begins_with("--gegner="):
			return true
	return false


func _ready() -> void:
	InputBindings.setup()
	GameSettings.apply_runtime()
	if skip_requested():
		Game.tutorial_mode = "--tutorial" in OS.get_cmdline_user_args()
		get_tree().change_scene_to_file.call_deferred(GameMenu.GAME_SCENE)
		return
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("Flugkern %s" % Hud.VERSION)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_background()
	menu = GameMenu.new()
	menu.mode = GameMenu.Mode.MAIN
	menu.start_requested.connect(start_game)
	add_child(menu)


func _background() -> void:
	if not ResourceLoader.exists(Game.TERRAIN_SCENE):
		return
	var w: Node3D = (load(Game.TERRAIN_SCENE) as PackedScene).instantiate()
	add_child(w)
	if w.has_method("airfield_count") and w.airfield_count() > 0:
		_center = w.to_scene(w.airfield(0).center)
		# M3.3: Hallen, Tanklager, Bunker, Wagen und abgestellte Flugzeuge wie im Spiel
		var lay: AirfieldLayout = w.airfield_layout(0) if w.has_method("airfield_layout") else null
		if lay != null:
			decor = AirfieldOps.new()
			add_child(decor)
			decor.setup_decor(lay)
			# Kamera kreist um die Abstellfläche statt um die Pistenmitte
			var focus := lay.to_scene(lay.hangar).lerp(lay.parking_transform(0).origin, 0.5) \
				if lay.parking_count() > 0 else lay.to_scene(lay.hangar)
			_center = focus
	_center.y = WorldGround.height_at(_center.x, _center.z)
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 12000.0
	add_child(cam)
	cam.make_current()
	_place_cam()


func _place_cam() -> void:
	if cam == null:
		return
	cam.position = _center + Vector3(cos(_a) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(_a) * ORBIT_RADIUS)
	cam.look_at(_center + Vector3(0, 4, 0), Vector3.UP)
	# Flugplatz rechts neben das Menü schieben (Menü-Panel links)
	cam.rotate_object_local(Vector3.UP, deg_to_rad(14.0))


func _process(dt: float) -> void:
	_a += dt * ORBIT_SPEED
	_place_cam()


func start_game(tutorial: bool) -> void:
	Game.tutorial_mode = tutorial
	get_tree().change_scene_to_file(GameMenu.GAME_SCENE)
