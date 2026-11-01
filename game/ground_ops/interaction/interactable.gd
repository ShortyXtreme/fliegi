class_name Interactable
extends Node3D
## M3 Vertrag (Paket 0b, gehört Strang H / Paket 4): Interaktionspunkt. Kommt aus Markern
## (ServiceMarkers: svc_*, hose_reel, crate_slot_*, seat_driver). Aktionen:
##   {id: StringName, label: String, hold_s: float, needs_item: StringName (leer = keins)}
## Feste Signaturen: marker, target, actions, add_action(), actions_for(character) -> Array.

var marker := ""
## Flugzeug/Fahrzeug/Gebäude, zu dem der Punkt gehört.
var target: Node = null
var actions: Array[Dictionary] = []


func add_action(id: StringName, label: String, hold_s: float = 0.0, needs_item: StringName = &"") -> void:
	actions.append({"id": id, "label": label, "hold_s": hold_s, "needs_item": needs_item})


## Aktionen, die die Figur gerade ausführen kann (Stub: alle).
func actions_for(_character: Node) -> Array[Dictionary]:
	return actions
