class_name CrewCharacter
extends CharacterBody3D
## M3 Stub (Paket 0b, gehört Strang H / Paket 4–5): Figur zu Fuß. Ist ein „Fahrzeug“ mit
## einem Sitz Seat.Role.CREW (crew_seat). Gehen 1,6 m/s, Sprint 4,5 m/s, folgt height_at.
## Trageplatz carried (Kiste, Schlauchende, Kanister, Werkzeug).
## SeatService-Haken: on_entered_seat(seat), on_exited_seat(seat, pos).

const WALK_SPEED := 1.6
const SPRINT_SPEED := 4.5

var crew_seat: Seat
var nation_id: int = Nations.BLUE
## Getragener Gegenstand (Node oder Id) oder null.
var carried = null
## Sitz, in dem die Figur gerade sitzt (null = zu Fuß).
var in_seat: Seat = null


func _init() -> void:
	collision_layer = Layers.CHARACTER
	collision_mask = Layers.WORLD | Layers.AIRCRAFT | Layers.GROUND_VEHICLE
	crew_seat = Seat.new()
	crew_seat.name = "CrewSeat"
	crew_seat.role = Seat.Role.CREW
	crew_seat.vehicle = self
	add_child(crew_seat)


func on_entered_seat(s: Seat) -> void:
	in_seat = s
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func on_exited_seat(_s: Seat, pos: Vector3) -> void:
	in_seat = null
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	global_position = pos
	velocity = Vector3.ZERO


func seat_speed() -> float:
	return velocity.length()


func seat_on_ground() -> bool:
	return true
