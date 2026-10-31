class_name FlightModel
extends RefCounted
## Schmale Schnittstelle zur Flugphysik:
##   var fm := FlightModel.new(data)
##   fm.integrate(state, commands, exclude_rids)  # in _integrate_forces
##   fm.telemetry                                 # Messwerte
## Alles Aerodynamische (Flächen, Motor, Fahrwerk) steckt hier drin und kann
## später durch ein anderes Modell ersetzt werden, ohne Sitz/Controller zu ändern.

const SEA_LEVEL_RHO := 1.225
const SCALE_HEIGHT := 8500.0
## Vorwarnung (Buffet) beginnt so viele Grad vor dem Abriss-Anstellwinkel.
const BUFFET_ONSET := deg_to_rad(3.0)

var data: AircraftData
var surfaces: Array[AeroSurface] = []
var engine: PropEngine
var gear: LandingGear
var telemetry := FlightTelemetry.new()
## Wenn true, werden Kraftpfeile für das Debug-Overlay gesammelt: [ort, kraft, farbe].
var collect_debug: bool = false
var debug_vectors: Array = []
var _prev_velocity := Vector3.ZERO
var _order: Array[AeroSurface] = []   # Flügel zuerst, dann Flächen im Abwind
var _wing_area := 0.0
var _wing_slope := 4.4
var _wing_cl_ref := 0.0               # Flügel-CL bei Rumpf-AoA 0 (Bezug für den Abwind)
var _downwash := 0.0                  # verzögerter Abwindwinkel am Leitwerk (rad)
var _tail_arm := 5.4
var _prev_aoa := 0.0


func _init(d: AircraftData) -> void:
	data = d
	for s in d.surfaces:
		surfaces.append(AeroSurface.new(s))
	engine = PropEngine.new(d)
	gear = LandingGear.new(d)
	var cl_ref_sum := 0.0
	for s in surfaces:
		if s.def.downwash_factor <= 0.0:
			_order.append(s)
		if s.def.is_main_wing:
			_wing_area += s.area
			_wing_slope = s.lift_slope
			cl_ref_sum += s.lift_slope * (deg_to_rad(s.def.rotation_deg.x) - s.alpha0) * s.area
	for s in surfaces:
		if s.def.downwash_factor > 0.0:
			_order.append(s)
			_tail_arm = absf(s.def.position.z)
	_wing_cl_ref = cl_ref_sum / maxf(_wing_area, 1e-3)
	for s in surfaces:
		if s.def.is_main_wing:
			telemetry.stall_aoa = s.body_stall_aoa()
			break
	telemetry.stall_aoa_base = telemetry.stall_aoa


static func air_density(altitude: float) -> float:
	return SEA_LEVEL_RHO * exp(-maxf(altitude, 0.0) / SCALE_HEIGHT)


## Leistungsfaktor des Motors (Lader): bis zur Volldruckhöhe 1, darüber ∝ Luftdichte.
func power_factor(altitude: float) -> float:
	var crit := data.engine_critical_altitude
	if altitude <= crit:
		return 1.0
	return air_density(altitude) / air_density(crit)


## Anstellwinkel (Rumpf), bei dem der Hauptflügel mit der aktuellen Klappenstellung abreißt.
func effective_stall_aoa(flaps: float) -> float:
	var best := INF
	for s in surfaces:
		if not s.def.is_main_wing:
			continue
		var cmd := flaps if s.def.control_axis == AeroSurfaceDef.ControlAxis.FLAPS else 0.0
		best = minf(best, s.body_stall_aoa_with(cmd))
	return best if best < INF else telemetry.stall_aoa_base


func integrate(state: PhysicsDirectBodyState3D, cmd: ControlCommands, exclude: Array[RID]) -> void:
	var xf := state.transform
	var b := xf.basis
	var vel := state.linear_velocity
	var ang := state.angular_velocity
	var dt := state.step
	var rho := air_density(xf.origin.y)
	debug_vectors.clear()
	var dbg = debug_vectors if collect_debug else null
	var v_local := b.transposed() * vel
	var speed := vel.length()
	var ang_local := b.transposed() * ang

	# --- Aerodynamik je Fläche (Flügel zuerst, dann Leitwerk im Abwind) ---
	var aero_total := Vector3.ZERO
	var stall_sum := 0.0
	var stall_n := 0
	var wing_cl := 0.0
	var dw_done := false
	for s in _order:
		var r := b * s.def.position
		var v_point := vel + ang.cross(r)
		var eps := 0.0
		if s.def.downwash_factor > 0.0:
			if not dw_done:
				dw_done = true
				var cl_w := wing_cl / maxf(_wing_area, 1e-3)
				var target := data.downwash_gradient * (cl_w - _wing_cl_ref) / maxf(_wing_slope, 0.1)
				# Abwind braucht die Laufzeit Flügel -> Leitwerk (α̇-Effekt, dämpft Überschwingen)
				var k := clampf(dt * maxf(speed, 1.0) / _tail_arm, 0.0, 1.0)
				_downwash = lerpf(_downwash, target, k)
			eps = _downwash * s.def.downwash_factor
		var f := s.compute(-v_point, b, rho, cmd.axis_value(s.def.control_axis), eps)
		state.apply_force(f, r)
		aero_total += f
		if s.def.is_main_wing:
			stall_sum += s.last_stall_t
			stall_n += 1
			wing_cl += s.last_lift_coef * s.area
		if dbg != null:
			dbg.append([xf.origin + r, f, Color(0.2, 1.0, 0.3)])

	# --- Nickdämpfung (Flügel/Rumpf, Cmq) ---
	var q_dyn := 0.5 * rho * speed * speed
	if speed > 5.0:
		var c := data.mean_chord
		var m_damp := data.pitch_damping_cmq * ang_local.x * c / (2.0 * speed) * q_dyn * _wing_area * c
		state.apply_torque(b.x * m_damp)

	# --- Rumpf- und Fahrwerkswiderstand ---
	var q := 0.5 * rho
	var drag_area := data.fuselage_drag_area + data.gear_drag_area * gear.extension
	var fus_local := Vector3(
		-v_local.x * absf(v_local.x) * q * data.fuselage_side_area * 0.5,
		-v_local.y * absf(v_local.y) * q * data.fuselage_side_area * 0.5,
		-v_local.z * absf(v_local.z) * q * drag_area)
	var fus := b * fus_local
	state.apply_central_force(fus)
	aero_total += fus

	# --- Antrieb ---
	var axial := -v_local.z
	var thrust := engine.update(dt, cmd.throttle, axial, power_factor(xf.origin.y))
	var thrust_vec := -b.z * thrust
	var r_eng := b * data.engine_position
	state.apply_force(thrust_vec, r_eng)
	if dbg != null:
		dbg.append([xf.origin + r_eng, thrust_vec, Color(1.0, 0.6, 0.1)])

	# --- Fahrwerk (inkl. Ein-/Ausfahren und Bauchkufen) ---
	var contacts := gear.integrate(state, cmd, exclude, dbg)

	# --- Telemetrie ---
	var t := telemetry
	t.airspeed = speed
	t.altitude = xf.origin.y
	t.aoa = atan2(-v_local.y, -v_local.z) if speed > 1.0 else 0.0
	t.aoa_rate = (t.aoa - _prev_aoa) / dt if speed > 10.0 else 0.0
	_prev_aoa = t.aoa
	t.sideslip = atan2(v_local.x, -v_local.z) if speed > 1.0 else 0.0
	t.stall_amount = stall_sum / maxf(stall_n, 1)
	t.stall_aoa = effective_stall_aoa(cmd.flaps)
	t.downwash = _downwash
	t.thrust = thrust
	t.throttle_actual = engine.throttle_actual
	t.wheels_in_contact = contacts
	t.belly_contact = gear.belly_contacts > 0
	t.on_ground = contacts > 0 or t.belly_contact
	t.gear_extension = gear.extension
	t.gear_down_cmd = gear.target_down
	t.gear_blocked = gear.blocked
	t.gear_overspeed = gear.extension > 0.02 and speed > data.gear_max_speed
	t.climb_rate = vel.y
	t.pitch_attitude = asin(clampf(-b.z.y, -1.0, 1.0))
	t.pitch_up_vector = b.y
	t.angular_velocity_local = ang_local
	t.aero_force = aero_total
	t.thrust_force = thrust_vec
	t.weight_force = Vector3.DOWN * state.total_gravity.length() / maxf(state.inverse_mass, 1e-6)
	t.commands = cmd
	# Buffet (Vorwarnung): steigt in den letzten BUFFET_ONSET Grad vor dem Abriss an,
	# im Abriss voll.
	if t.on_ground or speed < 15.0:
		t.buffet = 0.0
	else:
		var pre := clampf((t.aoa - (t.stall_aoa - BUFFET_ONSET)) / BUFFET_ONSET, 0.0, 1.0)
		t.buffet = clampf(maxf(pre * 0.7, t.stall_amount), 0.0, 1.0) * clampf(speed / 40.0, 0.3, 1.0)
	if speed > 1.0:
		var vdir := vel / speed
		var total_nongrav := aero_total + thrust_vec
		t.drag = -total_nongrav.dot(vdir) + thrust_vec.dot(vdir)
		t.lift = (aero_total - vdir * aero_total.dot(vdir)).length()
	else:
		t.drag = 0.0
		t.lift = 0.0
	var accel := (vel - _prev_velocity) / dt
	_prev_velocity = vel
	var g := state.total_gravity.length()
	if g > 0.0:
		t.g_load = (accel - state.total_gravity).dot(b.y) / g
	var ray := PhysicsRayQueryParameters3D.create(xf.origin, xf.origin + Vector3.DOWN * 5000.0)
	ray.exclude = exclude
	var hit := state.get_space_state().intersect_ray(ray)
	t.height_agl = xf.origin.y - hit.position.y if not hit.is_empty() else xf.origin.y


func reset(gear_down: bool = true) -> void:
	gear.reset(gear_down)
	_prev_velocity = Vector3.ZERO
	_downwash = 0.0
	_prev_aoa = 0.0
	engine.throttle_actual = 0.0
