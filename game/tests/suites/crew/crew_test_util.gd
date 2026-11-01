class_name CrewTestUtil
extends RefCounted
## Helfer für Strang-H-Tests: Controller mit festem CrewIntent bzw. PilotIntent.


class FixedCrewController extends Controller:
	var ci := CrewIntent.new()
	var pi := PilotIntent.new()

	func compute_crew_intent(_dt: float) -> CrewIntent:
		var c := CrewIntent.new()
		c.copy_from(ci)
		ci.view_toggle = false   # Flanke: nur einen Tick
		ci.enter = false
		ci.drop = false
		return c

	func compute_intent(_dt: float) -> PilotIntent:
		return pi


static func make_crew(parent: Node, pos: Vector3, peer := 1) -> CrewCharacter:
	var ch := CrewCharacter.new()
	parent.add_child(ch)
	ch.global_position = pos
	ch._snap_to_ground()
	var c := FixedCrewController.new()
	c.peer_id = peer
	ch.add_child(c)
	ch.crew_seat.possess(c)
	return ch


static func ctl(ch: CrewCharacter) -> FixedCrewController:
	return ch.crew_seat.controller as FixedCrewController
