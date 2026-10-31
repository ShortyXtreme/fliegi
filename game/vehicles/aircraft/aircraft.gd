class_name Aircraft
extends RigidBody3D
## Flugzeug: RigidBody mit FlightModel. Wird komplett im Code aufgebaut:
##   var a := Aircraft.create(load("res://vehicles/aircraft/data/fighter_t1.tres"))
## Eingaben kommen ausschließlich über den Pilotensitz (Seat -> PilotIntent).

signal crashed(aircraft: Aircraft)

var data: AircraftData
var flight: FlightModel
var assist: FlightAssist
var pilot_seat: Seat
var visual: AircraftVisual
## Vom Server erlaubte Hilfen-Modi (Lobby-Einstellung).
var allowed_assist_modes: Array[int] = [FlightAssist.Mode.ARCADE, FlightAssist.Mode.REALISTIC]
var assist_mode: int = FlightAssist.Mode.ARCADE

var _intent := PilotIntent.new()
var _exclude: Array[RID] = []


static func create(d: AircraftData, with_visual: bool = true) -> Aircraft:
	var a := Aircraft.new()
	a.data = d
	a._build(with_visual)
	return a


func _build(with_visual: bool) -> void:
	name = "Aircraft"
	mass = data.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.ZERO
	inertia = data.inertia
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.05
	physics_material_override = pm
	contact_monitor = true
	max_contacts_reported = 4

	_add_box(data.fuselage_box_center, data.fuselage_box_size)
	_add_box(data.wing_box_center, data.wing_box_size)

	flight = FlightModel.new(data)
	assist = FlightAssist.new(data)

	pilot_seat = Seat.new()
	pilot_seat.name = "PilotSeat"
	pilot_seat.vehicle = self
	add_child(pilot_seat)

	if with_visual:
		visual = AircraftVisual.new()
		visual.name = "Visual"
		add_child(visual)
		visual.build(data)


func _add_box(center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = center
	add_child(cs)


func _ready() -> void:
	_exclude = [get_rid()]
	body_entered.connect(_on_body_entered)


func _physics_process(dt: float) -> void:
	var i := pilot_seat.poll(dt)
	_intent.copy_from(i)
	# Server entscheidet, ob der gewünschte Modus erlaubt ist.
	if Authority.is_server() and _intent.assist_mode in allowed_assist_modes:
		assist_mode = _intent.assist_mode
	_intent.assist_mode = assist_mode
	if visual:
		visual.update_controls(flight.telemetry, dt)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var cmd := assist.apply(_intent, flight.telemetry, state.step)
	flight.telemetry.assist_mode = assist_mode
	flight.integrate(state, cmd, _exclude)


## Telemetrie für HUD/KI/Tests.
func telemetry() -> FlightTelemetry:
	return flight.telemetry


## Setzt das Flugzeug an eine Position (Server). speed in m/s entlang der Nase.
func place(xf: Transform3D, speed: float = 0.0, throttle: float = 0.0,
		gear_down: bool = true) -> void:
	global_transform = xf
	linear_velocity = -xf.basis.z * speed
	angular_velocity = Vector3.ZERO
	flight.reset(gear_down)
	if visual:
		visual.snap_gear(flight.gear.extension)
	flight.engine.throttle_actual = throttle
	reset_physics_interpolation()


## Startposition auf der Piste: Heck unten, Fahrwerk auf dem Boden.
func place_on_ground(pos: Vector3, heading_dir: Vector3) -> void:
	var fwd := heading_dir.normalized()
	var b := Basis.looking_at(fwd, Vector3.UP)
	b = b * Basis(Vector3.RIGHT, deg_to_rad(data.ground_pitch_deg))
	place(Transform3D(b, pos + Vector3.UP * data.ground_height), 0.0, 0.0)


func _on_body_entered(_body: Node) -> void:
	var t := flight.telemetry
	if linear_velocity.length() > 25.0 or t.wheels_in_contact == 0 and absf(t.climb_rate) > 6.0:
		crashed.emit(self)
