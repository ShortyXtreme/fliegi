class_name SpawnManager
extends Node
## Neustart nach Verlust/Ausstieg/Landung (Paket 6, Agent B). Nur Server.
## game.gd registriert jedes Flugzeug einmal mit einer Respawn-Funktion:
##   spawn_manager.register(aircraft, controller, respawn_callable)
## Ablauf: Abschuss (CombatEvents.aircraft_destroyed), Ausstieg oder Flugende am Boden
## (DamageModel.grounded) -> nach MatchRules.respawn_delay (Simulationszeit) respawn_callable.
## Beim Neustart bleibt ein Wrack liegen, bis MatchRules.wreck_lifetime ab Absturz um ist.
## Pilot: überlebt (Bauchlandung, Ausstieg mit Fallschirm) -> gleicher PilotRecord,
## sonst neuer Pilot (Level 1, offene XP verloren).

signal respawned(aircraft: Node3D)
## Neustart geplant (für HUD: Countdown über time_to_respawn()).
signal respawn_scheduled(aircraft: Node3D, delay: float)

## aircraft -> {"controller", "respawn", "timer" (-1 = keiner), "down_since", "down_xf"}
var entries := {}
## Erzeugte Wracks (noch lebend).
var wrecks: Array[Wreck] = []
var _bus_connected := false


func _ready() -> void:
	_connect_bus()


func _connect_bus() -> void:
	if _bus_connected:
		return
	_bus_connected = true
	var bus := CombatEvents.bus()
	bus.aircraft_destroyed.connect(_on_destroyed)
	bus.pilot_ejected.connect(func(a, _p): _schedule(a))


## delay (optional): Callable -> float, Ausfallzeit nur für dieses Flugzeug
## (Paket 14: KI 30–60 s); ohne gilt MatchRules.respawn_delay.
func register(aircraft: Node3D, controller: Controller, respawn: Callable,
		delay: Callable = Callable()) -> void:
	_connect_bus()
	entries[aircraft] = {"controller": controller, "respawn": respawn, "timer": -1.0,
		"down_since": -1.0, "down_xf": Transform3D.IDENTITY, "burning": false, "delay": delay}
	if aircraft.get("pilot") == null:
		_assign_pilot(aircraft, PilotRecord.new())
	var d = aircraft.get("damage")
	if d is DamageModel and not d.grounded.is_connected(_on_grounded):
		d.grounded.connect(_on_grounded.bind(aircraft))
		d.was_reset.connect(_on_reset.bind(aircraft))


func unregister(aircraft: Node3D) -> void:
	var d = aircraft.get("damage") if is_instance_valid(aircraft) else null
	if d is DamageModel and d.grounded.is_connected(_on_grounded):
		d.grounded.disconnect(_on_grounded)
		d.was_reset.disconnect(_on_reset)
	entries.erase(aircraft)


## Sekunden bis zum Neustart, -1 = keiner geplant.
func time_to_respawn(aircraft: Node3D) -> float:
	return entries[aircraft]["timer"] if entries.has(aircraft) else -1.0


## Sofortiger Neustart (Debugtasten R/T gehen weiter direkt über game.gd).
func respawn_now(aircraft: Node3D) -> void:
	if not Authority.is_server() or not entries.has(aircraft):
		return
	var e: Dictionary = entries[aircraft]
	_leave_wreck(aircraft, e)
	_next_pilot(aircraft)
	e.timer = -1.0
	var cb: Callable = e["respawn"]
	if cb.is_valid():
		cb.call()
	e.timer = -1.0
	e.down_since = -1.0
	respawned.emit(aircraft)


func _physics_process(dt: float) -> void:
	if not Authority.is_server():
		return
	for a in entries.keys():
		if not is_instance_valid(a):
			entries.erase(a)
			continue
		var e: Dictionary = entries[a]
		if e.down_since >= 0.0:
			e.down_since += dt
		if e.timer >= 0.0:
			e.timer -= dt
			if e.timer <= 0.0:
				respawn_now(a)
	for i in range(wrecks.size() - 1, -1, -1):
		if not is_instance_valid(wrecks[i]):
			wrecks.remove_at(i)


func _on_destroyed(victim: Node, _killer: Node, _cause: int) -> void:
	_schedule(victim)


func _on_grounded(outcome: int, aircraft: Node3D) -> void:
	if not entries.has(aircraft):
		return
	var e: Dictionary = entries[aircraft]
	if outcome == DamageModel.Outcome.CRASHED and e.down_since < 0.0:
		e.down_since = 0.0
	_schedule(aircraft)


## Debug-Neustart (R/T) über Aircraft.place(): geplanten Neustart verwerfen.
func _on_reset(aircraft: Node3D) -> void:
	if entries.has(aircraft):
		entries[aircraft].timer = -1.0


func _schedule(aircraft: Node) -> void:
	if not Authority.is_server() or not entries.has(aircraft):
		return
	var e: Dictionary = entries[aircraft]
	if e.timer >= 0.0:
		return
	var dl: Callable = e.get("delay", Callable())
	e.timer = float(dl.call()) if dl.is_valid() else MatchRules.respawn_delay
	var d = aircraft.get("damage")
	if d is DamageModel:
		e.burning = d.is_burning()
	respawn_scheduled.emit(aircraft, e.timer)


## Absturzstelle mit Wrack markieren (nur nach Absturz/Abschuss am Boden).
func _leave_wreck(aircraft: Node3D, e: Dictionary) -> void:
	var d = aircraft.get("damage")
	if not (d is DamageModel) or d.outcome != DamageModel.Outcome.CRASHED:
		return
	var parent := aircraft.get_parent()
	if parent == null:
		return
	var life := maxf(MatchRules.wreck_lifetime - maxf(e.down_since, 0.0), 0.5)
	wrecks.append(Wreck.spawn_at(parent, aircraft.global_transform, life, e.burning))


## Pilot für den nächsten Flug: Überlebende behalten ihren Datensatz.
func _next_pilot(aircraft: Node3D) -> void:
	var rec: PilotRecord = aircraft.get("pilot")
	if rec == null or not rec.alive:
		rec = PilotRecord.new()
	rec.ejected = false
	_assign_pilot(aircraft, rec)


func _assign_pilot(aircraft: Node3D, rec: PilotRecord) -> void:
	aircraft.set("pilot", rec)
	aircraft.set("crew_level", rec.level)
