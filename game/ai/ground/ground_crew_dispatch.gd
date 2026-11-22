class_name GroundCrewDispatch
extends Node
## M3 (Strang G / Paket 7a): Automatik des Bodenpersonals eines Platzes. Beobachtet die
## Maschinen der eigenen Nation; steht eine auf dem Platz (am Boden, < 1 m/s) und braucht
## Treibstoff, Munition oder Reparatur, legt sie die Abfertigung im JobBoard an – ohne Befehl.
## Priorität: Spieler-Maschine > KI-Maschine (Alarm über Turnaround.quick_service).
## Die GroundCrewBrain-Instanzen nehmen sich die Jobs selbst.

signal announced(text: String, aircraft: Node)
## M3.5: Funkmeldung des Personals („Mechaniker A: Tanken erledigt – räumt auf“).
signal crew_report(text: String, brain: Node)

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
## M3.4: Maschinen ohne Automatik-Abfertigung (Tutorial: der Spieler bereitet selbst vor;
## Befehle über das Befehlsrad gelten weiter).
var auto_exclude: Array = []

## M3.5: Stellplätze der Wagen (beim ersten Tick gemerkt bzw. gesetzt).
var _home := {}
## Letzte Meldungen (Text, für HUD/Tests), neueste zuletzt.
var reports: Array = []

## Nachtanken erst ab dieser Lücke (Leerlauf verbraucht etwas, kein Dauer-Nachfüllen).
const TOP_UP_MARGIN := 0.03


## Paket 14: Fahrspur westlich der Abstellplätze (Platz-Koordinaten x), null = ohne.
## M3.1: 12 m westlich der Abstellplätze (Wagen am Flugzeug halten bei x = -69,5 und
## blockieren die Spur nicht), Hallen-Tore bei x = -83 (M3.4: Piste 60 m, alles 10 m westlicher).
const LANE_X := -74.0
## Auf die Spur schräg vorwärts einfädeln bzw. vor dem Ziel schräg ausfädeln (m längs).
const LANE_IN := 8.0
const LANE_OUT := 10.0
var layout: AirfieldLayout = null


## Zwischenpunkte für eine Fahrt from -> to (Szenenkoordinaten): schräg auf die Fahrspur,
## längs, schräg zum Ziel. Kurze Fahrten (< 15 m längs) direkt.
func drive_route(from: Vector3, to: Vector3) -> Array:
	if layout == null:
		return []
	var a := layout.to_local(from)
	var b := layout.to_local(to)
	if absf(a.z - b.z) < 15.0:
		return []
	var dir := signf(b.z - a.z)
	var out := []
	var z_in := a.z + dir * LANE_IN
	var z_out := b.z - dir * LANE_OUT
	if absf(a.x - LANE_X) > 3.0 and (z_out - z_in) * dir > 0.0:
		out.append(layout.to_scene(Vector3(LANE_X, 0, z_in)))
	out.append(layout.to_scene(Vector3(LANE_X, 0, z_out if absf(b.x - LANE_X) > 3.0 else b.z)))
	for i in out.size():
		out[i].y = WorldGround.height_at(out[i].x, out[i].z)
	return out


## Halteplatz eines Wagens neben der Maschine a: auf der Seite der Fahrspur, Tankwagen auf Höhe
## des Tankdeckels, Munitionswagen weiter hinten (Richtung Heck). null = ohne Layout.
const SPOT_SIDE := 8.5
const SPOT_CART_BACK := 9.5
func vehicle_spot(a: Node3D, cart: bool):
	if layout == null or a == null:
		return null
	var l := layout.to_local(a.global_position)
	var side := Vector3(signf(LANE_X - l.x), 0.0, 0.0)
	var fwd := -a.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var p := a.global_position + side * SPOT_SIDE - (fwd * SPOT_CART_BACK if cart else Vector3.ZERO)
	p.y = WorldGround.height_at(p.x, p.z)
	return p


## Platz aus AirfieldLayout übernehmen.
func setup_from_layout(l: AirfieldLayout) -> void:
	if l == null:
		return
	layout = l
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
	for v in [fuel_truck, ammo_cart]:
		if v != null and is_instance_valid(v) and v.is_inside_tree() and not _home.has(v):
			_home[v] = v.global_position
	if not Authority.is_server():
		return
	if board == null:
		board = JobBoard.current
	if board == null:
		return
	for a in _watched():
		_check(a)
	_check_refill()


## Paket 14: „Wagen nachfüllen“ – fast leerer Tankwagen wird am Lager wieder befüllt
## (RefuelJob mit dest_source = Tank des Wagens, Priorität REFILL_VEHICLE, Mengen-Erhalt).
const REFILL_BELOW := 0.35
func _check_refill() -> void:
	if fuel_truck == null or not is_instance_valid(fuel_truck) or depot == null:
		return
	var tank: FuelSource = fuel_truck.tank
	if tank.total() >= FuelTruck.TANK_CAPACITY * REFILL_BELOW:
		return
	for j in board.open_jobs():
		if j is RefuelJob and (j.dest_source == tank or j.source == tank):
			return
	var g: StringName = tank.grade() if tank.total() > 0.5 else FuelSystem.GRADE_AVIATION
	if depot.available(g) < 1.0:
		return
	var rj := RefuelJob.new()
	rj.target = fuel_truck
	rj.source = depot
	rj.dest_source = tank
	rj.grade = g
	rj.allow_fallback = false
	rj.target_fraction = 1.0
	rj.priority = GroundCrewBrain.Priority.REFILL_VEHICLE * 10
	board.add_job(rj)


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


## Maschinen, die seit der letzten Abfertigung in der Luft waren (M3.2).
var _airborne := {}


func is_player_aircraft(a: Aircraft) -> bool:
	return player_aircraft.has(a) or a.pilot_seat.is_human_occupied()


func _check(a: Aircraft) -> void:
	if not a.seat_on_ground() and a.seat_speed() > 20.0:
		_airborne[a] = true      # M3.2: „gelandet“ nur nach echtem Flug melden
	if not is_parked(a):
		if _known.has(a):
			_known.erase(a)
			if a.seat_speed() > 3.0:
				board.clear_finished(a)
		if a.seat_speed() > 3.0 or not a.seat_on_ground():
			for j in board.open_jobs(a):   # Paket 14: Maschine rollt/fliegt weg -> Abfertigung abbrechen
				board.cancel(j.id)
		return
	if not board.open_jobs(a).is_empty() or not needs_service(a):
		return
	if auto_exclude.has(a):
		# M3.5: Selbstbedienung – Jobs für den Spieler anlegen, die das KI-Personal nicht nimmt
		for id in board.plan_service(a, fuel_source(), ammo_store(), {"priority": priority_for(a),
				"fuel_target": fuel_target, "fuel_node": fuel_truck}):
			board.get_job(id).reserved = true
		return
	var ids := board.plan_service(a, fuel_source(), ammo_store(), {"priority": priority_for(a),
		"fuel_target": fuel_target, "fuel_node": fuel_truck})
	if not ids.is_empty() and not _known.has(a):
		_known[a] = true
		var landed := _airborne.has(a)
		_airborne.erase(a)
		announced.emit(("%s gelandet" if landed else "%s wird abgefertigt") % _name_of(a), a)


func fuel_source() -> FuelSource:
	return fuel_truck.tank if fuel_truck != null and is_instance_valid(fuel_truck) else depot


func ammo_store() -> AmmoStore:
	return ammo_cart.store if ammo_cart != null and is_instance_valid(ammo_cart) else store


## Paket 14: Ziel für „Tankwagen zu mir“/„Folgen“ (Spielerfigur).
var follow_target: Node3D = null


## Befehlsrad (GroundHud.issue_command -> dispatch.command): verteilt an das Personal des
## Platzes. Job-Befehle ohne Ziel gelten der Spieler-Maschine; „Voll abfertigen“ ohne Ziel
## schaltet zurück auf Automatik. Rückgabe: Anzahl Empfänger.
## M3.5: crew = einzelner Mechaniker (GroundCrewBrain) oder null = alle.
func command(cmd: int, target: Node, crew: Node = null) -> int:
	var C := GroundCrewBrain.Command
	var t: Node = target
	if cmd == C.TRUCK_TO_ME or cmd == C.FOLLOW:
		t = follow_target if follow_target != null and is_instance_valid(follow_target) else target
	elif t == null and cmd not in [C.FULL_SERVICE, C.PAUSE, C.TRUCK_HOME, C.CART_HOME] and not player_aircraft.is_empty():
		t = player_aircraft[0]
	if cmd == C.AUTO and t is Aircraft:
		set_self_service(t, false)
	var n := GroundCrewBrain.issue(cmd, t, [crew] if crew != null and crews.has(crew) else crews)
	if n == 0:
		report("Funk: Befehl „%s“ nicht möglich" % GroundCrewBrain.COMMAND_LABELS[cmd], null)
	return n


## Meldung des Personals (Funk), Signal crew_report.
func report(text: String, brain: Node) -> void:
	reports.append(text)
	if reports.size() > 20:
		reports.pop_front()
	crew_report.emit(text, brain)


## Stellplatz eines Wagens (Startposition).
func home_of(v: Node3D) -> Vector3:
	if not _home.has(v):
		_home[v] = v.global_position
	return _home[v]


func set_home(v: Node3D, p: Vector3) -> void:
	_home[v] = p


## Selbstbedienung (Automatik für a aus): Offene, unbearbeitete KI-Jobs werden für den Spieler
## reserviert; aus = Reservierung aufheben, Automatik übernimmt wieder.
func set_self_service(a: Node, on: bool) -> void:
	if a == null:
		return
	auto_exclude.erase(a)
	if on:
		auto_exclude.append(a)
	if board == null:
		board = JobBoard.current
	if board == null:
		return
	for j in board.open_jobs(a):
		if on:
			# KI-Personal ohne Auftrag gibt die Jobs dieser Maschine ab (laufendes Pumpen läuft weiter)
			if j.worker != null and is_instance_valid(j.worker) and board.is_ai_worker(j.worker) \
					and j.for_worker == null:
				board.release(j.id, j.worker)
			if j.worker == null or not is_instance_valid(j.worker):
				j.reserved = j.for_worker == null
		else:
			j.reserved = false


func is_self_service(a: Node) -> bool:
	return auto_exclude.has(a)


## Befehl (Befehlsrad): Jobs für a nach Befehl anlegen. Rückgabe: neue Job-Ids.
func plan_for(a: Aircraft, cmd: int) -> Array:
	if board == null or a == null:
		return []
	var C := GroundCrewBrain.Command
	if cmd == C.QUICK_SERVICE:
		for j in board.open_jobs(a):
			j.reserved = false
		return Turnaround.quick_service(board, a, fuel_source(), ammo_store())
	var o := {"priority": GroundCrewBrain.Priority.PLAYER_AIRCRAFT * 10, "fuel_target": fuel_target,
		"fuel_node": fuel_truck, "fuel": cmd in [C.FULL_SERVICE, C.FUEL_ONLY],
		"ammo": cmd in [C.FULL_SERVICE, C.AMMO_ONLY], "repair": cmd in [C.FULL_SERVICE, C.REPAIR]}
	# M3.5: reservierte (Selbstbedienungs-)Jobs dieser Art gibt der Befehl an das Personal frei
	for j in board.open_jobs(a):
		if (j is RefuelJob and o.fuel) or (j is RearmJob and o.ammo) or (j is RepairJob and o.repair):
			j.reserved = false
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
