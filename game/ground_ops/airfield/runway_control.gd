class_name RunwayControl
extends Node
## M3 Stub (Paket 0b, gehört Strang C / Paket 8): vergibt die Piste eines Platzes exklusiv.
## request(aircraft) -> bool, release(aircraft), occupant, is_free().

var airfield_index := 0
var occupant: Node = null


func request(a: Node) -> bool:
	if not Authority.is_server():
		return false
	if occupant == null or not is_instance_valid(occupant) or occupant == a:
		occupant = a
		return true
	return false


func release(a: Node) -> void:
	if occupant == a:
		occupant = null


func is_free() -> bool:
	return occupant == null or not is_instance_valid(occupant)
