class_name HitboxSet
extends RefCounted
## Trefferzonen als reine Daten (Stub aus Paket 0, Inhalt: Agent B, Paket 3).
## Koordinaten im Flugzeug-System (Ursprung = Schwerpunkt). Kein Physik-Objekt, damit
## Trefferprüfung zurückspulen kann (TransformHistory).

## Radius der Begrenzungskugel (m) für die Grobprüfung im ProjectileSystem.
var bounding_radius := 6.0


static func from_aircraft_data(d: Resource) -> HitboxSet:
	var h := HitboxSet.new()
	if d != null and d.get("wing_box_size") is Vector3:
		h.bounding_radius = maxf(d.wing_box_size.x, d.fuselage_box_size.z) * 0.55
	return h


## Segment p0 -> p1 (lokal) gegen die Zonen. Rückgabe {} oder
## {"zone": DamageModel.Zone, "t": 0..1, "point": Vector3 (lokal)}. Stub: nie getroffen.
func intersect_segment(_p0: Vector3, _p1: Vector3) -> Dictionary:
	return {}
