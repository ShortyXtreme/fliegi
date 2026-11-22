class_name EngineControl
extends Node
## M3.5: Motor anlassen/abstellen und Elektrik eines Flugzeugs (Kind-Knoten „EngineControl“ des
## Aircraft, angelegt mit of()). Ohne diesen Knoten läuft der Motor wie bisher (PropEngine.running).
##
## Schalter: Hauptschalter (Batterie), Kraftstoffpumpe/Hahn, Zündmagnete, Gemisch (reich/Abstellen),
## Anlasser (Schwungkraft-Anlasser der 30er: halten = Schwungrad läuft hoch, loslassen = einkuppeln,
## der Motor dreht durch und springt an – nur mit Batterie, Pumpe, Zündung, Gemisch und Treibstoff).
## Abstellen: Gemisch auf Abstellen oder Zündung aus.
## Arcade: toggle() erledigt alles automatisch (kurze Anlassdauer mit Klang).
## Realistisch: einzelne Schalter (PlayerController liest die Tasten, input()).
## Ein Teleport in die Luft (Neustart, Respawn) schaltet warm (Motor läuft).

signal message(text: String, warn: bool)
signal phase_changed(phase: int)

enum Phase { OFF, SPINUP, CRANK, RUNNING, STOPPING }
const PHASE_NAMES := ["aus", "Anlasser läuft hoch", "dreht durch", "läuft", "läuft aus"]

## Schwungrad: Hochlaufzeit (s) bis voll, Mindeststand zum Einkuppeln, Durchdrehen (s).
const SPINUP_S := 3.5
const ENGAGE_MIN := 0.6
const CRANK_S := 1.4
const STOP_S := 2.2
## Arcade: Hochlauf + Durchdrehen zusammen ca. 2 s.
const ARCADE_SPINUP_S := 1.1
const ARCADE_CRANK_S := 0.9
## Ohne Pumpe läuft der Motor noch so lange (Vergaser leer).
const PUMP_STARVE_S := 6.0
const TELEPORT_M := 40.0

var aircraft: Node3D = null
var master := false
var fuel_pump := false
var magnetos := false
var mixture := true
var starter_held := false
var phase := Phase.RUNNING
## Schwungrad 0..1.
var flywheel := 0.0
var auto_sequence := false
var _t := 0.0
var _starve := 0.0
var _last_pos := Vector3.INF
## Eingabe-Flanken (input()).
var _prev := {}
var _pad_hold := 0.0


static func find(a: Node) -> EngineControl:
	if a == null or not is_instance_valid(a):
		return null
	return a.get_node_or_null("EngineControl") as EngineControl


static func of(a: Node) -> EngineControl:
	var ec := find(a)
	if ec == null and a != null:
		ec = EngineControl.new()
		ec.name = "EngineControl"
		ec.aircraft = a
		a.add_child(ec)
	return ec


func _engine() -> PropEngine:
	var f = aircraft.get("flight") if aircraft != null else null
	return f.engine if f != null else null


func is_running() -> bool:
	return phase == Phase.RUNNING


## Kalt (Partiestart am Boden): alle Schalter aus, Motor steht.
func cold() -> void:
	master = false
	fuel_pump = false
	magnetos = false
	mixture = true
	starter_held = false
	auto_sequence = false
	flywheel = 0.0
	_set_phase(Phase.OFF)
	_apply()


## Warm (Luftstart): alles an, Motor läuft.
func warm() -> void:
	master = true
	fuel_pump = true
	magnetos = true
	mixture = true
	starter_held = false
	auto_sequence = false
	_set_phase(Phase.RUNNING)
	_apply()


## Grund, warum der Motor nicht anspringt ("" = alles bereit).
func start_problem() -> String:
	var a := aircraft
	var dm = a.get("damage") if a != null else null
	if not master:
		return "Hauptschalter (Batterie) aus"
	if not fuel_pump:
		return "Kraftstoffpumpe aus"
	if not magnetos:
		return "Zündung aus"
	if not mixture:
		return "Gemisch auf Abstellen"
	if dm != null and dm.fuel.is_empty():
		return "kein Kraftstoff"
	if dm != null and (dm.is_destroyed or dm.engine_dead or dm.hp[DamageModel.Zone.ENGINE] <= 0.0):
		return "Motor defekt"
	return ""


## Arcade: eine Taste „Motor an/aus“ – Schritte automatisch.
func toggle() -> void:
	if phase == Phase.RUNNING or phase == Phase.SPINUP or phase == Phase.CRANK:
		stop()
		return
	master = true
	fuel_pump = true
	magnetos = true
	mixture = true
	auto_sequence = true
	flywheel = 0.0
	_set_phase(Phase.SPINUP)
	_sound("switch")
	_sound("starter_whine")


## KI: anlassen, falls aus (Arcade-Ablauf).
func auto_start() -> void:
	if phase == Phase.OFF or phase == Phase.STOPPING:
		toggle()


## Abstellen (Gemisch auf Abstellen, Zündung aus).
func stop() -> void:
	if phase == Phase.OFF:
		return
	mixture = false
	magnetos = false
	auto_sequence = false
	starter_held = false
	if phase == Phase.RUNNING:
		_set_phase(Phase.STOPPING)
		_sound("engine_stop")
	else:
		_set_phase(Phase.OFF)
	mixture = true          # Hebel nach dem Auslaufen wieder auf „reich“ (nächster Start)


func set_master(on: bool) -> void:
	master = on
	_sound("switch")


func set_fuel_pump(on: bool) -> void:
	fuel_pump = on
	_sound("switch")


func set_magnetos(on: bool) -> void:
	magnetos = on
	_sound("switch")
	if not on and phase == Phase.RUNNING:
		_set_phase(Phase.STOPPING)
		_sound("engine_stop")


func set_mixture(rich: bool) -> void:
	mixture = rich
	if not rich and phase == Phase.RUNNING:
		_set_phase(Phase.STOPPING)
		_sound("engine_stop")


## Anlasser halten (Realistisch). Loslassen kuppelt ein.
func set_starter(held: bool) -> void:
	if held and not starter_held and (phase == Phase.OFF or phase == Phase.STOPPING):
		if not master:
			message.emit("Anlasser: keine Spannung – Hauptschalter an", true)
		else:
			_set_phase(Phase.SPINUP)
			_sound("starter_whine")
	starter_held = held


## Nächster Schalter der Checkliste (Controller, Realistisch): Hauptschalter → Pumpe → Zündung;
## gibt die Beschriftung zurück („“ = alles an).
func next_switch() -> String:
	if not master:
		set_master(true)
		return "Hauptschalter an"
	if not fuel_pump:
		set_fuel_pump(true)
		return "Kraftstoffpumpe an"
	if not magnetos:
		set_magnetos(true)
		return "Zündung an"
	if not mixture:
		set_mixture(true)
		return "Gemisch reich"
	return ""


## Tasten des Spielers (PlayerController). realistic = einzelne Schalter.
func input(realistic: bool, pad: bool, dt: float) -> void:
	var edge := func(a: StringName) -> bool:
		var on := InputMap.has_action(a) and Input.is_action_pressed(a)
		var was: bool = _prev.get(a, false)
		_prev[a] = on
		return on and not was
	var toggle_held := InputMap.has_action(&"engine_toggle") and Input.is_action_pressed(&"engine_toggle")
	if not realistic:
		if edge.call(&"engine_toggle"):
			toggle()
		return
	if pad:
		# Controller: kurz = nächster Schalter, halten = Anlasser, bei laufendem Motor kurz = abstellen
		var was: bool = _prev.get(&"engine_toggle", false)
		_prev[&"engine_toggle"] = toggle_held
		if toggle_held:
			_pad_hold += dt
			if _pad_hold > 0.4 and phase != Phase.RUNNING and next_switch_label() == "":
				set_starter(true)
		elif was:
			if starter_held:
				set_starter(false)
			elif _pad_hold <= 0.4:
				if phase == Phase.RUNNING:
					set_mixture(false)
				else:
					var s := next_switch()
					if s != "":
						message.emit(s, false)
			_pad_hold = 0.0
		return
	if edge.call(&"master_toggle"):
		set_master(not master)
		message.emit("Hauptschalter %s" % ("an" if master else "aus"), false)
	if edge.call(&"fuel_pump_toggle"):
		set_fuel_pump(not fuel_pump)
		message.emit("Kraftstoffpumpe %s" % ("an" if fuel_pump else "aus"), false)
	if edge.call(&"magneto_toggle"):
		set_magnetos(not magnetos)
		message.emit("Zündung %s" % ("an" if magnetos else "aus"), false)
	if edge.call(&"engine_toggle"):
		set_mixture(not mixture if phase != Phase.RUNNING else false)
		message.emit("Gemisch %s" % ("reich" if mixture else "Abstellen"), false)
	var st := InputMap.has_action(&"starter_hold") and Input.is_action_pressed(&"starter_hold")
	if st != starter_held:
		set_starter(st)


func next_switch_label() -> String:
	if not master:
		return "Hauptschalter"
	if not fuel_pump:
		return "Kraftstoffpumpe"
	if not magnetos:
		return "Zündung"
	if not mixture:
		return "Gemisch"
	return ""


func _set_phase(p: int) -> void:
	if p != phase:
		phase = p
		_t = 0.0
		phase_changed.emit(p)


func _physics_process(dt: float) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return
	_t += dt
	# Teleport in die Luft (Neustart, Respawn): warm
	var pos := aircraft.global_position
	if _last_pos != Vector3.INF and pos.distance_to(_last_pos) > TELEPORT_M:
		var t = aircraft.call("telemetry") if aircraft.has_method("telemetry") else null
		if t != null and not t.on_ground and phase != Phase.RUNNING:
			warm()
	_last_pos = pos
	match phase:
		Phase.SPINUP:
			var spin := ARCADE_SPINUP_S if auto_sequence else SPINUP_S
			if auto_sequence or starter_held:
				flywheel = minf(flywheel + dt / spin, 1.0)
			if auto_sequence and flywheel >= 1.0:
				_engage()
			elif not auto_sequence and not starter_held:
				if flywheel >= ENGAGE_MIN:
					_engage()
				else:
					message.emit("Anlasser zu kurz gehalten – Schwungrad zu langsam", true)
					_set_phase(Phase.OFF)
		Phase.CRANK:
			if _t >= (ARCADE_CRANK_S if auto_sequence else CRANK_S * flywheel):
				var why := start_problem()
				auto_sequence = false
				flywheel = 0.0
				if why == "":
					_set_phase(Phase.RUNNING)
					message.emit("Motor läuft", false)
				else:
					_set_phase(Phase.OFF)
					message.emit("Motor springt nicht an: %s" % why, true)
		Phase.RUNNING:
			var dm = aircraft.get("damage")
			if dm != null and dm.fuel.is_empty():
				_set_phase(Phase.STOPPING)
				message.emit("Motor aus: kein Kraftstoff", true)
			elif not magnetos or not mixture:
				_set_phase(Phase.STOPPING)
			_starve = _starve + dt if not fuel_pump else 0.0
			if _starve > PUMP_STARVE_S:
				_set_phase(Phase.STOPPING)
				message.emit("Motor aus: Kraftstoffpumpe aus", true)
				_sound("engine_stop")
		Phase.STOPPING:
			if _t >= STOP_S:
				_set_phase(Phase.OFF)
	_apply()


func _engage() -> void:
	_set_phase(Phase.CRANK)
	_sound("engine_catch" if start_problem() == "" else "engine_stop")


func _apply() -> void:
	var e := _engine()
	if e != null:
		e.running = phase == Phase.RUNNING


func _sound(n: String) -> void:
	if DisplayServer.get_name() == "headless" or aircraft == null or not aircraft.is_inside_tree():
		return
	var d := SoundDirector.instance
	if d != null and is_instance_valid(d):
		d.play_3d(n, aircraft.global_position, "Motor", -2.0, 1.0, 12.0)


## Zustand für HUD/Tests.
func state() -> Dictionary:
	return {"master": master, "fuel_pump": fuel_pump, "magnetos": magnetos, "mixture": mixture,
		"starter": starter_held, "phase": phase, "phase_name": PHASE_NAMES[phase], "flywheel": flywheel}
