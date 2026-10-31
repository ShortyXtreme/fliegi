extends SceneTree
## Erzeugt res://vehicles/aircraft/data/fighter_t1.tres aus lesbaren Kennzahlen.
## Aufruf: godot --headless --path . --script res://tools/build_fighter_t1.gd
## Die .tres kann danach auch direkt im Editor bearbeitet werden.

func _init() -> void:
	var d := make()
	var err := ResourceSaver.save(d, "res://vehicles/aircraft/data/fighter_t1.tres")
	print("fighter_t1.tres gespeichert: ", error_string(err))
	quit(0 if err == OK else 1)


static func surf(n: String, pos: Vector3, rot: Vector3, span: float, chord: float, axis: int,
		sign: float, max_defl: float, main: bool, ar: float, alpha0: float, stall: float,
		flap_frac: float = 0.25) -> AeroSurfaceDef:
	var s := AeroSurfaceDef.new()
	s.name = n
	s.position = pos
	s.rotation_deg = rot
	s.span = span
	s.chord = chord
	s.control_axis = axis
	s.control_sign = sign
	s.max_deflection_deg = max_defl
	s.is_main_wing = main
	s.aspect_ratio = ar
	s.zero_lift_aoa_deg = alpha0
	s.stall_angle_high_deg = stall
	s.stall_angle_low_deg = -stall + 2.0
	s.flap_fraction = flap_frac
	return s


# Höhenruder: M1 hatte 30° / 45 % Rudertiefe (Nickrate 87°/s, AoA schoss über).
const HTAIL_DEFL := 24.0
const HTAIL_FLAP := 0.38


static func make() -> AircraftData:
	var d := AircraftData.new()
	d.display_name = "Jäger T1 \"Falke\""
	d.tier = 1
	d.mass = 2500.0
	d.inertia = Vector3(8000, 13000, 6000)   # Nicken, Gieren, Rollen
	d.engine_power_w = 700000.0
	d.static_thrust_n = 11500.0
	d.prop_efficiency = 0.8
	d.engine_position = Vector3(0, 0, -3.2)
	d.engine_critical_altitude = 4000.0   # Volldruckhöhe Lader
	d.idle_throttle = 0.04
	d.prop_blend_exponent = 2.5
	d.fuselage_drag_area = 0.17           # M1.1: CD0 realistischer (vorher 0,10)
	d.fuselage_side_area = 4.0
	d.downwash_gradient = 0.4
	d.pitch_damping_cmq = -6.0
	d.mean_chord = 1.85
	d.gear_drag_area = 0.08
	d.gear_transition_time = 6.5
	d.gear_max_speed = 300.0 / 3.6
	d.realistic_elevator_ref_speed = 240.0 / 3.6
	d.elevator_per_aoa = 0.038
	d.realistic_elevator_exponent = 1.5

	const A := AeroSurfaceDef.ControlAxis
	var wing_ar := 7.0
	var incid := 2.0
	var dihedral := 5.0
	var segs := [
		# name, x, span, chord, axis, max_defl
		["root", 1.35, 1.5, 2.15, A.FLAPS, 35.0],
		["mid", 2.9, 1.6, 1.85, A.FLAPS, 35.0],
		["tip", 4.5, 1.6, 1.5, A.ROLL, 18.0],
	]
	var surfaces: Array[AeroSurfaceDef] = []
	for side in [1.0, -1.0]:
		for g in segs:
			var x: float = g[1] * side
			var y: float = -0.3 + absf(x) * tan(deg_to_rad(dihedral))
			var sign := 1.0
			if g[4] == A.ROLL:
				sign = -side   # rechts rollen: rechtes Querruder hoch, linkes runter
			var s := surf("wing_%s_%s" % ["R" if side > 0 else "L", g[0]],
				Vector3(x, y, 0.05), Vector3(incid, 0, dihedral * side), g[2], g[3], g[4], sign,
				g[5], true, wing_ar, -2.5, 16.0)   # M1.1: 16° (weiche Kurve, CL_max ≈ 1,37)
			# Außenflügel reißt etwas später ab (Schränkung) -> gutmütiger Abriss
			if g[0] == "tip":
				s.rotation_deg.x = incid - 1.5
			surfaces.append(s)
	# Höhenleitwerk mit Höhenruder (symmetrisches Profil)
	for side in [1.0, -1.0]:
		var s := surf("htail_%s" % ("R" if side > 0 else "L"), Vector3(1.0 * side, 0.14, 5.45),
			Vector3(-0.5, 0, 0), 1.8, 1.0, A.PITCH, -1.0, HTAIL_DEFL, false, 4.5, 0.0, 18.0,
			HTAIL_FLAP)
		s.downwash_factor = 1.0   # liegt im Abwind des Flügels
		surfaces.append(s)
	# Seitenleitwerk mit Seitenruder (Normale zeigt nach -X / links)
	var fin := surf("vtail", Vector3(0, 0.8, 5.5), Vector3(0, 0, 90), 1.4, 1.2, A.YAW, 1.0,
		25.0, false, 2.0, 0.0, 18.0, 0.4)
	surfaces.append(fin)
	d.surfaces = surfaces

	var wheels: Array[WheelDef] = []
	for side in [1.0, -1.0]:
		var w := WheelDef.new()
		w.name = "main_%s" % ("R" if side > 0 else "L")
		w.position = Vector3(1.55 * side, -1.0, -0.6)
		w.brake_friction = 0.45
		w.rest_length = 0.6
		w.radius = 0.34
		w.spring = 90000.0
		w.damper = 9000.0
		w.has_brake = true
		wheels.append(w)
	var tw := WheelDef.new()
	tw.name = "tail"
	tw.position = Vector3(0, -0.1, 5.84)
	tw.rest_length = 0.3
	tw.radius = 0.12
	tw.spring = 30000.0
	tw.damper = 4000.0
	tw.steer_max_deg = 25.0    # Seitenruder rechts -> Heckrad zeigt nach links -> Nase nach rechts
	tw.lateral_friction = 0.7
	tw.retractable = false     # Spornrad fest
	wheels.append(tw)
	d.wheels = wheels

	d.fuselage_box_center = Vector3(0, 0.1, 1.3)
	d.fuselage_box_size = Vector3(1.05, 0.9, 8.4)
	d.wing_box_center = Vector3(0, -0.2, 0.6)
	d.wing_box_size = Vector3(10.7, 0.3, 2.2)

	d.model_path = "res://vehicles/aircraft/models/fighter_t1.glb"
	d.model_rotation_deg = Vector3(0, 180, 0)   # glTF +Z vorn -> Godot -Z vorn
	# Modell ist maßstäblich (10,7 m Spannweite). Verschiebung: Flügel-t/4 auf Schwerpunkt.
	d.model_offset = Vector3(0, 0, 1.5)
	d.model_fit_span = 0.0
	d.cockpit_eye = Vector3(0, 0.88, 1.45)
	d.propeller_position = Vector3(0, -0.06, -2.9)
	d.engine_position = Vector3(0, 0, -2.6)
	d.ground_height = 1.655   # M1.1: Ruhelage (Federn eingefedert) -> kein Nachfedern beim Spawn
	d.ground_pitch_deg = 12.4
	return d
