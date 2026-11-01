extends RefCounted
## Helfer für die Flugbetriebs-Tests (Strang C).

const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"


## KI-Maschine am Abstellplatz spot von Platz field (TerrainWorld) mit Flugplatz-Phasen.
static func ai_at_parking(world: TerrainWorld, field: int, spot: int, seed: int,
		eid: int = 0) -> AIPilotBrain:
	var l := world.airfield_layout(field)
	var a := Aircraft.create(load(FIGHTER), false)
	a.nation_id = l.nation_id if l.nation_id >= 0 else Nations.RED
	if eid > 0:
		a.entity_id = eid
	world.add_child(a)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed) ^ 0x7a1
	var xf := l.parking_transform(spot)
	var h := (-xf.basis.z).rotated(Vector3.UP, deg_to_rad(rng.randf_range(-4.0, 4.0)))
	var pos := xf.origin + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
	a.place_on_ground(pos, h, true, ServiceState.make(rng.randf_range(0.6, 1.0), 1.0))
	var br := AIPilotBrain.new()
	br.rng_seed = seed
	br.airfield = AirfieldPhases.new()
	br.airfield.setup(l, RunwayControl.find_or_create(world, field), spot)
	a.add_child(br)
	a.pilot_seat.possess(br)
	return br


static func trace_line(a: Aircraft, ph: AirfieldPhases) -> String:
	var t := a.telemetry()
	var b := a.global_transform.basis
	var l := ph.layout.to_local(a.global_position) if ph.layout else a.global_position
	return "%s/%d v=%5.1f agl=%5.1f vs=%5.1f pitch=%5.1f up=%.2f wheels=%d pos=(%.0f,%.0f) hdg=%.0f thr=%.2f yaw=%+.2f r=%+.2f" % [
		ph.phase_name(), ph._sub, t.airspeed * 3.6, t.height_agl, t.climb_rate,
		rad_to_deg(asin(clampf(-b.z.y, -1, 1))), b.y.y, t.wheels_in_contact, l.x, l.z,
		rad_to_deg(atan2(-b.z.x, b.z.z)), t.throttle_actual, t.commands.rudder, -t.angular_velocity_local.y]
