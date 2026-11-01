class_name FuelTruck
extends GroundVehicle
## M3 (Paket 6, Strang H): Tankwagen, 2.000 l (TruckTank, eine Sorte zugleich), Schlauch
## 12 m auf der Trommel (Marker hose_reel, FuelHose). tank ist die FuelSource für RefuelJob.
## Befüllen am Lager: fill_from(source, grade, dt) mit FILL_RATE (20 l/s), nur Server, nur
## in FILL_RANGE um source.position (FuelDepot) bzw. fill_source_pos. Mengen-Erhalt: was der
## Tank nicht annimmt, geht mit deposit() an die Quelle zurück.
## Interaktion an der Trommel: „Tankwagen befüllen“ (Dauer-Aktion, solange gehalten) bei
## gesetztem depot in Reichweite.

signal tank_changed

const TANK_CAPACITY := 2000.0
const HOSE_LENGTH := 12.0
const FILL_RATE := 20.0
const FILL_RANGE := 10.0

var tank := TruckTank.new(TANK_CAPACITY, FuelSystem.GRADE_AVIATION, TANK_CAPACITY)
var hose: FuelHose
## Lager zum Befüllen (FuelDepot o. ä.), setzt das Szenario (Paket 14).
var depot: FuelSource = null
var fill_grade: StringName = FuelSystem.GRADE_AVIATION
var fill_point: Interactable


func _configure() -> void:
	body_length = 6.4
	markers[ServiceMarkers.HOSE_REEL] = Vector3(0.0, 1.3, 3.1)


func _ready() -> void:
	super()
	hose = FuelHose.new()
	add_child(hose)
	hose.position = marker_point(ServiceMarkers.HOSE_REEL)
	fill_point = Interactable.new()
	fill_point.name = "FillPoint"
	fill_point.marker = ServiceMarkers.HOSE_REEL
	fill_point.target = self
	add_child(fill_point)
	fill_point.position = marker_point(ServiceMarkers.HOSE_REEL) + Vector3(0.6, -0.3, 0.2)
	var a := fill_point.add_action(&"truck_fill", "Tankwagen befüllen", 0.0, &"", _can_fill_here)
	a["continuous"] = true
	fill_point.holding.connect(_on_fill_hold)
	tank.changed.connect(func(): tank_changed.emit())


## Static-Fabrik mit Startinhalt (Authentisch: leer, muss am Lager befüllt werden).
static func create(start_l := TANK_CAPACITY, grade: StringName = FuelSystem.GRADE_AVIATION) -> FuelTruck:
	var t := FuelTruck.new()
	t.tank = TruckTank.new(start_l, grade, TANK_CAPACITY)
	return t


func _markers_changed() -> void:
	if hose != null:
		hose.position = marker_point(ServiceMarkers.HOSE_REEL)


func source_position(src: Object) -> Vector3:
	var p = src.get("position") if src != null else null
	return p if p is Vector3 else Vector3(INF, INF, INF)


## Steht der Wagen nah genug an der Quelle (Abstand Trommel ↔ Lager)?
func in_fill_range(src: Object) -> bool:
	var p := source_position(src)
	if not p.is_finite():
		return false
	var r := global_transform * marker_point(ServiceMarkers.HOSE_REEL)
	return Vector2(r.x - p.x, r.z - p.z).length() <= FILL_RANGE


## Nur Server: aus source befüllen. Rückgabe: angenommene Liter in diesem Schritt.
func fill_from(source: FuelSource, grade: StringName, dt: float) -> float:
	if not Authority.is_server() or source == null or dt <= 0.0:
		return 0.0
	if not in_fill_range(source) or absf(speed) >= Seat.MAX_SWITCH_SPEED or hose.is_coupled():
		return 0.0
	var room := tank.capacity(grade) - tank.available(grade)
	var want := minf(FILL_RATE * dt, room)
	if want <= 0.0:
		return 0.0
	var got := source.draw(grade, want)
	var put := tank.deposit(grade, got)
	if got - put > 0.0:
		source.deposit(grade, got - put)
	return put


func _can_fill_here(_c: Node) -> bool:
	return depot != null and in_fill_range(depot) and tank.capacity(fill_grade) - tank.available(fill_grade) > 0.01


func _on_fill_hold(id: StringName, _c: Node, dt: float, _p: float) -> void:
	if id == &"truck_fill" and depot != null:
		fill_from(depot, fill_grade, dt)


func _build_visual() -> void:
	super()
	var tankm := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.85
	c.bottom_radius = 0.85
	c.height = 3.8
	tankm.mesh = c
	tankm.rotation.x = PI / 2
	tankm.position = Vector3(0, ground_clear + 1.45, 0.9)
	tankm.material_override = _mat(Color(0.35, 0.38, 0.3))
	visual.add_child(tankm)
	_box(Vector3(0.9, 0.7, 0.5), markers[ServiceMarkers.HOSE_REEL] + Vector3(0, -0.2, 0), Color(0.2, 0.2, 0.2))
