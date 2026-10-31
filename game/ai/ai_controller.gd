class_name AIController
extends Controller
## Einfache KI: startet von der Piste, steigt auf Reiseflughöhe und kreist dann
## um einen Punkt (oder fliegt geradeaus). Nutzt nur den Intent-Weg – kein
## direkter Zugriff auf Physik oder Ruder. Liest die Telemetrie wie ein Instrument.

enum Behaviour { STRAIGHT, CIRCLE }
enum Phase { TAKEOFF_ROLL, CLIMB, CRUISE }

@export var behaviour: Behaviour = Behaviour.CIRCLE
@export var cruise_altitude: float = 400.0
@export var circle_center: Vector3 = Vector3(0, 0, -1200)
@export var circle_radius: float = 900.0
@export var cruise_throttle: float = 0.8
@export var rotate_speed: float = 42.0   # m/s (~150 km/h)

var phase: Phase = Phase.TAKEOFF_ROLL
var _intent := PilotIntent.new()
var _heading := Vector3.FORWARD


func on_possess(s: Seat) -> void:
	super.on_possess(s)
	var v := get_vehicle()
	if v:
		_heading = -v.global_transform.basis.z
		_heading.y = 0
		_heading = _heading.normalized()
		var a := v as Aircraft
		phase = Phase.TAKEOFF_ROLL if a and a.linear_velocity.length() < 15.0 else Phase.CRUISE
		_intent.gear_down = phase == Phase.TAKEOFF_ROLL


static func t_agl(a: Aircraft) -> float:
	return a.telemetry().height_agl if a else 0.0


func compute_intent(_dt: float) -> PilotIntent:
	var a := get_vehicle() as Aircraft
	var i := _intent
	i.assist_mode = FlightAssist.Mode.ARCADE
	i.brakes = 0.0
	# Fahrwerk nach dem Abheben ab 40 m einfahren (einmalig, bleibt dann drin)
	if phase != Phase.TAKEOFF_ROLL and t_agl(a) > 40.0:
		i.gear_down = false
	if a == null:
		return i
	var t := a.telemetry()
	var b := a.global_transform.basis
	var pos := a.global_position
	match phase:
		Phase.TAKEOFF_ROLL:
			i.throttle = 1.0
			i.flaps = 0.5
			i.roll = 0.0
			i.yaw = Autopilot.hold_heading(b, -t.angular_velocity_local.y, _heading)
			# Heck am Boden halten bis Rotationsgeschwindigkeit, dann ziehen
			i.pitch = 0.0 if t.airspeed < rotate_speed else 0.5
			if not t.on_ground and t.height_agl > 8.0:
				phase = Phase.CLIMB
		Phase.CLIMB:
			i.throttle = 1.0
			i.flaps = 0.0 if t.height_agl > 60.0 else 0.5
			var dir := _heading + Vector3.UP * 0.18
			var s := Autopilot.steer_to_direction(b, dir.normalized())
			i.pitch = s.x; i.roll = s.y; i.yaw = 0.0
			if pos.y > cruise_altitude - 30.0:
				phase = Phase.CRUISE
		Phase.CRUISE:
			i.throttle = cruise_throttle
			i.flaps = 0.0
			var target_dir := _heading
			if behaviour == Behaviour.CIRCLE:
				var to_c := circle_center - pos
				to_c.y = 0.0
				var radial := -to_c.normalized()
				var tangent := Vector3.UP.cross(radial)  # gegen den Uhrzeigersinn
				var dist_err := to_c.length() - circle_radius
				target_dir = (tangent + (-radial) * clampf(dist_err / circle_radius, -0.6, 0.6)).normalized()
			var climb := clampf((cruise_altitude - pos.y) / 300.0, -0.25, 0.25)
			var s := Autopilot.steer_to_direction(b, (target_dir + Vector3.UP * climb).normalized())
			i.pitch = s.x; i.roll = s.y; i.yaw = 0.0
	return i.clamp_values()
