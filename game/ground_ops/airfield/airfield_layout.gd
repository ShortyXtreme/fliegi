class_name AirfieldLayout
extends Resource
## Bodenplan eines Platzes (M3 Paket 8, Strang C). Daten: ground_ops/airfield/data/
## airfield_<i>.tres (erzeugt mit tools/build_airfield_layouts.gd aus make_default()).
## Alle Punkte LOKAL zum Platzmittelpunkt (Gelände-Mitte der Piste, y = 0); Szenen-
## koordinaten über to_scene() (setzt center und Höhe aus WorldGround.height_at).
## Gestartet und gelandet wird Richtung -Z (TerrainWorld.RUNWAY_DIR).
##
## Plan (Draufsicht, Norden = -Z oben):
##   Piste x = 0 (±20 m), z = +450 … -450, Schwelle z = +430.
##   Rollweg x = -27 von z = -300 bis zum Haltepunkt (-27, 462) im Süden, dann Bogen
##   über (-20, 476) und (-6, 472) auf den Pistenanfang (0, 445).
##   Abstellplätze x = -45, z = 245 … 420 (Abstand 35 m), Nase nach Süden (+Z), d. h.
##   rollen hinaus und herein fließt immer Richtung Haltepunkt, ohne Wenden.
##   Zufahrt (parking_nodes): Rollweg-Knoten 17,5 m südlich des Platzes (hinaus);
##   Einfahrt (parking_in_nodes): Knoten 17,5 m nördlich (herein).
##   Pistenausfahrten (exit_nodes) bei z = 100, -100, -300 (Knoten auf der Pistenmitte).

@export var airfield_index := 0
@export var nation_id: int = Nations.NONE
@export var runway_start := Vector3.ZERO       # Schwelle (Startbeginn)
@export var runway_end := Vector3.ZERO
@export var runway_width := 40.0
## Abstellplätze: Position und Nasenrichtung (Einheitsvektor, waagerecht).
@export var parking_positions: PackedVector3Array = []
@export var parking_headings: PackedVector3Array = []
## Rollweg-Graph: Knoten und Kanten als Indexpaare [a0, b0, a1, b1, ...].
@export var taxi_nodes: PackedVector3Array = []
@export var taxi_edges: PackedInt32Array = []
## Knoten-Index des Haltepunkts vor der Piste und des Pistenanfangs.
@export var hold_node := -1
@export var runway_node := -1
## Knoten-Index der Zufahrt je Abstellplatz (hinaus rollen).
@export var parking_nodes: PackedInt32Array = []
## Knoten-Index der Einfahrt je Abstellplatz (herein rollen, nördlich des Platzes).
@export var parking_in_nodes: PackedInt32Array = []
## Pistenausfahrten: Knoten auf der Pistenmitte (mit Rollweg verbunden).
@export var exit_nodes: PackedInt32Array = []
@export var fuel_depot := Vector3.ZERO
@export var ammo_bunker := Vector3.ZERO
@export var hangar := Vector3.ZERO
@export var crew_spawn := Vector3.ZERO
@export var vehicle_spawns: PackedVector3Array = []
## Platzrunde: Höhe über Platz (m) und Seite (+1 = Osten, Rechtsplatzrunde).
@export var pattern_altitude := 300.0
@export var pattern_side := 1.0

## Laufzeit (nicht gespeichert): Platzmittelpunkt in Szenenkoordinaten.
var center := Vector3.ZERO


func to_scene(local: Vector3) -> Vector3:
	var p := center + Vector3(local.x, 0.0, local.z)
	p.y = WorldGround.height_at(p.x, p.z) + local.y
	return p


## Szenenpunkt -> lokale Koordinaten (y = Höhe über center).
func to_local(scene: Vector3) -> Vector3:
	return scene - center


func parking_count() -> int:
	return parking_positions.size()


## Abstellplatz i in Szenenkoordinaten: Ursprung auf dem Boden, -Z = Nasenrichtung.
func parking_transform(i: int) -> Transform3D:
	var p := to_scene(parking_positions[i])
	var h := parking_headings[i] if i < parking_headings.size() else Vector3.FORWARD
	return Transform3D(Basis.looking_at(h.normalized(), Vector3.UP), p)


## Startrichtung (Einheitsvektor, waagerecht).
func runway_dir() -> Vector3:
	var d := runway_end - runway_start
	d.y = 0.0
	return d.normalized() if d.length() > 1.0 else Vector3.FORWARD


func runway_length() -> float:
	return runway_start.distance_to(runway_end)


## Nachbarn eines Rollweg-Knotens.
func taxi_neighbors(n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in range(0, taxi_edges.size() - 1, 2):
		if taxi_edges[k] == n:
			out.append(taxi_edges[k + 1])
		elif taxi_edges[k + 1] == n:
			out.append(taxi_edges[k])
	return out


## Kürzester Weg (Dijkstra) von Knoten a nach b als Knotenliste (inkl. a und b);
## leer, wenn nicht verbunden.
func taxi_path(a: int, b: int) -> PackedInt32Array:
	var n := taxi_nodes.size()
	if a < 0 or b < 0 or a >= n or b >= n:
		return PackedInt32Array()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var done := PackedByteArray()
	done.resize(n)
	dist[a] = 0.0
	for _i in n:
		var u := -1
		for k in n:
			if done[k] == 0 and (u < 0 or dist[k] < dist[u]):
				u = k
		if u < 0 or dist[u] == INF:
			break
		done[u] = 1
		if u == b:
			break
		for v in taxi_neighbors(u):
			var d := dist[u] + taxi_nodes[u].distance_to(taxi_nodes[v])
			if d < dist[v]:
				dist[v] = d
				prev[v] = u
	if dist[b] == INF:
		return PackedInt32Array()
	var out := PackedInt32Array()
	var c := b
	while c >= 0:
		out.insert(0, c)
		c = prev[c]
	return out


## Lokale Punkte einer Knotenliste.
func path_points(nodes: PackedInt32Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in nodes:
		out.append(taxi_nodes[k])
	return out


## Ist der Graph zusammenhängend (alle Knoten von hold_node aus erreichbar)?
func is_connected_graph() -> bool:
	if taxi_nodes.is_empty() or hold_node < 0:
		return false
	var seen := {hold_node: true}
	var todo := [hold_node]
	while not todo.is_empty():
		var u: int = todo.pop_back()
		for v in taxi_neighbors(u):
			if not seen.has(v):
				seen[v] = true
				todo.append(v)
	return seen.size() == taxi_nodes.size()


## Bodenplan passend zu TerrainWorld._build_airfields (Hangars bei x = -80 und
## z = Schwelle -120 … -216, Turm bei (-70, Schwelle + 30)). Siehe Plan oben.
static func make_default(index: int, runway_length_m: float, runway_width_m: float = 40.0,
		nation: int = Nations.NONE) -> AirfieldLayout:
	var l := AirfieldLayout.new()
	l.airfield_index = index
	l.nation_id = nation
	l.runway_width = runway_width_m
	var half := runway_length_m * 0.5
	var sz := half - 20.0                       # Schwelle (+430 bei 900 m)
	l.runway_start = Vector3(0, 0, sz)
	l.runway_end = Vector3(0, 0, -half + 20.0)
	var tx := -27.0                             # Rollweg-Mitte
	var px := -45.0                             # Abstellplätze
	var spacing := 35.0
	var spots := 6
	var z0 := sz - 10.0 - (spots - 1) * spacing   # südlichster Platz bei z = sz - 10
	# Knoten 0: Pistenanfang (auf der Mittellinie, kurz hinter der Schwelle),
	# 1, 2: Einroll-Bogen, 3: Haltepunkt.
	l.taxi_nodes.append(Vector3(0, 0, sz + 15.0))
	l.taxi_nodes.append(Vector3(-6, 0, sz + 42.0))
	l.taxi_nodes.append(Vector3(-20, 0, sz + 46.0))
	l.taxi_nodes.append(Vector3(tx, 0, sz + 32.0))
	l.taxi_edges.append_array([0, 1, 1, 2, 2, 3])
	l.runway_node = 0
	l.hold_node = 3
	# Rollweg nach Norden: Knoten zwischen den Plätzen (z_k + spacing/2), südlich -> nördlich.
	var prev := 3
	var mid := {}                               # k -> Knotenindex bei z_k + spacing/2
	for k in range(spots - 1, -2, -1):
		var z := z0 + k * spacing + spacing * 0.5
		if z >= sz + 32.0 - 1.0:
			continue
		l.taxi_nodes.append(Vector3(tx, 0, z))
		var n := l.taxi_nodes.size() - 1
		l.taxi_edges.append_array([prev, n])
		mid[k] = n
		prev = n
	# weiter nach Norden mit Pistenausfahrten
	for z in [100.0, -100.0, -300.0]:
		l.taxi_nodes.append(Vector3(tx, 0, z))
		var n := l.taxi_nodes.size() - 1
		l.taxi_edges.append_array([prev, n])
		prev = n
		l.taxi_nodes.append(Vector3(0, 0, z - 15.0))
		var e := l.taxi_nodes.size() - 1
		l.taxi_edges.append_array([n, e])
		l.exit_nodes.append(e)
	for k in spots:
		var z := z0 + k * spacing
		l.parking_positions.append(Vector3(px, 0, z))
		l.parking_headings.append(Vector3(0, 0, 1))
		l.parking_nodes.append(mid[k] if mid.has(k) else 3)
		l.parking_in_nodes.append(mid[k - 1])
	l.fuel_depot = Vector3(-110.0, 0, sz - 20.0)
	l.ammo_bunker = Vector3(-115.0, 0, sz - 260.0)
	l.hangar = Vector3(-80.0, 0, sz - 120.0)
	l.crew_spawn = Vector3(-60.0, 0, sz - 60.0)
	l.vehicle_spawns = PackedVector3Array([Vector3(-95.0, 0, sz - 30.0), Vector3(-95.0, 0, sz - 245.0)])
	return l
