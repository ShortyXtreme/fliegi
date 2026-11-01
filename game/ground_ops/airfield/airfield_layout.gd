class_name AirfieldLayout
extends Resource
## M3 Vertrag (Paket 0b, gehört Strang C / Paket 8 inkl. .tres): Bodenplan eines Platzes.
## Alle Punkte LOKAL zum Platzmittelpunkt (Gelände-Mitte der Piste, y = 0); Szenen-
## koordinaten über to_scene() (setzt center und Höhe aus WorldGround.height_at).
## TerrainWorld.airfield_layout(i) lädt res://ground_ops/airfield/data/airfield_<i>.tres
## oder erzeugt mit make_default() einen Ersatzplan passend zu den M2-Gebäuden.
## Gestartet wird Richtung -Z (TerrainWorld.RUNWAY_DIR).

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
## Knoten-Index der Zufahrt je Abstellplatz.
@export var parking_nodes: PackedInt32Array = []
@export var fuel_depot := Vector3.ZERO
@export var ammo_bunker := Vector3.ZERO
@export var hangar := Vector3.ZERO
@export var crew_spawn := Vector3.ZERO
@export var vehicle_spawns: PackedVector3Array = []

## Laufzeit (nicht gespeichert): Platzmittelpunkt in Szenenkoordinaten.
var center := Vector3.ZERO


func to_scene(local: Vector3) -> Vector3:
	var p := center + Vector3(local.x, 0.0, local.z)
	p.y = WorldGround.height_at(p.x, p.z) + local.y
	return p


func parking_count() -> int:
	return parking_positions.size()


## Abstellplatz i in Szenenkoordinaten: Ursprung auf dem Boden, -Z = Nasenrichtung.
func parking_transform(i: int) -> Transform3D:
	var p := to_scene(parking_positions[i])
	var h := parking_headings[i] if i < parking_headings.size() else Vector3.FORWARD
	return Transform3D(Basis.looking_at(h.normalized(), Vector3.UP), p)


## Nachbarn eines Rollweg-Knotens.
func taxi_neighbors(n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in range(0, taxi_edges.size() - 1, 2):
		if taxi_edges[k] == n:
			out.append(taxi_edges[k + 1])
		elif taxi_edges[k + 1] == n:
			out.append(taxi_edges[k])
	return out


## Ersatzplan zu TerrainWorld._build_airfields (Hangars bei x = -80, Turm bei x = -70).
## Abstellplätze westlich der Piste bei x = -45, Nase nach Osten (zur Piste).
static func make_default(index: int, runway_length: float, runway_width_m: float = 40.0,
		nation: int = Nations.NONE) -> AirfieldLayout:
	var l := AirfieldLayout.new()
	l.airfield_index = index
	l.nation_id = nation
	l.runway_width = runway_width_m
	var sz := runway_length * 0.5 - 20.0
	l.runway_start = Vector3(0, 0, sz)
	l.runway_end = Vector3(0, 0, -runway_length * 0.5 + 20.0)
	var taxi_x := -30.0
	# Knoten: 0 = Pistenanfang, 1 = Haltepunkt, danach Rollweg nach Norden mit Zufahrten
	l.taxi_nodes.append(l.runway_start)
	l.taxi_nodes.append(Vector3(taxi_x, 0, sz))
	l.taxi_edges.append_array([0, 1])
	l.runway_node = 0
	l.hold_node = 1
	var prev := 1
	for i in 4:
		var z := sz - 90.0 - i * 30.0
		l.parking_positions.append(Vector3(-45.0, 0, z))
		l.parking_headings.append(Vector3(1, 0, 0))
		l.taxi_nodes.append(Vector3(taxi_x, 0, z))
		var n := l.taxi_nodes.size() - 1
		l.taxi_edges.append_array([prev, n])
		l.parking_nodes.append(n)
		prev = n
	l.fuel_depot = Vector3(-110.0, 0, sz - 20.0)
	l.ammo_bunker = Vector3(-115.0, 0, sz - 260.0)
	l.hangar = Vector3(-80.0, 0, sz - 120.0)
	l.crew_spawn = Vector3(-60.0, 0, sz - 60.0)
	l.vehicle_spawns = PackedVector3Array([Vector3(-95.0, 0, sz - 30.0), Vector3(-95.0, 0, sz - 245.0)])
	return l
