class_name RunwayControl
extends Node
## Vergibt die Piste eines Platzes exklusiv (M3 Paket 8, Strang C). Nur der Server vergibt.
## request(aircraft) -> bool (true = Piste gehört jetzt diesem Flugzeug), release(aircraft),
## occupant, is_free(). Abgeschossene/entfernte Belegungen gelten als frei.
## find_or_create(node, index): eine Instanz je Platz (Gruppe "runway_controls").

const GROUP := "runway_controls"

var airfield_index := 0
var occupant: Node = null
## Diagnose: Anzahl Vergaben und abgelehnter Anfragen.
var grants := 0
var denials := 0


func _enter_tree() -> void:
	add_to_group(GROUP)


func request(a: Node) -> bool:
	if not Authority.is_server() or a == null:
		return false
	if is_free() or occupant == a:
		if occupant != a:
			grants += 1
		occupant = a
		return true
	denials += 1
	return false


func release(a: Node) -> void:
	if occupant == a:
		occupant = null


func is_free() -> bool:
	if occupant == null or not is_instance_valid(occupant):
		occupant = null
		return true
	var d = occupant.get("damage")
	if d is DamageModel and d.outcome == DamageModel.Outcome.CRASHED:
		occupant = null
		return true
	return false


func holds(a: Node) -> bool:
	return not is_free() and occupant == a


## Pistenvergabe des Platzes index im Baum von node; legt sie bei Bedarf unter node an.
static func find_or_create(node: Node, index: int) -> RunwayControl:
	if node == null:
		return null
	if node.is_inside_tree():
		for r in node.get_tree().get_nodes_in_group(GROUP):
			if r is RunwayControl and r.airfield_index == index:
				return r
	var rc := RunwayControl.new()
	rc.name = "RunwayControl%d" % index
	rc.airfield_index = index
	node.add_child(rc)
	return rc
