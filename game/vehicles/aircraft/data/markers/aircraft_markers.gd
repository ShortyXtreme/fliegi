class_name AircraftMarkers
extends Resource
## Aus dem GLB extrahierte Marker eines Flugzeugtyps (Paket 3, Agent B).
## Alle Koordinaten im Flugzeug-System des Spiels (Ursprung = Schwerpunkt, Nase -Z,
## rechter Flügel +X). Server/Headless laden so kein GLB.
## Erzeugt von tools/extract_markers.gd; fehlt die Datei, liefert fallback_from_data()
## Ersatzwerte aus Aero-Flächen und Kollisionsboxen.

## Trefferzonen (Name wie DamageModel.ZONE_NAMES), Mittelpunkt und halbe Kantenlängen.
@export var zone_names: PackedStringArray = []
@export var zone_centers: PackedVector3Array = []
@export var zone_half_extents: PackedVector3Array = []
## Bordwaffen (gun_*): Position, Schussrichtung (Einheitsvektor), Kaliber.
@export var gun_names: PackedStringArray = []
@export var gun_positions: PackedVector3Array = []
@export var gun_dirs: PackedVector3Array = []
@export var gun_calibers: PackedFloat32Array = []
## Außenlasten (hardpoint_*): Position, Höchstlast (kg).
@export var hardpoint_names: PackedStringArray = []
@export var hardpoint_positions: PackedVector3Array = []
@export var hardpoint_max_kg: PackedFloat32Array = []
## Weitere Punkte (exhaust_*, wingtip_*, contact_*, cam_cockpit, Ruder-Pivots
## "pivot_<knoten>", ...): Name -> Vector3.
@export var points: Dictionary = {}
## Herkunft (GLB-Pfad) bzw. "fallback".
@export var source: String = ""

const ZONE_PREFIX := "dmg_"


func is_fallback() -> bool:
	return source == "fallback"


func zone_index(zone_name: String) -> int:
	return zone_names.find(zone_name)


## Marker eines Flugzeugtyps: Datei aus d.markers_path, sonst Ersatz aus den Daten.
static func load_for(d: Resource) -> AircraftMarkers:
	if d != null:
		var p = d.get("markers_path")
		if p is String and not p.is_empty() and ResourceLoader.exists(p):
			var m = load(p)
			if m is AircraftMarkers:
				return m
	return fallback_from_data(d)


## Ersatz-Marker aus Aero-Flächen, Motorposition, Cockpit und Rumpfbox.
static func fallback_from_data(d: Resource) -> AircraftMarkers:
	var m := AircraftMarkers.new()
	m.source = "fallback"
	var fus_c := Vector3(0, 0, 0.6)
	var fus_s := Vector3(1.0, 1.1, 8.2)
	var engine := Vector3(0, 0, -2.6)
	var eye := Vector3(0, 0.95, 0.9)
	if d != null and d.get("fuselage_box_size") is Vector3:
		fus_c = d.fuselage_box_center
		fus_s = d.fuselage_box_size
		engine = d.engine_position
		eye = d.cockpit_eye
	var half_w := fus_s.x * 0.5
	# Flügel und Leitwerk aus den Flächen
	var wing := {1: AABB(), -1: AABB()}
	var wing_set := {1: false, -1: false}
	var tail := AABB()
	var tail_set := false
	var surfaces = d.get("surfaces") if d != null else null
	if surfaces is Array:
		for s in surfaces:
			var b := _surface_box(s)
			var nm: String = s.name
			if nm.begins_with("wing"):
				var side := 1 if s.position.x >= 0.0 else -1
				wing[side] = b if not wing_set[side] else wing[side].merge(b)
				wing_set[side] = true
			elif nm.contains("tail"):
				tail = b if not tail_set else tail.merge(b)
				tail_set = true
	if not wing_set[1]:
		wing[1] = AABB(Vector3(half_w, -0.3, -0.9), Vector3(4.7, 0.3, 1.8))
		wing[-1] = AABB(Vector3(-half_w - 4.7, -0.3, -0.9), Vector3(4.7, 0.3, 1.8))
	if not tail_set:
		var z_end := fus_c.z + fus_s.z * 0.5
		tail = AABB(Vector3(-1.8, -0.2, z_end - 1.5), Vector3(3.6, 1.8, 1.5))
	# Flügel beginnen neben dem Rumpf
	for side in [1, -1]:
		var b: AABB = wing[side]
		var inner := half_w
		if side > 0 and b.position.x < inner:
			b.size.x -= inner - b.position.x
			b.position.x = inner
		elif side < 0 and b.end.x > -inner:
			b.size.x -= b.end.x + inner
		wing[side] = b
	m._add_zone("engine", engine + Vector3(0, 0, 0.8), Vector3(half_w * 0.85, 0.45, 0.85))
	var wl: AABB = wing[-1]
	var wr: AABB = wing[1]
	var tank_y := (wl.position.y + wl.end.y) * 0.5
	m._add_zone("fuel_tank_L", Vector3(-half_w - 0.5, tank_y, wl.get_center().z), Vector3(0.5, 0.12, 0.45))
	m._add_zone("fuel_tank_R", Vector3(half_w + 0.5, tank_y, wr.get_center().z), Vector3(0.5, 0.12, 0.45))
	m._add_zone("wing_L", wl.get_center(), wl.size * 0.5)
	m._add_zone("wing_R", wr.get_center(), wr.size * 0.5)
	m._add_zone("tail", tail.get_center(), tail.size * 0.5)
	m._add_zone("cockpit", Vector3(eye.x, eye.y - 0.35, eye.z + 0.25), Vector3(0.35, 0.45, 0.8))
	return m


static func _surface_box(s) -> AABB:
	var basis := Basis.from_euler(s.rotation_deg * (PI / 180.0))
	var he := Vector3(s.span * 0.5, maxf(s.chord * 0.06, 0.08), s.chord * 0.5)
	var c: Vector3 = s.position
	var box := AABB(c, Vector3.ZERO)
	for i in 8:
		var corner := Vector3(he.x if i & 1 else -he.x, he.y if i & 2 else -he.y, he.z if i & 4 else -he.z)
		box = box.expand(c + basis * corner)
	return box


func _add_zone(n: String, c: Vector3, he: Vector3) -> void:
	zone_names.append(n)
	zone_centers.append(c)
	zone_half_extents.append(he.abs())


# --- Extraktion aus dem GLB (ohne Import, liest nur den JSON-Teil) ---------------

## Liest Marker aus einer .glb-Datei. model_xf bildet Modell- auf Flugzeugkoordinaten ab
## (Spiel: Nase -Z; Modell laut rig.json Nase +Z -> 180° um Y).
## Fehlende Zonen werden mit Ersatzwerten aus d ergänzt (Warnung).
static func from_glb(path: String, model_xf: Transform3D, d: Resource = null) -> AircraftMarkers:
	var abs_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		push_warning("AircraftMarkers: GLB fehlt: %s" % abs_path)
		return null
	if f.get_32() != 0x46546C67:
		push_warning("AircraftMarkers: keine GLB-Datei: %s" % abs_path)
		return null
	f.get_32()
	f.get_32()
	var json_len := f.get_32()
	f.get_32()
	var j = JSON.parse_string(f.get_buffer(json_len).get_string_from_utf8())
	if not (j is Dictionary) or not j.has("nodes"):
		return null
	var nodes: Array = j["nodes"]
	var parent := {}
	for i in nodes.size():
		for c in nodes[i].get("children", []):
			parent[int(c)] = i
	var m := AircraftMarkers.new()
	m.source = path
	var rot := model_xf.basis.orthonormalized()
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var nm: String = n.get("name", "")
		var ex: Dictionary = n.get("extras", {})
		var xf := model_xf * _world_xf(nodes, parent, i)
		var p := xf.origin.snapped(Vector3.ONE * 1e-4)
		if nm.begins_with(ZONE_PREFIX):
			var he := _v3(ex.get("half_extents", [0.5, 0.5, 0.5]))
			m._add_zone(nm.substr(ZONE_PREFIX.length()), p, (rot * he).abs().snapped(Vector3.ONE * 1e-4))
		elif nm.begins_with("gun_"):
			m.gun_names.append(nm)
			m.gun_positions.append(p)
			m.gun_dirs.append((rot * _v3(ex.get("fire_dir", [0, 0, 1]))).normalized().snapped(Vector3.ONE * 1e-5))
			m.gun_calibers.append(float(ex.get("caliber_mm", 0.0)))
		elif nm.begins_with("hardpoint_"):
			m.hardpoint_names.append(nm)
			m.hardpoint_positions.append(p)
			m.hardpoint_max_kg.append(float(ex.get("max_kg", 0.0)))
		elif not n.has("mesh") and not n.has("children") and not nm.is_empty():
			m.points[nm] = p
			if ex.has("dir"):
				m.points[nm + "_dir"] = (rot * _v3(ex["dir"])).normalized()
		elif n.has("translation") or n.has("rotation"):
			m.points["pivot_" + nm] = p
	# Ersatz für fehlende Zonen
	var fb := fallback_from_data(d)
	for k in fb.zone_names.size():
		if m.zone_index(fb.zone_names[k]) < 0:
			push_warning("AircraftMarkers: Marker dmg_%s fehlt, Ersatzbox" % fb.zone_names[k])
			m._add_zone(fb.zone_names[k], fb.zone_centers[k], fb.zone_half_extents[k])
	return m


static func _v3(a) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


static func _local_xf(n: Dictionary) -> Transform3D:
	var t := _v3(n.get("translation", [0, 0, 0]))
	var r: Array = n.get("rotation", [0, 0, 0, 1])
	var s := _v3(n.get("scale", [1, 1, 1]))
	var q := Quaternion(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	return Transform3D(Basis(q) * Basis.from_scale(s), t)


static func _world_xf(nodes: Array, parent: Dictionary, i: int) -> Transform3D:
	var xf := _local_xf(nodes[i])
	var k := i
	while parent.has(k):
		k = parent[k]
		xf = _local_xf(nodes[k]) * xf
	return xf
