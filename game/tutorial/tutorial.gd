class_name Tutorial
extends Node
## Geführtes Tutorial (M3.2 Phase 2). Start: Option --tutorial bzw. Game.tutorial_mode (Angebot
## beim allerersten Start, TutorialOffer). Ruhige Szene: gleiche Welt, keine roten Angreifer,
## kein Alarm, nur ein „Übungsziel“, das nicht zurückschießt.
## Jeder Schritt hat Aufgaben, deren Prüfung die echte Aktion beobachtet (Flugzustand, Eingabe,
## Treffer-Bus, Befehlsrad, Tragen, Munition, Sitz). F8 überspringt den Schritt, F7 beendet.
## Fortschritt in user://tutorial.cfg (angeboten, letzter Schritt, abgeschlossen).

signal step_changed(index: int)
signal finished(completed: bool)

const PROGRESS_PATH := "user://tutorial.cfg"
const TEXT_STEP_TIME := 12.0
const TARGET_RADIUS := 900.0
const TARGET_SPEED := 65.0
const HITS_NEEDED := 3

var game: Node = null
var steps: Array = []
var index := -1
## Erledigte Aufgaben des aktuellen Schritts.
var done: Array = []
var step_t := 0.0
var active := false
var card: TutorialCard
var target: Aircraft = null
var hits := 0
var home := Transform3D.IDENTITY

var _turn := 0.0
var _last_heading := INF
var _cmd_fuel := false
var _crate_taken := false
var _ammo_mark := -1
var _bus: CombatEvents
var _target_angle := 0.0
var _target_center := Vector3.ZERO


# --- Fortschritt ---------------------------------------------------------------------------

static func load_progress() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(PROGRESS_PATH)
	return c


static func save_progress(key: String, value) -> void:
	var c := load_progress()
	c.set_value("tutorial", key, value)
	c.save(PROGRESS_PATH)


static func was_offered() -> bool:
	return bool(load_progress().get_value("tutorial", "offered", false))


## Selbsttest/Diagnose: Schritte bauen, Karte erzeugen.
static func diagnose() -> Array:
	var t := Tutorial.new()
	t.steps = t.build_steps()
	var c := TutorialCard.new()
	var ok := t.steps.size() == 7 and c != null
	for s in t.steps:
		ok = ok and not (s.tasks as Array).is_empty() and String(s.title) != ""
	var n := t.steps.size()
	c.free()
	t.free()
	return [ok, "Tutorial lädt: %d Schritte, Karte %s" % [n, str(ok)]]


# --- Ablauf --------------------------------------------------------------------------------

func _ready() -> void:
	name = "Tutorial"
	steps = build_steps()
	var a := _aircraft()
	if a != null:
		home = a.global_transform
	card = TutorialCard.new()
	var h = game.get("hud") if game != null else null
	if h != null:
		(h as Node).add_child(card)
	else:
		add_child(card)
	active = true
	save_progress("offered", true)
	go_to(0)


func go_to(i: int) -> void:
	index = i
	step_t = 0.0
	if i >= steps.size():
		_finish(true)
		return
	var s: Dictionary = steps[i]
	done = []
	for _k in (s.tasks as Array).size():
		done.append(false)
	if s.has("setup"):
		(s.setup as Callable).call()
	save_progress("last_step", i)
	_refresh()
	step_changed.emit(i)


func skip_step() -> void:
	if active:
		go_to(index + 1)


func quit() -> void:
	if active:
		_finish(false)


func _finish(completed: bool) -> void:
	active = false
	if completed:
		save_progress("completed", true)
	_set_keys([])
	if card != null and is_instance_valid(card):
		card.queue_free()
	_remove_target()
	finished.emit(completed)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed(&"tutorial_skip"):
		skip_step()
	elif event.is_action_pressed(&"tutorial_quit"):
		quit()


func _physics_process(dt: float) -> void:
	if not active or index < 0 or index >= steps.size():
		return
	step_t += dt
	_track(dt)
	var s: Dictionary = steps[index]
	var tasks: Array = s.tasks
	# Aufgaben der Reihe nach: erst wenn die vorige erledigt ist, zählt die nächste
	for k in tasks.size():
		if done[k]:
			continue
		if (tasks[k][1] as Callable).call():
			done[k] = true
			_refresh()
		break
	if done.all(func(x): return x):
		go_to(index + 1)
	elif card != null and is_instance_valid(card):
		card.step_t = step_t


func _refresh() -> void:
	if card == null or not is_instance_valid(card) or index >= steps.size():
		return
	var s: Dictionary = steps[index]
	card.set_step(index, steps.size(), s.title, s.text, (s.tasks as Array).map(func(t): return t[0]), done)
	_set_keys(s.keys)


func _set_keys(k: Array) -> void:
	var gh = _ground_hud()
	if gh != null:
		gh.key_override = k


# --- Hilfsdaten ----------------------------------------------------------------------------

func _aircraft() -> Aircraft:
	if game == null:
		return null
	var a = game.get("player_aircraft")
	return a if a is Aircraft and is_instance_valid(a) else null


func _ground_hud() -> GroundHud:
	var h = game.get("hud") if game != null else null
	return h.ground_hud if h != null and h.get("ground_hud") != null else null


func _ctx() -> int:
	var s = game.get("session") if game != null else null
	return int(s.context) if s != null else InputBindings.Context.FLIGHT


func _tel() -> FlightTelemetry:
	var a := _aircraft()
	return a.telemetry() if a != null else null


func _track(_dt: float) -> void:
	var a := _aircraft()
	if a == null:
		return
	var t := a.telemetry()
	var f := -a.global_transform.basis.z
	var hd := atan2(f.x, -f.z)
	if not t.on_ground and _last_heading != INF:
		_turn += absf(wrapf(hd - _last_heading, -PI, PI))
	_last_heading = hd
	var b := CombatEvents.bus()
	if b != _bus:
		_bus = b
		b.hit_confirmed.connect(_on_hit)
	_update_target(_dt)


func _on_hit(shooter: Node, tgt: Node, _zone: int, _dmg: float) -> void:
	if active and shooter == _aircraft() and tgt != null and tgt == target:
		hits += 1


# --- Übungsziel (kinematisch auf einer Kreisbahn, schießt nicht) ---------------------------

func spawn_target() -> void:
	var a := _aircraft()
	if a == null or (target != null and is_instance_valid(target)):
		return
	target = Aircraft.create(a.data)
	target.name = "Uebungsziel"
	target.nation_id = Nations.RED
	target.set_meta("display_name", "Übungsziel")
	game.add_child(target)
	var f := -a.global_transform.basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.1 else Vector3.FORWARD
	_target_center = a.global_position + f * (TARGET_RADIUS + 900.0)
	_target_center.y = maxf(a.global_position.y, WorldGround.height_at(_target_center.x, _target_center.z) + 500.0)
	_target_angle = atan2(-f.z, -f.x)   # Startpunkt auf der dem Spieler zugewandten Seite
	_update_target(0.0)
	target.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	target.freeze = true


func _update_target(dt: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.damage != null and target.damage.is_destroyed:
		target.damage.reset()
	_target_angle += dt * TARGET_SPEED / TARGET_RADIUS
	var p := _target_center + Vector3(cos(_target_angle), 0, sin(_target_angle)) * TARGET_RADIUS
	var tang := Vector3(-sin(_target_angle), 0, cos(_target_angle))
	var xf := Transform3D(Basis.looking_at(tang, Vector3.UP).rotated(tang, -0.35), p)
	if dt == 0.0:
		target.place(xf, TARGET_SPEED, 0.6, false)
	else:
		target.global_transform = xf
		target.linear_velocity = tang * TARGET_SPEED


func _remove_target() -> void:
	if target != null and is_instance_valid(target):
		target.queue_free()
	target = null


# --- Schritte ------------------------------------------------------------------------------

func build_steps() -> Array:
	var C := InputBindings.Context
	return [
		{"title": "Starten",
		 "text": "Die Parkbremse ist an. Gib Gas – ab 10 % löst sie sich. Halte die Maschine mit dem Seitenruder auf der Bahn und ziehe ab etwa 150 km/h leicht.",
		 "keys": [[&"throttle_up", "Gas"], [&"kb_yaw_left", "Seitenruder"], [&"kb_pitch_up", "Ziehen"]],
		 "tasks": [
			["Gas geben (Parkbremse löst)", _chk_gas],
			["Rollen und abheben", _chk_airborne]]},
		{"title": "Fliegen",
		 "text": "Fahrwerk einfahren, dann eine Kurve fliegen: Rollen und gleichzeitig ziehen. Danach auf 300 m über Grund steigen.",
		 "keys": [[&"gear_toggle", "Fahrwerk"], [&"kb_roll_left", "Rollen"], [&"kb_pitch_up", "Ziehen"]],
		 "setup": func(): _turn = 0.0,
		 "tasks": [
			["Fahrwerk einfahren", _chk_gear_up],
			["Kurve fliegen (90°)", func(): return _turn > PI * 0.5],
			["Auf 300 m über Grund steigen", _chk_climb]]},
		{"title": "Zielen",
		 "text": "Vor dir kreist ein Übungsziel – es schießt nicht. Halte den Zielzoom, setze das Fadenkreuz auf den Vorhaltepunkt (Kreis vor dem Ziel) und feuere kurze Stöße.",
		 "keys": [[&"zoom_hold", "Zielzoom (halten)"], [&"fire_primary", "Feuer"]],
		 "setup": _setup_aim,
		 "tasks": [
			["Zielzoom halten", func(): return Input.is_action_pressed(&"zoom_hold")],
			["%d Treffer am Übungsziel" % HITS_NEEDED, func(): return hits >= HITS_NEEDED]]},
		{"title": "Notausstieg",
		 "text": "Notausstieg geht nur bei schwerem Schaden: Taste 1 s halten. Bei leichtem Schaden lieber landen – die Maschine wird repariert.",
		 "keys": [[&"eject_hold", "Notausstieg (1 s halten)"]],
		 "setup": func(): _remove_target(),
		 "tasks": [["Gelesen", func(): return step_t > TEXT_STEP_TIME]]},
		{"title": "Landen",
		 "text": "Flieg zurück zum Platz. Platzrunde: parallel zur Bahn, Gas raus, Fahrwerk und Klappen aus, Endanflug flach. Nach der Landung zum Abstellplatz rollen (Bodenmarke) und anhalten.",
		 "keys": [[&"gear_toggle", "Fahrwerk"], [&"flaps_cycle", "Klappen"], [&"brakes", "Bremsen"]],
		 "tasks": [
			["Zurück zum Platz (< 2,5 km)", _chk_home],
			["Fahrwerk ausfahren", _chk_gear_down],
			["Landen", _chk_landed],
			["Am Abstellplatz anhalten", _chk_parked]]},
		{"title": "Abfertigen",
		 "text": "Steig aus. Öffne das Befehlsrad und wähle „Nur tanken“ – die Mannschaft tankt. Die Munition lädst du selbst: Kiste holen, an der Klappe Interagieren halten (Klappe, Gurt). Dann wieder einsteigen.",
		 "keys": [[&"eject_hold", "Aussteigen (halten)"], [&"crew_wheel", "Befehlsrad"], [&"crew_interact", "Interagieren"], [&"crew_enter", "Einsteigen"]],
		 "setup": _setup_service,
		 "tasks": [
			["Aussteigen", func(): return _ctx() == C.CREW],
			["Befehlsrad: „Nur tanken“", func(): return _cmd_fuel],
			["Munitionskiste holen", func(): return _crate_taken],
			["Klappe öffnen, Gurt einlegen", _chk_ammo],
			["Einsteigen", func(): return _ctx() == C.FLIGHT]]},
		{"title": "Geschafft",
		 "text": "Alle Tasten findest du jederzeit unter F1. Im freien Spiel kommt ein Alarmstart: Rote greifen an – Maschine schnell abfertigen und starten. Viel Erfolg!",
		 "keys": [[&"help_toggle", "Hilfe"]],
		 "tasks": [["Abschluss", func(): return step_t > TEXT_STEP_TIME * 0.6]]},
	]


func _setup_service() -> void:
	_cmd_fuel = false
	_crate_taken = false
	_ammo_mark = -1
	var gh := _ground_hud()
	if gh != null and not gh.command_issued.is_connected(_on_command):
		gh.command_issued.connect(_on_command)
	var ch = game.get("crew") if game != null else null
	if ch != null and ch.has_signal("carried_changed") and not ch.carried_changed.is_connected(_on_carried):
		ch.carried_changed.connect(_on_carried)


func _on_command(cmd: int, _t: Node) -> void:
	if cmd == GroundCrewBrain.Command.FUEL_ONLY:
		_cmd_fuel = true


func _on_carried(item: Node) -> void:
	if item != null and item.get("kind") == CarryItem.CRATE and _cmd_fuel:
		_crate_taken = true
		var a := _aircraft()
		_ammo_mark = a.weapons.ammo() if a != null else -1


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _setup_aim() -> void:
	hits = 0
	spawn_target()


func _chk_gas() -> bool:
	var pl = game.get("player")
	return pl != null and not pl.parking_brake and pl.throttle > 0.5


func _chk_airborne() -> bool:
	var t := _tel()
	return t != null and not t.on_ground and t.height_agl > 15.0


func _chk_gear_up() -> bool:
	var t := _tel()
	return t != null and t.gear_extension <= 0.01


func _chk_climb() -> bool:
	var t := _tel()
	return t != null and t.height_agl > 300.0


func _chk_home() -> bool:
	var a := _aircraft()
	return a != null and _flat(a.global_position - home.origin) < 2500.0


func _chk_gear_down() -> bool:
	var t := _tel()
	return t != null and t.gear_extension >= 0.99


func _chk_landed() -> bool:
	var t := _tel()
	return t != null and t.on_ground and t.airspeed * 3.6 < 60.0


func _chk_parked() -> bool:
	var a := _aircraft()
	return a != null and a.seat_on_ground() and a.seat_speed() < 1.0 and _flat(a.global_position - home.origin) < 40.0


func _chk_ammo() -> bool:
	var a := _aircraft()
	return a != null and _ammo_mark >= 0 and a.weapons.ammo() > _ammo_mark
