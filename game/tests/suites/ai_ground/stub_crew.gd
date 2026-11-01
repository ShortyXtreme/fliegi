extends Node3D
## Test-Stub einer Figur (Vertrag CrewCharacter): Sitz CREW, folgt dem CrewIntent waagerecht
## mit Gehen 1,6 / Sprint 4,5 m/s, Bewegung relativ zu look_yaw (0 = Blick nach -Z).

var crew_seat: Seat
var carried = null
var in_seat: Seat = null
var velocity := Vector3.ZERO
var walked := 0.0


func _init() -> void:
	crew_seat = Seat.new()
	crew_seat.role = Seat.Role.CREW
	crew_seat.vehicle = self
	add_child(crew_seat)


func _physics_process(dt: float) -> void:
	var i := crew_seat.poll_crew(dt)
	var fwd := Vector3(-sin(i.look_yaw), 0.0, -cos(i.look_yaw))
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var sp := CrewCharacter.SPRINT_SPEED if i.sprint else CrewCharacter.WALK_SPEED
	velocity = (right * i.move.x + fwd * i.move.y).limit_length(1.0) * sp
	global_position += velocity * dt
	walked += velocity.length() * dt
