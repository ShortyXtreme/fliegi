class_name ServiceMarkers
extends RefCounted
## M3 (Paket 0b, Vertrag): feste Marker-Namen für Bodenbetrieb. Die Grafik setzt sie als
## leere Knoten in die GLBs (extract_markers -> AircraftMarkers.points). Fehlt ein Marker,
## gelten die Ersatzpositionen unten (aus AircraftData-Geometrie). Koordinaten im
## Fahrzeug-System (Nase -Z, rechts +X).

# --- Flugzeug (build_game_aircraft.py) ---
const SVC_FUEL_CAP := "svc_fuel_cap"
const SVC_GUN_HATCH_L := "svc_gun_hatch_L"
const SVC_GUN_HATCH_R := "svc_gun_hatch_R"
const SVC_ENTRY := "svc_entry"
const SVC_ENGINE := "svc_engine"
const AIRCRAFT := [SVC_FUEL_CAP, SVC_GUN_HATCH_L, SVC_GUN_HATCH_R, SVC_ENTRY, SVC_ENGINE]
# --- Bodenfahrzeuge (build_airfield_props.py) ---
const HOSE_REEL := "hose_reel"
const SEAT_DRIVER := "seat_driver"
const SEAT_PASSENGER := "seat_passenger"
const GROUND_CLIP := "ground_clip"
const CRATE_SLOT_PREFIX := "crate_slot_"   # crate_slot_1 .. crate_slot_6
const CRATE_SLOTS := 6
# --- Platz-Gebäude ---
const DOOR := "door"
const FUEL_TAP := "fuel_tap"
const AMMO_DOOR := "ammo_door"
# --- Figur (build_crew.py) ---
const HAND_R := "hand_R"
const HAND_L := "hand_L"
const CARRY := "carry"


static func crate_slot(i: int) -> String:
	return "%s%d" % [CRATE_SLOT_PREFIX, i]


## Position eines Service-Markers am Flugzeug (lokal): aus den Markern, sonst Ersatz.
static func aircraft_point(a: Node, marker: String) -> Vector3:
	var d = a.get("damage")
	var h: HitboxSet = d.hitboxes if d != null else null
	if h != null and h.markers != null and h.markers.points.has(marker):
		return h.markers.points[marker]
	return fallback(a.get("data"), marker, h.markers if h != null else null)


## Ersatzpositionen aus der Geometrie (AircraftData) bzw. Waffenmarkern.
static func fallback(data: Resource, marker: String, m: AircraftMarkers = null) -> Vector3:
	var fc: Vector3 = data.fuselage_box_center if data != null else Vector3(0, 0, 0.6)
	var fs: Vector3 = data.fuselage_box_size if data != null else Vector3(1, 1.1, 8.2)
	var wc: Vector3 = data.wing_box_center if data != null else Vector3(0, -0.35, 0)
	var ws: Vector3 = data.wing_box_size if data != null else Vector3(10.6, 0.22, 1.9)
	var eye: Vector3 = data.cockpit_eye if data != null else Vector3(0, 0.95, 0.9)
	match marker:
		SVC_FUEL_CAP:
			return Vector3(0, fc.y + fs.y * 0.5, eye.z - 1.4)
		SVC_GUN_HATCH_L, SVC_GUN_HATCH_R:
			var sx := -1.0 if marker == SVC_GUN_HATCH_L else 1.0
			if m != null:
				for p in m.gun_positions:
					if signf(p.x) == sx:
						return Vector3(p.x, wc.y + ws.y * 0.5, p.z + 0.3)
			return Vector3(sx * ws.x * 0.25, wc.y + ws.y * 0.5, wc.z)
		SVC_ENTRY:
			return Vector3(-(fs.x * 0.5 + 0.6), wc.y + ws.y * 0.5, eye.z)
		SVC_ENGINE:
			return Vector3(0, fc.y, fc.z - fs.z * 0.5 + 0.6)
	return Vector3.ZERO
