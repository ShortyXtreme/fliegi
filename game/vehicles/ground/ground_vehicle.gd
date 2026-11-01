class_name GroundVehicle
extends CharacterBody3D
## M3 Stub (Paket 0b, gehört Strang H / Paket 6): Bodenfahrzeug, kinematisches Fahrmodell
## (Einspurmodell auf WorldGround.height_at, ≤ MAX_SPEED, Kollisionskapsel), deterministisch,
## ohne VehicleBody3D. Sitze: driver_seat (DRIVER), passenger_seat (PASSENGER); Eingabe über
## PilotIntent (throttle, yaw = Lenkung, brakes). Marker: seat_driver, ground_clip.

const MAX_SPEED := 35.0 / 3.6

var driver_seat: Seat
var passenger_seat: Seat
var nation_id: int = Nations.BLUE
var speed := 0.0


func _init() -> void:
	collision_layer = Layers.GROUND_VEHICLE
	collision_mask = Layers.WORLD | Layers.AIRCRAFT | Layers.GROUND_VEHICLE | Layers.CHARACTER
	driver_seat = _make_seat("DriverSeat", Seat.Role.DRIVER, Vector3(-1.4, 0, -1.0))
	passenger_seat = _make_seat("PassengerSeat", Seat.Role.PASSENGER, Vector3(1.4, 0, -1.0))


func _make_seat(n: String, r: int, entry: Vector3) -> Seat:
	var s := Seat.new()
	s.name = n
	s.role = r
	s.vehicle = self
	s.entry_offset = entry
	add_child(s)
	return s


func seat_speed() -> float:
	return absf(speed)


func seat_on_ground() -> bool:
	return true
