class_name Tutorial
extends Node
## Geführtes Tutorial (M3.2 Phase 2). Start: Option --tutorial bzw. Game.tutorial_mode (Angebot
## über das Hauptmenü, GameMenu). Ruhige Szene: gleiche Welt, keine roten Angreifer,
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
## M3.4: Bodenvorbereitung zuerst (11 Schritte)
const STEP_COUNT := 11
const STEP_AMMO := 2
const START_FUEL := 0.25

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
var _fuel_mark := 0.0
var _bus: CombatEvents
var _target_angle := 0.0
var _target_center := Vector3.ZERO
## M3.3: Controller – View halten (VIEW_HOLD_S) = Schritt überspringen; kurz drücken = Hilfe wie
## bisher (wird beim Loslassen nachgereicht). Beenden per Pausenmenü (Menu-Taste).
const VIEW_HOLD_S := 0.8
var view_hold := -1.0


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
	var ok := t.steps.size() == STEP_COUNT and c != null
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
	_prepare_aircraft()
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
	_set_marks(s.get("marks", Callable()))
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
	_set_auto_service(true)
	if completed:
		save_progress("completed", true)
	_set_keys([])
	_set_marks(Callable())
	if card != null and is_instance_valid(card):
		card.queue_free()
	_remove_target()
	finished.emit(completed)


func _input(event: InputEvent) -> void:
	KeyGlyphs.note_input(event)
	if not active or not (event is InputEventJoypadButton) \
			or (event as InputEventJoypadButton).button_index != JOY_BUTTON_BACK:
		return
	get_viewport().set_input_as_handled()
	if event.pressed:
		if view_hold < 0.0:
			view_hold = 0.0
	else:
		var was := view_hold
		view_hold = -1.0
		if card != null and is_instance_valid(card):
			card.hold = 0.0
		if was >= 0.0:
			_send_help()


## Kurzer View-Druck: Hilfe umschalten (als Aktion nachgereicht, damit Flug/Boden reagieren).
func _send_help() -> void:
	for pr in [true, false]:
		var a := InputEventAction.new()
		a.action = &"help_toggle"
		a.pressed = pr
		Input.parse_input_event(a)


func _process(dt: float) -> void:
	if view_hold < 0.0:
		return
	view_hold += dt
	if card != null and is_instance_valid(card):
		card.hold = clampf(view_hold / VIEW_HOLD_S, 0.0, 1.0)
	if view_hold >= VIEW_HOLD_S:
		view_hold = -2.0   # bis zum Loslassen gesperrt
		if card != null and is_instance_valid(card):
			card.hold = 0.0
		skip_step()


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
		{"title": "Aussteigen",
		 "text": "Erst die Maschine vorbereiten: Tank und MG sind fast leer. Steig aus – im Stand Taste 1 s halten.",
		 "keys": [[&"eject_hold", "Aussteigen (1 s halten)"]],
		 "tasks": [["Aussteigen", func(): return _ctx() == C.CREW]]},
		{"title": "Tanken",
		 "text": "Der Tankwagen steht neben der Maschine. Selbst tanken: am gelben Ring „Schlauch hier nehmen“ Interagieren halten, zum Ring „Tankstutzen“ gehen und dort halten – der Schlauch koppelt an, die Pumpe läuft (hörbar, Tankanzeige im Cockpit). Oder per Funk: Funkgerät öffnen, Kanal 1 „Tankwart“, Befehl „Volltanken“.",
		 "marks": _marks_fuel,
		 "keys": [[&"crew_interact", "Interagieren (halten)"], [&"crew_wheel", "Funkgerät"], [&"radio_channel_1", "Kanal Tankwart"], [&"radio_cmd_3", "Volltanken"]],
		 "setup": _setup_fuel,
		 "tasks": [
			["Funk „Volltanken“ oder Schlauch ankoppeln", func(): return _cmd_fuel or _fuel() > _fuel_mark + 0.01],
			["Tank füllt sich (+10 %)", func(): return _fuel() > _fuel_mark + 0.1]]},
		{"title": "Munition",
		 "text": "Am Munitionswagen beim Ring „Kiste hier holen“ Interagieren halten. Die Kiste zur markierten MG-Klappe im Flügel tragen und dort halten: Klappe auf, Gurt einlegen, Klappe zu.",
		 "marks": _marks_ammo,
		 "keys": [[&"crew_interact", "Interagieren (halten)"], [&"crew_drop", "Ablegen"]],
		 "setup": _setup_ammo,
		 "tasks": [
			["Munitionskiste nehmen", func(): return _crate_taken],
			["Klappe öffnen, Gurt einlegen", _chk_ammo]]},
		{"title": "Einsteigen",
		 "text": "Zum markierten Einstieg am Cockpit gehen und einsteigen.",
		 "marks": _marks_entry,
		 "keys": [[&"crew_enter", "Einsteigen"]],
		 "tasks": [["Einsteigen", func(): return _ctx() == C.FLIGHT]]},
		{"title": "Vorflug-Check",
		 "text": "Klappen einmal tippen = Startstellung (mehr Auftrieb). Dann Gas geben – ab 10 % löst sich die Parkbremse.",
		 "keys": [[&"flaps_cycle", "Klappen"], [&"throttle_up", "Gas"]],
		 "tasks": [
			["Startklappen setzen", func(): return _flaps() == 1],
			["Gas geben (Parkbremse löst)", _chk_gas]]},
		{"title": "Start",
		 "text": "Auf der Bahn mit dem Seitenruder geradeaus halten, ab etwa 150 km/h leicht ziehen. In der Luft Fahrwerk und Klappen einfahren.",
		 "keys": [[&"kb_yaw_left", "Seitenruder"], [&"kb_pitch_up", "Ziehen"], [&"gear_toggle", "Fahrwerk"], [&"flaps_cycle", "Klappen"]],
		 "tasks": [
			["Abheben", _chk_airborne],
			["Fahrwerk einfahren", _chk_gear_up],
			["Klappen einfahren", func(): return _flaps() == 0]]},
		{"title": "Fliegen",
		 "text": "Kurve fliegen: rollen und gleichzeitig ziehen. Dann auf 300 m über Grund steigen.",
		 "keys": [[&"kb_roll_left", "Rollen"], [&"kb_pitch_up", "Ziehen"], [&"throttle_up", "Gas"]],
		 "setup": func(): _turn = 0.0,
		 "tasks": [
			["Kurve fliegen (90°)", func(): return _turn > PI * 0.5],
			["Auf 300 m über Grund steigen", _chk_climb]]},
		{"title": "Zielen",
		 "text": "Vor dir kreist ein Übungsziel – es schießt nicht. Zielzoom halten, Fadenkreuz auf den Vorhaltekreis, kurze Stöße.",
		 "keys": [[&"zoom_hold", "Zielzoom (halten)"], [&"fire_primary", "Feuer"]],
		 "setup": _setup_aim,
		 "tasks": [
			["Zielzoom halten", func(): return Input.is_action_pressed(&"zoom_hold")],
			["%d Treffer am Übungsziel" % HITS_NEEDED, func(): return hits >= HITS_NEEDED]]},
		{"title": "Landung",
		 "text": "Zurück zum Platz. Parallel zur Bahn Gas raus, Fahrwerk aus, Klappen zweimal = Landestellung. Flach anschweben und aufsetzen.",
		 "keys": [[&"gear_toggle", "Fahrwerk"], [&"flaps_cycle", "Klappen"], [&"throttle_down", "Gas weg"], [&"brakes", "Bremsen"]],
		 "setup": func(): _remove_target(),
		 "tasks": [
			["Zurück zum Platz (< 2,5 km)", _chk_home],
			["Fahrwerk ausfahren", _chk_gear_down],
			["Landeklappen setzen", func(): return _flaps() == 2],
			["Landen", _chk_landed]]},
		{"title": "Abstellplatz",
		 "text": "Zum Abstellplatz rollen (Bodenmarke) und anhalten.",
		 "keys": [[&"kb_yaw_left", "Lenken"], [&"throttle_up", "Gas"], [&"brakes", "Bremsen"]],
		 "tasks": [["Am Abstellplatz anhalten", _chk_parked]]},
		{"title": "Geschafft",
		 "text": "Alle Tasten unter F1. Notausstieg nur bei schwerem Schaden (Taste 1 s halten) – sonst landen und reparieren lassen. Im freien Spiel kommt der Alarmstart. Viel Erfolg!",
		 "keys": [[&"help_toggle", "Hilfe"], [&"eject_hold", "Notausstieg"]],
		 "tasks": [["Abschluss", func(): return step_t > TEXT_STEP_TIME * 0.6]]},
	]


## M3.4: Tutorial-Maschine fast leer (Tank 25 %, MG leer) – sie wird zuerst am Boden vorbereitet.
func _prepare_aircraft() -> void:
	var a := _aircraft()
	if a == null:
		return
	if a.damage != null:
		a.damage.fuel.set_fraction(START_FUEL)
	a.weapons.set_ammo_fraction(0.0)
	_set_auto_service(false)


## Automatik-Abfertigung des eigenen Platzes für die Tutorial-Maschine aus/an.
func _set_auto_service(on: bool) -> void:
	var ops = game.get("blue_ops") if game != null else null
	var a := _aircraft()
	if ops == null or ops.dispatch == null or a == null:
		return
	ops.dispatch.auto_exclude.erase(a)
	if not on:
		ops.dispatch.auto_exclude.append(a)


func _fuel() -> float:
	var t := _tel()
	return t.fuel_fraction if t != null else 0.0


func _flaps() -> int:
	var pl = game.get("player") if game != null else null
	return int(pl.flap_index) if pl != null else -1


# --- M3.5: 3D-Markierungen ---------------------------------------------------------

func _guide() -> InteractionGuide:
	var g = game.get("guide") if game != null else null
	return g if g is InteractionGuide and is_instance_valid(g) else null


func _set_marks(c: Callable) -> void:
	var g := _guide()
	if g != null:
		g.override = c


func _carried() -> StringName:
	var ch = game.get("crew") if game != null else null
	var it = ch.get("carried") if ch != null else null
	return it.kind if it is Object and it.get("kind") != null else &""


func _ops():
	return game.get("blue_ops") if game != null else null


func _marks_fuel() -> Array:
	var a := _aircraft()
	var ops = _ops()
	if a == null or ops == null or _ctx() != InputBindings.Context.CREW:
		return []
	var cap := InteractionGuide.at_aircraft(a, ServiceMarkers.SVC_FUEL_CAP, "Tankstutzen", "hier ankoppeln – Interagieren halten")
	var hose = ops.truck.hose if ops.truck != null else null
	if _carried() == CarryItem.HOSE:
		return [cap]
	if hose is FuelHose and hose.is_coupled():
		cap.sub = "Schlauch gekoppelt – Pumpe läuft"
		return [cap]
	return [InteractionGuide.at_vehicle(ops.truck, ServiceMarkers.HOSE_REEL, "Schlauch hier nehmen", "Interagieren halten"), cap]


func _marks_ammo() -> Array:
	var a := _aircraft()
	var ops = _ops()
	if a == null or ops == null or _ctx() != InputBindings.Context.CREW:
		return []
	var hatches := []
	for i in a.weapons.gun_count():
		if a.weapons.gun_ammo(i) < a.weapons.gun_capacity(i):
			var m := ServiceMarkers.SVC_GUN_HATCH_L if i % 2 == 0 else ServiceMarkers.SVC_GUN_HATCH_R
			if not hatches.has(m):
				hatches.append(m)
	if _carried() == CarryItem.CRATE:
		return hatches.map(func(m): return InteractionGuide.at_aircraft(a, m, InteractionGuide.hatch_text(m),
			"Klappe auf, Gurt ein, Klappe zu – halten"))
	var out := [InteractionGuide.at_vehicle(ops.cart, ServiceMarkers.crate_slot(1), "Kiste hier holen", "Interagieren halten")]
	if not hatches.is_empty():
		out.append(InteractionGuide.at_aircraft(a, hatches[0], InteractionGuide.hatch_text(hatches[0]), "hierhin tragen"))
	return out


func _marks_entry() -> Array:
	var a := _aircraft()
	if a == null or _ctx() != InputBindings.Context.CREW:
		return []
	return [InteractionGuide.at_aircraft(a, ServiceMarkers.SVC_ENTRY, "Einstieg", "Einsteigen")]


## Wagen neben die Maschine stellen (Tutorial: kein Rangieren nötig).
func _park_vehicle(cart: bool) -> void:
	var a := _aircraft()
	var ops = _ops()
	if a == null or ops == null:
		return
	var v: GroundVehicle = ops.cart if cart else ops.truck
	var spot = ops.dispatch.vehicle_spot(a, cart)
	if v != null and spot is Vector3 and v.driver_seat.controller == null:
		var fwd := -a.global_transform.basis.z
		v.place(spot, atan2(-fwd.x, -fwd.z))


func _setup_fuel() -> void:
	_park_vehicle(false)
	_cmd_fuel = false
	_fuel_mark = _fuel()
	_connect_ground()


func _setup_ammo() -> void:
	_park_vehicle(true)
	_crate_taken = false
	_ammo_mark = -1
	_connect_ground()


func _connect_ground() -> void:
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
	if item != null and item.get("kind") == CarryItem.CRATE and index == STEP_AMMO and not _crate_taken:
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
