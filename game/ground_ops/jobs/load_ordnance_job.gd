class_name LoadOrdnanceJob
extends GroundJob
## M3 Stub (Paket 0b, gehört Strang G): Schnittstelle für Bomben (M4, PO-Entscheidung 5). In M3 immer blockiert (&"not_available").

## M4: Außenlast (Bombe) an Aufhängung hardpoint (AircraftMarkers.hardpoint_names).
var hardpoint := ""
var ordnance: StringName = &""


func _init() -> void:
	kind = &"load_ordnance"
	steps.assign([])
	blocked_reason = &"not_available"
