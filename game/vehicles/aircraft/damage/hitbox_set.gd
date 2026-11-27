class_name HitboxSet
extends RefCounted
## Trefferzonen als reine Daten (Paket 3, Agent B).
## Koordinaten im Flugzeug-System (Ursprung = Schwerpunkt). Kein Physik-Objekt, damit
## die Trefferprüfung zurückspulen kann (TransformHistory).
## Quelle: AircraftMarkers (aus dem GLB extrahiert) oder Ersatz-Boxen aus AircraftData.
## Dazu Füllboxen für den Rumpf zwischen den Zonen (Rumpfmitte -> Cockpit, Heck -> Leitwerk)
## mit verringertem Schaden (damage_mul).

## Radius der Begrenzungskugel (m) für die Grobprüfung im ProjectileSystem.
var bounding_radius := 6.0
## Je Box: Zone (DamageModel.Zone), Mittelpunkt, halbe Kantenlängen, Schadensfaktor.
var zones: PackedInt32Array = []
var centers: PackedVector3Array = []
var half_extents: PackedVector3Array = []
var damage_mul: PackedFloat32Array = []
## Marker, aus denen die Boxen stammen (Waffen, Außenlasten, Punkte).
var markers: AircraftMarkers
## true, wenn keine extrahierten Marker vorlagen.
var is_fallback := true

## Innere Zonen gewinnen gegen Flügel/Leitwerk/Füllbox, wenn das Segment sie höchstens
## PENETRATION hinter dem ersten Eintritt schneidet (Geschoss durchschlägt die Beplankung).
const INNER := [0, 1, 2, 6]   # ENGINE, FUEL_L, FUEL_R, COCKPIT
const FILLER_MUL := 0.4
## Eindringtiefe (m), bis zu der eine innere Zone hinter der Außenhaut noch zählt.
const PENETRATION := 1.0
## Prüfung Waffen (27.11.2026): Beginnt der Treffer in einer Rumpf-Füllbox (leerer Heckrumpf,
## Monocoque/Stoff), durchschlägt das Geschoss bis zu PENETRATION_FUSELAGE m bis zur
## Panzerplatte hinter dem Piloten. Vorher war das Cockpit von hinten unerreichbar, jeder
## Abschuss von 6 Uhr ging übers Leitwerk.
const PENETRATION_FUSELAGE := 4.5
## Rückenpanzer (Bf 109 E: 8 mm + 10 mm Kopfplatte, Spitfire 1940: 4,5/6,5 mm): Cockpit-Treffer
## aus dem hinteren Kegel (Flugrichtung des Geschosses innerhalb REAR_ARMOR_COS zu -Z) zählen
## nur mit REAR_ARMOR_MUL (Rest = Treffer an der Platte vorbei oder durch sie hindurch).
const REAR_ARMOR_MUL := 0.3
const REAR_ARMOR_COS := 0.6
## Halbe Dicke der Leitwerksplatten (m), ≈ 10–12 % Profildicke plus Ruderspalt.
const TAIL_PLATE_HALF := 0.08


static func from_aircraft_data(d: Resource) -> HitboxSet:
	return from_markers(AircraftMarkers.load_for(d), d)


static func from_markers(m: AircraftMarkers, d: Resource = null) -> HitboxSet:
	var h := HitboxSet.new()
	h.markers = m
	h.is_fallback = m.is_fallback()
	for k in m.zone_names.size():
		var z := DamageModel.ZONE_NAMES.find(m.zone_names[k])
		if z < 0:
			push_warning("HitboxSet: unbekannte Zone %s" % m.zone_names[k])
			continue
		h.add_box(z, m.zone_centers[k], m.zone_half_extents[k], 1.0)
	h._refine_tail(d)
	h._add_fuselage_fillers(d)
	h._update_radius()
	return h


func add_box(zone: int, center: Vector3, he: Vector3, mul := 1.0) -> void:
	zones.append(zone)
	centers.append(center)
	half_extents.append(he.abs())
	damage_mul.append(mul)


## Prüfung Waffen: Das Leitwerk aus den Markern ist ein massiver Block um Flosse und
## Höhenleitwerk (3,7 × 1,8 × 1,5 m, 6,7 m² Stirnfläche). Mit den Leitwerksflächen aus
## AircraftData (htail_*, vtail) wird es durch zwei dünne Platten ersetzt; der Heckkonus
## dazwischen ist eine Füllbox (Steuerseile/Rumpf, FILLER_MUL). Ohne Flächen bleibt der Block.
func _refine_tail(d: Resource) -> void:
	var surfaces = d.get("surfaces") if d != null else null
	if not (surfaces is Array):
		return
	var k := -1
	for i in zones.size():
		if zones[i] == DamageModel.Zone.TAIL and damage_mul[i] >= 1.0:
			k = i
			break
	if k < 0:
		return
	var h_x := 0.0
	var h_y := 0.0
	var h_z := 0.0
	var h_c := 0.0
	var nh := 0
	var fin: Resource = null
	for s in surfaces:
		var nm: String = s.name
		if nm.begins_with("htail"):
			h_x = maxf(h_x, absf(s.position.x) + s.span * 0.5)
			h_y += s.position.y
			h_z += s.position.z
			h_c = maxf(h_c, s.chord)
			nh += 1
		elif nm.begins_with("vtail"):
			fin = s
	if nh == 0 or fin == null:
		return
	var box_c := centers[k]
	var box_h := half_extents[k]
	# Höhenleitwerk (ersetzt den Block)
	centers[k] = Vector3(0.0, h_y / nh, h_z / nh)
	half_extents[k] = Vector3(h_x, TAIL_PLATE_HALF, h_c * 0.5)
	# Seitenflosse
	add_box(DamageModel.Zone.TAIL, fin.position, Vector3(TAIL_PLATE_HALF, fin.span * 0.5, fin.chord * 0.5), 1.0)
	# Heckkonus (Rumpfende unter dem Leitwerk)
	var fs := Vector3(1.0, 1.1, 8.2)
	var fc := Vector3(0, 0, 0.6)
	if d.get("fuselage_box_size") is Vector3:
		fs = d.fuselage_box_size
		fc = d.fuselage_box_center
	add_box(DamageModel.Zone.TAIL, Vector3(0.0, fc.y, box_c.z), Vector3(fs.x * 0.3, fs.y * 0.3, box_h.z), FILLER_MUL)


## Rumpf zwischen Motor/Cockpit/Leitwerk ohne eigene Zone auffüllen.
func _add_fuselage_fillers(d: Resource) -> void:
	var fc := Vector3(0, 0, 0.6)
	var fs := Vector3(1.0, 1.1, 8.2)
	if d != null and d.get("fuselage_box_size") is Vector3:
		fc = d.fuselage_box_center
		fs = d.fuselage_box_size
	var eng := _zone_box(DamageModel.Zone.ENGINE)
	var cpt := _zone_box(DamageModel.Zone.COCKPIT)
	var tail := _zone_box(DamageModel.Zone.TAIL)
	if eng.size == Vector3.ZERO or cpt.size == Vector3.ZERO or tail.size == Vector3.ZERO:
		return
	var hx := fs.x * 0.5
	var hy := fs.y * 0.5
	var cy := fc.y
	# Rumpfmitte: Motor-Ende bis Cockpit-Beginn
	var z0 := eng.end.z
	var z1 := cpt.position.z
	if z1 - z0 > 0.05:
		add_box(DamageModel.Zone.COCKPIT, Vector3(0, cy, (z0 + z1) * 0.5), Vector3(hx, hy, (z1 - z0) * 0.5), FILLER_MUL)
	# Hinterer Rumpf: Cockpit-Ende bis Leitwerk-Beginn
	z0 = cpt.end.z
	z1 = tail.position.z
	if z1 - z0 > 0.05:
		add_box(DamageModel.Zone.TAIL, Vector3(0, cy, (z0 + z1) * 0.5), Vector3(hx * 0.8, hy * 0.8, (z1 - z0) * 0.5), FILLER_MUL)


func _zone_box(zone: int) -> AABB:
	for k in zones.size():
		if zones[k] == zone and damage_mul[k] >= 1.0:
			return AABB(centers[k] - half_extents[k], half_extents[k] * 2.0)
	return AABB()


func _update_radius() -> void:
	var r := 0.0
	for k in zones.size():
		r = maxf(r, (centers[k].abs() + half_extents[k]).length())
	bounding_radius = r + 0.25 if r > 0.0 else 6.0


func box_count() -> int:
	return zones.size()


## Segment p0 -> p1 (lokal) gegen die Zonen. Rückgabe {} oder
## {"zone": DamageModel.Zone, "t": 0..1, "point": Vector3 (lokal), "damage_mul": float, "box": int}.
func intersect_segment(p0: Vector3, p1: Vector3) -> Dictionary:
	var d := p1 - p0
	var first := -1
	var first_t := INF
	var inner := -1
	var inner_t := INF
	for k in zones.size():
		var t := _slab(p0, d, centers[k], half_extents[k])
		if t < 0.0:
			continue
		if t < first_t:
			first = k
			first_t = t
		if zones[k] in INNER and damage_mul[k] >= 1.0 and t < inner_t:
			inner = k
			inner_t = t
	if first < 0:
		return {}
	var best := first
	var seg_len := maxf(d.length(), 1e-6)
	var pen := PENETRATION_FUSELAGE if damage_mul[first] < 1.0 else PENETRATION
	if inner >= 0 and (inner_t - first_t) * seg_len <= pen:
		best = inner
	var bt := first_t if best == first else inner_t
	var mul := damage_mul[best]
	var armor := false
	if zones[best] == DamageModel.Zone.COCKPIT and -d.z / seg_len > REAR_ARMOR_COS:
		mul *= REAR_ARMOR_MUL
		armor = true
	return {"zone": zones[best], "t": bt, "point": p0 + d * bt,
		"damage_mul": mul, "box": best, "armor": armor}


## Eintritts-Parameter t (0..1) des Segments in die achsparallele Box, -1 = kein Treffer.
static func _slab(p0: Vector3, d: Vector3, c: Vector3, he: Vector3) -> float:
	var t0 := 0.0
	var t1 := 1.0
	for a in 3:
		var o := p0[a] - c[a]
		if absf(d[a]) < 1e-9:
			if absf(o) > he[a]:
				return -1.0
			continue
		var inv := 1.0 / d[a]
		var ta := (-he[a] - o) * inv
		var tb := (he[a] - o) * inv
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return -1.0
	return t0
