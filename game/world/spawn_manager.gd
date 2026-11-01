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
##
## M3 Paket 10 (Strang C): Spawn am Boden. register_ground(aircraft, controller, layout)
## meldet ein Flugzeug mit Neustart auf einem freien Abstellplatz an (kein Spawn in der
## Luft). spawn_on_ground(aircraft, layout, kind) setzt es dorthin, mit ServiceState nach
## MatchRules (FIRST 50 %/voll, AFTER_LOSS 15 %/0, AFTER_LANDING Restzustand), und richtet
## bei KI (AIPilotBrain) die Flugplatz-Phasen ab PARKED ein.

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


## M3: Anmeldung mit Neustart am Boden (Abstellplatz von layout). Der erste Spawn
## (spawn_on_ground(..., FIRST)) ist Sache des Aufrufers; jeder Neustart danach läuft
## als AFTER_LOSS bzw. nach respawn_after_landing() als AFTER_LANDING.
func register_ground(aircraft: Node3D, controller: Controller, layout: AirfieldLayout,
		delay: Callable = Callable()) -> void:
	register(aircraft, controller, func(): spawn_on_ground(aircraft, layout, next_start_kind(aircraft)),
		delay)
	entries[aircraft]["layout"] = layout
	entries[aircraft]["kind"] = MatchRules.StartKind.AFTER_LOSS


## Startart für den nächsten Neustart dieses Flugzeugs.
func next_start_kind(aircraft: Node3D) -> int:
	if entries.has(aircraft):
		return int(entries[aircraft].get("kind", MatchRules.StartKind.AFTER_LOSS))
	return MatchRules.StartKind.AFTER_LOSS


## Neustart nach Landung am eigenen Platz (Restzustand bleibt), z. B. „neue Maschine“
## aus dem Menü oder Paket 14. Sofort, ohne Wrack.
func respawn_after_landing(aircraft: Node3D) -> void:
	if not entries.has(aircraft):
		return
	entries[aircraft]["kind"] = MatchRules.StartKind.AFTER_LANDING
	respawn_now(aircraft)
	entries[aircraft]["kind"] = MatchRules.StartKind.AFTER_LOSS


## Flugzeug auf einen Abstellplatz von layout setzen (spot < 0 = freien wählen).
## Rückgabe: Platzindex, -1 = kein Server/kein Platz.
func spawn_on_ground(aircraft: Node3D, layout: AirfieldLayout, kind: int, spot: int = -1) -> int:
	if not Authority.is_server() or layout == null or layout.parking_count() == 0:
		return -1
	var s := spot if spot >= 0 else free_spot(layout, aircraft)
	if s < 0:
		s = _least_crowded_spot(layout, aircraft)
	var xf := layout.parking_transform(s)
	if aircraft is Aircraft:
		(aircraft as Aircraft).place_on_ground(xf.origin, -xf.basis.z, false, ServiceState.for_start(kind))
	var c = entries[aircraft]["controller"] if entries.has(aircraft) else null
	if c is AIPilotBrain:
		var br := c as AIPilotBrain
		if br.airfield == null:
			br.airfield = AirfieldPhases.new()
		br.airfield.setup(layout, RunwayControl.find_or_create(self, layout.airfield_index), s,
			AirfieldPhases.Phase.PARKED)
	return s


## Erster freier Abstellplatz (kein Flugzeug/Wrack näher als PARKING_CLEARANCE, nicht von
## einer heimkehrenden KI belegt). -1 = alle belegt.
const PARKING_CLEARANCE := 14.0
func free_spot(layout: AirfieldLayout, exclude: Node3D = null) -> int:
	var others := _ground_bodies(exclude)
	var reserved := AirfieldPhases.reserved_spots(layout, exclude)
	for s in layout.parking_count():
		if s in reserved:
			continue
		var p := layout.parking_transform(s).origin
		var ok := true
		for o in others:
			if Vector2(o.x - p.x, o.z - p.z).length() < PARKING_CLEARANCE:
				ok = false
				break
		if ok:
			return s
	return -1


func _least_crowded_spot(layout: AirfieldLayout, exclude: Node3D) -> int:
	var others := _ground_bodies(exclude)
	var best := 0
	var best_d := -1.0
	for s in layout.parking_count():
		var p := layout.parking_transform(s).origin
		var dmin := INF
		for o in others:
			dmin = minf(dmin, Vector2(o.x - p.x, o.z - p.z).length())
		if dmin > best_d:
			best_d = dmin
			best = s
	return best


func _ground_bodies(exclude: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var seen := {}
	for a in entries.keys():
		if is_instance_valid(a) and a != exclude:
			seen[a] = true
			out.append(a.global_position)
	for a in AirfieldPhases.fleet():
		if a != exclude and not seen.has(a):
			out.append(a.global_position)
	for w in wrecks:
		if is_instance_valid(w):
			out.append(w.global_position)
	return out


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
	e["kind"] = MatchRules.StartKind.AFTER_LOSS
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
