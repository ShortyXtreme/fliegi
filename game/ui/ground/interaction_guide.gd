class_name InteractionGuide
extends Node3D
## M3.5: Interaktionshilfen in 3D – pulsierender Ring, wippender Pfeil und Beschriftung genau an der
## Stelle, an der man arbeitet („Tankstutzen“, „MG-Klappe links“, „Schlauch hier nehmen“, „Kiste hier
## holen“). Die Positionen werden jeden Frame aus den Markern gelesen (svc_* am Flugzeug über
## ServiceMarkers.aircraft_point, hose_reel/crate_slot_* am Wagen) – neue Markerlagen im Modell
## gelten damit automatisch.
## Quelle der Markierungen: override (Tutorial, Callable -> Array) oder automatisch aus der Lage
## (Figur trägt Schlauch/Kiste, offene Jobs). Automatik nur mit enabled (Einstellung
## „Interaktionshilfen“, Standard an); das Tutorial zeigt seine Markierungen immer.

## Einstellung „Interaktionshilfen: an/aus“ (GameSettings [m3_5] hilfen).
static var enabled := true

const COLOR := Color(1.0, 0.74, 0.22)
const AUTO_RANGE := 30.0
const RING_R := 0.42

## Spielerfigur, eigene Maschine, Wagen, JobBoard (setzt game.gd).
var character: Node3D = null
var aircraft: Node3D = null
var truck: Node3D = null
var cart: Node3D = null
var board: JobBoard = null
## Tutorial: Callable() -> Array von Markierungen; ungültig = Automatik.
var override := Callable()
## Aktuelle Markierungen: [{node, marker, text, sub, pos}] (pos = Weltposition, für Tests).
var marks: Array = []

var _pool: Array = []
var _t := 0.0
var _mat: StandardMaterial3D


func _ready() -> void:
	name = "InteractionGuide"
	top_level = true
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.albedo_color = COLOR
	_mat.render_priority = 10


## Markierung am Flugzeug (svc_*-Marker).
static func at_aircraft(a: Node3D, marker: String, text: String, sub := "") -> Dictionary:
	return {node = a, marker = marker, kind = &"aircraft", text = text, sub = sub}


## Markierung am Wagen (hose_reel, crate_slot_*).
static func at_vehicle(v: Node3D, marker: String, text: String, sub := "") -> Dictionary:
	return {node = v, marker = marker, kind = &"vehicle", text = text, sub = sub}


## Weltposition einer Markierung (jeden Frame neu aus den Markern).
static func resolve(m: Dictionary):
	var n: Node3D = m.get("node")
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return null
	if m.kind == &"aircraft":
		return n.global_transform * ServiceMarkers.aircraft_point(n, m.marker)
	if m.marker == ServiceMarkers.HOSE_REEL and n.get("hose") is Node3D:
		return (n.get("hose") as Node3D).global_position
	if n.has_method("marker_point"):
		return n.global_transform * n.marker_point(m.marker)
	return n.global_position


func _carried_kind() -> StringName:
	if character == null or not is_instance_valid(character):
		return &""
	var it = character.get("carried")
	if it is Object and it.get("kind") != null:
		return it.kind
	return &""


## Automatische Hilfen: was als Nächstes zu tun ist (nur zu Fuß nahe der eigenen Maschine).
func auto_marks() -> Array:
	var out := []
	var a := aircraft as Aircraft
	if a == null or not is_instance_valid(a) or character == null or not is_instance_valid(character) \
			or not character.visible or character.global_position.distance_to(a.global_position) > AUTO_RANGE:
		return out
	var b := board if board != null and is_instance_valid(board) else JobBoard.current
	var carried := _carried_kind()
	var need_fuel := false
	var hatches := []
	if b != null:
		for j: GroundJob in b.open_jobs(a):
			if j.worker != null and is_instance_valid(j.worker) and j.worker != character:
				continue
			if j is RefuelJob and j.current_step() in [&"bring", &"ground", &"attach"]:
				need_fuel = true
			elif j is RearmJob and j.current_step() in [&"crate", &"hatch_open", &"belt", &"hatch_close"]:
				hatches.append(ServiceMarkers.SVC_GUN_HATCH_L if j.gun_index % 2 == 0 else ServiceMarkers.SVC_GUN_HATCH_R)
	if carried == CarryItem.HOSE:
		out.append(at_aircraft(a, ServiceMarkers.SVC_FUEL_CAP, "Tankstutzen", "Schlauch hier ankoppeln"))
	elif carried == CarryItem.CRATE:
		for h in hatches:
			out.append(at_aircraft(a, h, hatch_text(h), "Klappe auf, Gurt einlegen"))
	else:
		if need_fuel and truck != null and is_instance_valid(truck):
			var hose = truck.get("hose")
			if hose is FuelHose and hose.stowed:
				out.append(at_vehicle(truck, ServiceMarkers.HOSE_REEL, "Schlauch hier nehmen", "Interagieren"))
		if not hatches.is_empty() and cart != null and is_instance_valid(cart) and int(cart.get("crates")) > 0:
			out.append(at_vehicle(cart, ServiceMarkers.crate_slot(1), "Kiste hier holen", "Interagieren"))
	return out


static func hatch_text(marker: String) -> String:
	return "MG-Klappe links" if marker == ServiceMarkers.SVC_GUN_HATCH_L else "MG-Klappe rechts"


func _process(dt: float) -> void:
	_t += dt
	var want: Array = []
	if override.is_valid():
		want = override.call()
	elif enabled:
		want = auto_marks()
	marks = []
	for m in want:
		var p = resolve(m)
		if p is Vector3:
			var mm: Dictionary = m.duplicate()
			mm.pos = p
			marks.append(mm)
	while _pool.size() < marks.size():
		_pool.append(_make_visual())
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	for i in _pool.size():
		var v: Node3D = _pool[i]
		v.visible = i < marks.size()
		if not v.visible:
			continue
		var m: Dictionary = marks[i]
		var p: Vector3 = m.pos
		v.global_position = p
		var ring: MeshInstance3D = v.get_child(0)
		var arrow: MeshInstance3D = v.get_child(1)
		var label: Label3D = v.get_child(2)
		var pulse := 1.0 + 0.22 * sin(_t * 5.0 + i)
		if cam != null and cam.global_position.distance_to(p) > 0.5:
			ring.look_at(cam.global_position, Vector3.UP)
			ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		ring.scale = Vector3.ONE * pulse
		arrow.position = Vector3(0, 0.95 + 0.12 * sin(_t * 4.0), 0)
		label.position = Vector3(0, 1.55, 0)
		label.text = String(m.text) + (("\n" + String(m.sub)) if String(m.get("sub", "")) != "" else "")
		var mat := ring.material_override as StandardMaterial3D
		mat.albedo_color = Color(COLOR, 0.55 + 0.35 * (0.5 + 0.5 * sin(_t * 5.0)))


func _make_visual() -> Node3D:
	var root := Node3D.new()
	root.top_level = true
	add_child(root)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RING_R - 0.05
	tm.outer_radius = RING_R
	tm.rings = 32
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = _mat.duplicate()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var arrow := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.0
	cm.height = 0.35
	cm.radial_segments = 12
	arrow.mesh = cm
	arrow.material_override = _mat
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(arrow)
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 30
	l.outline_size = 10
	l.modulate = Color(1.0, 0.93, 0.78)
	l.outline_modulate = Color(0.12, 0.09, 0.05, 0.9)
	l.render_priority = 11
	l.outline_render_priority = 10
	var f = load(HudStyle.FONT_SEMIBOLD)
	if f is Font:
		l.font = f
	root.add_child(l)
	return root
