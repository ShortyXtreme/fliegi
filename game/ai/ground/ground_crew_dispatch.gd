class_name GroundCrewDispatch
extends Node
## M3 (Strang G / Paket 7a): Automatik des Bodenpersonals eines Platzes. Beobachtet die
## Maschinen der eigenen Nation; steht eine auf dem Platz (am Boden, < 1 m/s) und braucht
## Treibstoff, Munition oder Reparatur, legt sie die Abfertigung im JobBoard an – ohne Befehl.
## Priorität: Spieler-Maschine > KI-Maschine (Alarm über Turnaround.quick_service).
## Die GroundCrewBrain-Instanzen nehmen sich die Jobs selbst.

signal announced(text: String, aircraft: Node)

var board: JobBoard = null
var depot: FuelSource = null
var store: AmmoStore = null
var nation_id: int = Nations.BLUE
## Beobachtete Maschinen (leer = alle Aircraft unter watch_root).
var aircraft: Array = []
var watch_root: Node = null
## Maschinen, die als Spieler-Maschine gelten (zusätzlich zu menschlich besetztem Pilotensitz).
var player_aircraft: Array = []
## Lagepunkte für Wege (Szenenkoordinaten). Tankwagen steht ohne Fahrzeug am Lager.
var depot_pos := Vector3.ZERO
var truck_pos := Vector3.ZERO
var cart_pos := Vector3.ZERO
var has_cart_pos := false
var crew_spawn := Vector3.ZERO
## Umkreis des Platzes um center (0 = ohne Prüfung).
var center := Vector3.ZERO
var radius := 0.0
var fuel_target := 1.0
var crews: Array = []
## Fahrzeuge des Platzes (Strang H). Gesetzt: Tanken aus truck.tank, Munition aus cart.store.
var fuel_truck: FuelTruck = null
var ammo_cart: AmmoCart = null
var _known := {}

## Nachtanken erst ab dieser Lücke (Leerlauf verbraucht etwas, kein Dauer-Nachfüllen).
const TOP_UP_MARGIN := 0.03


## Platz aus AirfieldLayout übernehmen.
func setup_from_layout(l: AirfieldLayout) -> void:
	if l == null:
		return
	depot_pos = l.to_scene(l.fuel_depot)
	truck_pos = l.to_scene(l.vehicle_spawns[0]) if l.vehicle_spawns.size() > 0 else depot_pos
	crew_spawn = l.to_scene(l.crew_spawn)
	center = l.to_scene(l.parking_positions[0]) if l.parking_count() > 0 else depot_pos
	radius = 600.0
	nation_id = l.nation_id
	if depot is FuelDepot:
		depot.position = depot_pos
	if store is AmmoBunker:
		store.position = l.to_scene(l.ammo_bunker)


func _physics_process(dt: float) -> void:
	tick(dt)


func tick(_dt: float) -> void:
	if not Authority.is_server():
		return
	if board == null:
		board = JobBoard.current
	if board == null:
		return
	for a in _watched():
		_check(a)


func is_parked(a: Aircraft) -> bool:
	return a.seat_on_ground() and a.seat_speed() < 1.0 and not a.damage.is_destroyed \
		and (radius <= 0.0 or a.global_position.distance_to(center) <= radius)


func needs_service(a: Aircraft) -> bool:
	var f := a.damage.fuel
	if f.fraction() < fuel_target - TOP_UP_MARGIN:
		return true
	if a.weapons.ammo() < a.weapons.ammo_max():
		return true
	for z in DamageModel.Zone.COUNT:
		if a.damage.can_repair(z):
			return true
	return false


func priority_for(a: Aircraft) -> int:
	if is_player_aircraft(a):
		return GroundCrewBrain.Priority.PLAYER_AIRCRAFT * 10
	return GroundCrewBrain.Priority.AI_AIRCRAFT * 10


func is_player_aircraft(a: Aircraft) -> bool:
	return player_aircraft.has(a) or a.pilot_seat.is_human_occupied()


func _check(a: Aircraft) -> void:
	if not is_parked(a):
		if _known.has(a):
			_known.erase(a)
			if a.seat_speed() > 3.0:
				board.clear_finished(a)
		return
	if not board.open_jobs(a).is_empty() or not needs_service(a):
		return
	var ids := board.plan_service(a, fuel_source(), ammo_store(), {"priority": priority_for(a),
		"fuel_target": fuel_target, "fuel_node": fuel_truck})
	if not ids.is_empty() and not _known.has(a):
		_known[a] = true
		announced.emit("%s gelandet" % _name_of(a), a)


func fuel_source() -> FuelSource:
	return fuel_truck.tank if fuel_truck != null and is_instance_valid(fuel_truck) else depot


func ammo_store() -> AmmoStore:
	return ammo_cart.store if ammo_cart != null and is_instance_valid(ammo_cart) else store


## Befehl (Befehlsrad): Jobs für a nach Befehl anlegen. Rückgabe: neue Job-Ids.
func plan_for(a: Aircraft, cmd: int) -> Array:
	if board == null or a == null:
		return []
	var C := GroundCrewBrain.Command
	if cmd == C.QUICK_SERVICE:
		return Turnaround.quick_service(board, a, fuel_source(), ammo_store())
	var o := {"priority": GroundCrewBrain.Priority.PLAYER_AIRCRAFT * 10, "fuel_target": fuel_target,
		"fuel_node": fuel_truck, "fuel": cmd in [C.FULL_SERVICE, C.FUEL_ONLY],
		"ammo": cmd in [C.FULL_SERVICE, C.AMMO_ONLY], "repair": cmd in [C.FULL_SERVICE, C.REPAIR]}
	return board.plan_service(a, fuel_source(), ammo_store(), o)


func _watched() -> Array:
	var out := []
	var src: Array = aircraft
	if src.is_empty() and watch_root != null:
		src = watch_root.find_children("*", "Aircraft", true, false)
	for a in src:
		if a is Aircraft and is_instance_valid(a) and a.nation_id == nation_id:
			out.append(a)
	return out


func _name_of(a: Aircraft) -> String:
	if a.pilot != null and a.pilot.get("display_name") != null:
		return str(a.pilot.get("display_name"))
	var n: String = Nations.NAMES[a.nation_id] if Nations.is_valid(a.nation_id) else "Maschine"
	return "%s %d" % [n, maxi(a.entity_id, 1)]
