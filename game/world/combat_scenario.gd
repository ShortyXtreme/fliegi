class_name CombatScenario
extends Node
## Szenario „Luftkampf 1 gegen 3“ (M2, Paket 14). Wird von game.gd angelegt.
##  - Gegner: `enemy_count` KI-Jäger der Nation Rot (AIPilotBrain, Stufe `difficulty`),
##    patrouillieren 6–10 km vom Platz Blau in Richtung Platz Rot und greifen an.
##  - Bodenleitung: Ist der Spieler in der Luft und weiter als GCI_MIN_DIST vom eigenen
##    Platz, lenkt das Szenario Gegner ohne Ziel zu ihm (sonst eigene Patrouille).
##  - Abgeschossene Gegner starten nach 30–60 s (`enemy_respawn_min/max`) über dem
##    Platz Rot neu (in der Luft, steigend) – dauerhafter Kampf.
##  - Erfahrung: Abschuss/Mithilfe → PilotRecord.add_xp; Stillstand am Platz Blau →
##    bank_xp() mit Meldung im Kill-Feed.
## Einstellungen: user://flugkern.cfg, Abschnitt [m2] (ki_stufe = "rekrut" | "erfahren" |
## "veteran", gegner = 1..6) oder Startoption `-- --ki=veteran --gegner=2`.

const CONFIG_PATH := "user://flugkern.cfg"
const LEVEL_NAMES := {"rekrut": "Rekrut", "erfahren": "Erfahren", "veteran": "Veteran"}
const GCI_MIN_DIST := 2500.0
const PATROL_DIST := [6000.0, 8000.0, 10000.0]
const PATROL_AGL := 1300.0
const XP_KILL := 100
const XP_ASSIST := 40
## Stillstand auf dem eigenen Platz: Radius um die Pistenmitte (m).
const HOME_RADIUS := 1200.0

var difficulty := "erfahren"
var enemy_count := 3
var enemy_respawn_min := 30.0
var enemy_respawn_max := 60.0

var game: Node
var world: Node3D
var enemies: Array[Aircraft] = []
var brains: Array[AIPilotBrain] = []
var patrol_points: Array[Vector3] = []
var blue_field := 0
var red_field := 1
var _rng := RandomNumberGenerator.new()
var _name_counter := 0
var _bus: CombatEvents = null


func _init() -> void:
	_rng.seed = 20261101
	load_config()


## Einstellungen aus user://flugkern.cfg und der Kommandozeile.
func load_config() -> void:
	var cf := ConfigFile.new()
	if cf.load(CONFIG_PATH) == OK:
		difficulty = str(cf.get_value("m2", "ki_stufe", difficulty)).to_lower()
		enemy_count = int(cf.get_value("m2", "gegner", enemy_count))
		var zr := str(cf.get_value("m2", "zoom_realistisch", "flugzeug")).to_lower()
		MatchRules.realistic_zoom = {"immer": MatchRules.RealisticZoom.ALWAYS,
			"nie": MatchRules.RealisticZoom.NEVER}.get(zr, MatchRules.RealisticZoom.AIRCRAFT)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ki="):
			difficulty = a.substr(5).to_lower()
		elif a.begins_with("--gegner="):
			enemy_count = int(a.substr(9))
		elif a.begins_with("--zoom-realistisch="):
			MatchRules.realistic_zoom = {"immer": MatchRules.RealisticZoom.ALWAYS,
				"nie": MatchRules.RealisticZoom.NEVER}.get(a.substr(19).to_lower(),
				MatchRules.RealisticZoom.AIRCRAFT)
	if not LEVEL_NAMES.has(difficulty):
		push_warning("Unbekannte KI-Stufe '%s', nehme 'erfahren'" % difficulty)
		difficulty = "erfahren"
	enemy_count = clampi(enemy_count, 1, 6)


func difficulty_name() -> String:
	return LEVEL_NAMES.get(difficulty, difficulty)


## Flugplätze der Nationen suchen und Patrouillenpunkte festlegen.
func setup(g: Node, w: Node3D) -> void:
	game = g
	world = w
	if w.has_method("airfield_count"):
		for i in w.airfield_count():
			var n: int = w.airfield(i).get("nation", -1)
			if n == Nations.BLUE:
				blue_field = i
			elif n == Nations.RED:
				red_field = i
	var b := field_center(blue_field)
	var r := field_center(red_field)
	var dir := Vector3(r.x - b.x, 0, r.z - b.z).normalized()
	var side := Vector3.UP.cross(dir)
	patrol_points.clear()
	for k in enemy_count:
		var dist: float = PATROL_DIST[k % PATROL_DIST.size()]
		var p := b + dir * dist + side * (k - (enemy_count - 1) * 0.5) * 1800.0
		p.y = _ground(p) + PATROL_AGL + k * 150.0
		patrol_points.append(p)


func field_center(i: int) -> Vector3:
	if world.has_method("airfield_count") and i < world.airfield_count():
		var p: Vector3 = world.to_scene(world.airfield(i).center)
		p.y = _ground(p)
		return p
	return Vector3.ZERO if i == blue_field else Vector3(0, 0, -9000)


func _ground(p: Vector3) -> float:
	return WorldGround.height_at(p.x, p.z)


## Gegner erzeugen (nur Server): in der Luft an den Patrouillenpunkten.
func spawn_enemies(data: AircraftData, spawn_manager: SpawnManager) -> void:
	_connect_bus()
	for k in enemy_count:
		var a := Aircraft.create(data)
		a.name = "AIAircraft%d" % (k + 1)
		a.nation_id = Nations.RED
		game.add_child(a)
		var br := AIPilotBrain.new()
		br.name = "AIBrain%d" % (k + 1)
		br.difficulty = AIDifficulty.load_level(difficulty)
		br.rng_seed = 1000 + k
		game.add_child(br)
		enemies.append(a)
		brains.append(br)
		_place_enemy(k, true)
		if Authority.is_server():
			a.pilot_seat.possess(br)
			spawn_manager.register(a, br, func(): _respawn_enemy(k),
					func(): return _rng.randf_range(enemy_respawn_min, enemy_respawn_max))


func _place_enemy(k: int, initial: bool) -> void:
	var a := enemies[k]
	var br := brains[k]
	var home := field_center(red_field)
	var pos: Vector3
	var fwd: Vector3
	if initial:
		pos = patrol_points[k]
		fwd = field_center(blue_field) - pos
	else:
		# Neustart über dem Platz Rot, Richtung Patrouillenpunkt, steigend
		pos = home + Vector3(k * 60.0, 350.0, -300.0 - k * 80.0)
		fwd = patrol_points[k] - pos
	fwd.y = 0.0
	_name_counter += 1
	a.set_meta("display_name", "Rot %d" % _name_counter)
	a.place(Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP), pos), 105.0, 1.0, false)
	br.patrol_center = patrol_points[k]
	br.patrol_altitude = patrol_points[k].y
	br.patrol_radius = 1500.0
	br.home = home + Vector3(0, 600.0, 0)
	if Authority.is_server():
		a.pilot_seat.possess(br)   # Gehirn neu starten (Wahrnehmung, Zustand)


func _respawn_enemy(k: int) -> void:
	_place_enemy(k, false)


func _connect_bus() -> void:
	var b := CombatEvents.bus()
	if b == _bus:
		return
	_bus = b
	b.aircraft_destroyed.connect(_on_destroyed)


func _on_destroyed(victim: Node, killer: Node, _cause: int) -> void:
	if killer != null and is_instance_valid(killer) and killer != victim:
		var rec = killer.get("pilot")
		if rec is PilotRecord and Nations.is_hostile(killer.get("nation_id"), victim.get("nation_id")):
			rec.add_xp(XP_KILL, "Abschuss")
	var d = victim.get("damage")
	if d is DamageModel:
		for h in d.assists():
			if h != killer and is_instance_valid(h):
				var r2 = h.get("pilot")
				if r2 is PilotRecord:
					r2.add_xp(XP_ASSIST, "Mithilfe")


func _physics_process(_dt: float) -> void:
	if not Authority.is_server() or game == null:
		return
	_connect_bus()
	var pl: Aircraft = game.get("player_aircraft")
	if pl == null or not is_instance_valid(pl):
		return
	var t := pl.telemetry()
	var home := field_center(blue_field)
	var away := Vector2(pl.global_position.x - home.x, pl.global_position.z - home.z).length()
	var alive := not pl.damage.is_destroyed
	# Bodenleitung
	var gci := alive and not t.on_ground and t.height_agl > 150.0 and away > GCI_MIN_DIST
	for k in brains.size():
		var br := brains[k]
		if gci and br.target == null:
			var p := pl.global_position
			br.patrol_center = Vector3(p.x, 0.0, p.z)
			br.patrol_altitude = maxf(p.y + 300.0, _ground(p) + 600.0)
		elif br.target == null:
			br.patrol_center = patrol_points[k]
			br.patrol_altitude = patrol_points[k].y
	# XP gutschreiben: Stillstand am eigenen Platz
	if alive and t.on_ground and pl.linear_velocity.length() < 2.0 and away < HOME_RADIUS \
			and pl.pilot != null and pl.pilot.pending_total() > 0:
		var n := pl.pilot.bank_xp()
		var hud = game.get("hud")
		if hud != null and hud.combat != null:
			hud.combat.kill_feed.add_text(pl, "gelandet: +%d XP gutgeschrieben (gesamt %d)" % [
				n, pl.pilot.xp_banked], pl)
		print("XP gutgeschrieben: +%d (gesamt %d)" % [n, pl.pilot.xp_banked])
