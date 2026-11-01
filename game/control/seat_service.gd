class_name SeatService
extends Node
## M3 (Paket 0a): Ein- und Aussteigen als Sitzwechsel, nur Server. Spieler und KI rufen
## dieselben Funktionen auf (offline direkt, später per RPC wie der HitValidator):
##   request_enter(peer, character, seat) -> Result
##   request_exit(peer, seat) -> Result
## Prüfungen: Server (Authority), Peer besitzt den Controller, Abstand Figur ↔
## seat.entry_position() ≤ Seat.ENTRY_RANGE, Fahrt < Seat.MAX_SWITCH_SPEED, Bodenkontakt,
## Sitz frei oder mit KI besetzt (die KI macht Platz, Signal ai_displaced).
##
## Die Figur (CrewCharacter, Strang H) hat ein Feld `crew_seat: Seat` (Role.CREW). Optional
## implementiert sie `on_entered_seat(seat)` und `on_exited_seat(seat, pos)`; sonst wird sie
## nur versteckt bzw. an den Einstiegspunkt gesetzt. Den Controller für den Zielsitz liefert
## der Besitzer des Controllers (`controller.session.controller_for(role)`, PlayerSession),
## ohne Besitzer zieht derselbe Controller um.
## Fahrzeuge melden optional `seat_speed() -> float` und `seat_on_ground() -> bool`;
## sonst gelten Aircraft.telemetry(), RigidBody3D/CharacterBody3D-Geschwindigkeit.

enum Result { OK, NOT_SERVER, BAD_PEER, TOO_FAR, MOVING, NO_GROUND, OCCUPIED, INVALID, NO_CHARACTER }
const RESULT_TEXT := ["ok", "nur Server", "fremder Sitz", "zu weit weg", "noch in Fahrt",
	"nicht am Boden", "Sitz besetzt", "ungültig", "keine Figur"]

signal ai_displaced(controller: Controller, seat: Seat)

static var current: SeatService = null

## Sitz -> Figur, die darin sitzt (für das Aussteigen).
var riders := {}


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func request_enter(peer: int, character: Node3D, seat: Seat) -> int:
	if not Authority.is_server():
		return Result.NOT_SERVER
	if seat == null or not is_instance_valid(character):
		return Result.INVALID
	var crew_seat := character.get("crew_seat") as Seat
	if crew_seat == null or crew_seat == seat or crew_seat.controller == null:
		return Result.INVALID
	var cc := crew_seat.controller
	if cc.peer_id != peer:
		return Result.BAD_PEER
	if character.global_position.distance_to(seat.entry_position()) > Seat.ENTRY_RANGE:
		return Result.TOO_FAR
	var v := seat.vehicle
	if vehicle_speed(v) >= Seat.MAX_SWITCH_SPEED:
		return Result.MOVING
	if not vehicle_on_ground(v):
		return Result.NO_GROUND
	if seat.controller != null:
		if not seat.controller.is_ai():
			return Result.OCCUPIED
		var ai := seat.controller
		seat.release()
		ai_displaced.emit(ai, seat)
	var target_c := _controller_for(cc, seat.role)
	crew_seat.release()
	seat.possess(target_c)
	riders[seat] = character
	if character.has_method("on_entered_seat"):
		character.call("on_entered_seat", seat)
	else:
		character.visible = false
	GroundEvents.bus().seat_changed.emit(peer, crew_seat, seat)
	return Result.OK


func request_exit(peer: int, seat: Seat) -> int:
	if not Authority.is_server():
		return Result.NOT_SERVER
	if seat == null or seat.controller == null:
		return Result.INVALID
	if seat.controller.peer_id != peer:
		return Result.BAD_PEER
	var v := seat.vehicle
	if vehicle_speed(v) >= Seat.MAX_SWITCH_SPEED:
		return Result.MOVING
	if not vehicle_on_ground(v):
		return Result.NO_GROUND
	var character: Node3D = riders.get(seat)
	if not is_instance_valid(character) or not (character.get("crew_seat") is Seat):
		return Result.NO_CHARACTER
	var crew_seat: Seat = character.get("crew_seat")
	var crew_c := _controller_for(seat.controller, Seat.Role.CREW)
	var pos := seat.entry_position()
	seat.release()
	riders.erase(seat)
	crew_seat.possess(crew_c)
	if character.has_method("on_exited_seat"):
		character.call("on_exited_seat", seat, pos)
	else:
		character.global_position = pos
		character.visible = true
	GroundEvents.bus().seat_changed.emit(peer, seat, crew_seat)
	return Result.OK


## Figur, die in seat sitzt (oder null).
func rider_of(seat: Seat) -> Node3D:
	var c = riders.get(seat)
	return c if is_instance_valid(c) else null


static func vehicle_speed(v: Node) -> float:
	if v == null:
		return 0.0
	if v.has_method("seat_speed"):
		return float(v.call("seat_speed"))
	if v is RigidBody3D:
		return (v as RigidBody3D).linear_velocity.length()
	if v is CharacterBody3D:
		return (v as CharacterBody3D).velocity.length()
	return 0.0


static func vehicle_on_ground(v: Node) -> bool:
	if v == null:
		return true
	if v.has_method("seat_on_ground"):
		return bool(v.call("seat_on_ground"))
	if v is Aircraft:
		return (v as Aircraft).telemetry().on_ground
	if v is CharacterBody3D:
		return (v as CharacterBody3D).is_on_floor()
	return true


static func result_text(r: int) -> String:
	return RESULT_TEXT[r] if r >= 0 and r < RESULT_TEXT.size() else "?"


func _controller_for(c: Controller, role: int) -> Controller:
	var owner_obj: Object = c.session if c.session != null else c
	if owner_obj.has_method("controller_for"):
		var nc = owner_obj.call("controller_for", role)
		if nc is Controller:
			return nc
	return c
