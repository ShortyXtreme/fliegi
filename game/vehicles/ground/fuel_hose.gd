class_name FuelHose
extends Node3D
## M3 (Paket 5, Strang H): Schlauch von der Trommel (Marker hose_reel) mit tragbarem Ende
## (CarryItem HOSE). Länge HOSE_LENGTH = 12 m; die Figur kommt mit dem Ende nicht weiter
## (constrain). Die Kurve aus SEGMENTS Segmenten hängt durch (Parabel mit Länge ≤ 12 m)
## und liegt nie unter dem Gelände. Angekoppelt (couple, Aufruf durch RefuelJob/Strang G)
## sitzt das Ende am Ziel; wird der Abstand zu groß (Wagen fährt weg), reißt es ab
## (Signal overstretched, Ende fällt zu Boden).
## Am Knoten selbst: Interactable „Schlauch einrollen“ (Ende in der Hand).

signal coupled(anchor: Node3D)
signal uncoupled
signal overstretched

const HOSE_LENGTH := 12.0
const SEGMENTS := 16
## Abstand Körpermitte ↔ Hand (carry) beim Begrenzen.
const HAND_REACH := 0.5
const GROUND_CLEAR := 0.04
const RADIUS := 0.035

var length := HOSE_LENGTH
var end_item: CarryItem
var coupled_to: Node3D = null
var stowed := true
var reel_point: Interactable
var _segs: Array[MeshInstance3D] = []


func _init() -> void:
	name = "FuelHose"
	end_item = CarryItem.make(CarryItem.HOSE)
	end_item.name = "HoseEnd"
	end_item.tether = self
	end_item.pickup.get_action(&"pick_up").label = "Schlauch nehmen"
	add_child(end_item)
	reel_point = Interactable.new()
	reel_point.name = "ReelPoint"
	reel_point.marker = ServiceMarkers.HOSE_REEL
	reel_point.target = self
	add_child(reel_point)
	reel_point.add_action(&"hose_stow", "Schlauch einrollen", 0.0, CarryItem.HOSE, _is_my_end_carried)
	reel_point.performed.connect(_on_reel_action)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.12)
	var mesh := CylinderMesh.new()
	mesh.top_radius = RADIUS
	mesh.bottom_radius = RADIUS
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 1
	for i in SEGMENTS:
		var m := MeshInstance3D.new()
		m.mesh = mesh
		m.material_override = mat
		m.top_level = true
		m.visible = false
		add_child(m)
		_segs.append(m)


func _is_my_end_carried(character: Node) -> bool:
	return character != null and character.get("carried") == end_item


func _on_reel_action(id: StringName, character: Node) -> void:
	if id == &"hose_stow" and character.get("carried") == end_item:
		character.call("release_item")
		stow()


func reel_position() -> Vector3:
	return global_position


func end_position() -> Vector3:
	return end_item.global_position


## Ende zurück auf die Trommel.
func stow() -> void:
	if coupled_to != null:
		uncouple()
	if end_item.holder != null and end_item.holder.has_method("release_item"):
		end_item.holder.call("release_item")
	_reparent_end(self, Vector3.ZERO)
	stowed = true
	end_item.set_locked(false)


## Nur Server: Ende an anchor (z. B. Flugzeug, local = svc_fuel_cap) ankoppeln.
func couple(anchor: Node3D, local := Vector3.ZERO) -> bool:
	if not Authority.is_server() or anchor == null:
		return false
	if reel_position().distance_to(anchor.global_transform * local) > length:
		return false
	if end_item.holder != null and end_item.holder.has_method("release_item"):
		end_item.holder.call("release_item")
	_reparent_end(anchor, local)
	coupled_to = anchor
	stowed = false
	end_item.set_locked(true)
	coupled.emit(anchor)
	return true


## Nur Server: abkoppeln, das Ende liegt danach frei am Boden.
func uncouple() -> void:
	if coupled_to == null or not Authority.is_server():
		return
	_lay_end_at(end_position())
	coupled_to = null
	end_item.set_locked(false)
	uncoupled.emit()


func is_coupled() -> bool:
	return coupled_to != null and is_instance_valid(coupled_to)


func _reparent_end(parent: Node, local: Vector3) -> void:
	if end_item.get_parent() != parent:
		if end_item.get_parent() != null:
			end_item.get_parent().remove_child(end_item)
		parent.add_child(end_item)
	end_item.position = local
	end_item.rotation = Vector3.ZERO


func _lay_end_at(p: Vector3) -> void:
	# oberster Knoten unter der Wurzel (Welt), damit das Ende nicht mitfährt
	var host: Node = self
	while host.get_parent() != null and host.get_parent() != get_tree().root:
		host = host.get_parent()
	_reparent_end(host, Vector3.ZERO)
	end_item.global_position = Vector3(p.x, WorldGround.height_at(p.x, p.z), p.z)


## Figur mit dem Ende in der Hand: waagerechter Abstand zur Trommel ≤ Länge − Handweite.
func constrain(p: Vector3) -> Vector3:
	var r := reel_position()
	var flat := Vector3(p.x - r.x, 0.0, p.z - r.z)
	var dy := absf(p.y + 1.0 - r.y)
	var max_r := sqrt(maxf(pow(length - HAND_REACH, 2) - dy * dy, 0.0))
	if flat.length() <= max_r:
		return p
	var q := r + flat.normalized() * max_r
	return Vector3(q.x, p.y, q.z)


func _physics_process(_dt: float) -> void:
	stowed = end_item.get_parent() == self
	if is_coupled() and reel_position().distance_to(end_position()) > length:
		var p := reel_position() + (end_position() - reel_position()).normalized() * (length - 0.5)
		coupled_to = null
		end_item.set_locked(false)
		_lay_end_at(p)
		overstretched.emit()
		uncoupled.emit()


## Kurve Trommel -> Ende, SEGMENTS + 1 Punkte, Polylinienlänge ≤ length.
func points() -> PackedVector3Array:
	var a := reel_position()
	var b := end_position()
	var pts := PackedVector3Array()
	pts.resize(SEGMENTS + 1)
	var d := a.distance_to(b)
	var sag := sqrt(3.0 * d * maxf(length - d, 0.0) / 8.0) if d > 0.01 else 0.0
	for it in 6:
		for i in SEGMENTS + 1:
			var t := float(i) / SEGMENTS
			var p := a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t)
			p.y = maxf(p.y, WorldGround.height_at(p.x, p.z) + GROUND_CLEAR) if i > 0 and i < SEGMENTS else p.y
			pts[i] = p
		if _poly_len(pts) <= length or sag <= 0.0:
			break
		sag *= 0.8
	return pts


static func _poly_len(pts: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i].distance_to(pts[i - 1])
	return l


func polyline_length() -> float:
	return _poly_len(points())


func _process(_dt: float) -> void:
	var show := not stowed and is_visible_in_tree()
	var pts := points() if show else PackedVector3Array()
	for i in SEGMENTS:
		var m := _segs[i]
		m.visible = show
		if not show:
			continue
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var dir := p1 - p0
		var l := dir.length()
		if l < 1e-4:
			m.visible = false
			continue
		var y := dir / l
		var x := y.cross(Vector3.UP if absf(y.y) < 0.99 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		m.global_transform = Transform3D(Basis(x, y * l, z), (p0 + p1) * 0.5)
