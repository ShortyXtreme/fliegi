extends SceneTree
## Diagnose "Strömungsabriss beim Hochziehen". Schreibt pro Szenario eine CSV nach
## res://tests/diag/out/. Aufruf:
##   godot --headless --path . --fixed-fps 60 --script res://tests/diag/stall_diag.gd [-- --only=a_]
## Optionen: --no-protect (Arcade ohne Stall-Schutz)

const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"
const ARC := FlightAssist.Mode.ARCADE
const REAL := FlightAssist.Mode.REALISTIC
const ALT := 1500.0

var world: TestWorld
var only := ""
var no_protect := false
var alt_lim := false
var suffix := ""
var out_dir := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		if a == "--no-protect":
			no_protect = true
			suffix = "_noprot"
		if a == "--alt-limiter":
			alt_lim = true
			suffix = "_altlim"
	out_dir = ProjectSettings.globalize_path("res://tests/diag/out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void:
	# [name, scenario, mode, input]
	var list := []
	for m in [ARC, REAL]:
		var mn := "arc" if m == ARC else "real"
		for inp in ["kb", "stick"]:
			for sc in ["a", "b", "c"]:
				list.append(["%s_%s_%s" % [sc, mn, inp], sc, m, inp])
	for inp in ["mouse30", "mouse60", "mouseflick"]:
		list.append(["a_arc_" + inp, "a", ARC, inp])
	for inp in ["mouse20", "mouse30"]:
		list.append(["b_arc_" + inp, "b", ARC, inp])
	list.append(["c_arc_mouseslow", "c", ARC, "mouseslow"])
	for v in [200, 230, 260, 290, 320]:
		list.append(["d_real_climb%d" % v, "d", REAL, str(v)])
	for e in list:
		if only != "" and not e[0].contains(only):
			continue
		world = TestWorld.new()
		root.add_child(world)
		await physics_frame
		await _scenario(e[0] + suffix, e[1], e[2], e[3])
		world.queue_free()
		await physics_frame
	quit(0)


static func pitch_deg(ac: Aircraft) -> float:
	return rad_to_deg(asin(clampf(-ac.global_transform.basis.z.y, -1.0, 1.0)))


static func aim_at(elev_deg: float) -> Vector3:
	var d := TestWorld.RUNWAY_DIR
	return (d * cos(deg_to_rad(elev_deg)) + Vector3.UP * sin(deg_to_rad(elev_deg))).normalized()


func _scenario(name: String, sc: String, mode: int, inp: String) -> void:
	var speed := 97.2 if sc != "c" else 69.4
	var alt0 := ALT if sc != "d" else 300.0
	if sc == "d":
		speed = float(inp) / 3.6
	var a := Aircraft.create(load(FIGHTER), false)
	a.assist = DiagAssist.new(a.data)
	if no_protect:
		a.assist.stall_protection = false
	(a.assist as DiagAssist).alt_limiter = alt_lim
	world.add_child(a)
	a.place(Transform3D(Basis.looking_at(TestWorld.RUNWAY_DIR, Vector3.UP), Vector3(0, alt0, 0)), speed, 1.0)
	var settle := 3.0
	var dur: float = {"a": 6.0, "b": 70.0, "c": 25.0, "d": 40.0}[sc]
	var st := {"t": 0.0, "kb": 0.0}
	var is_mouse := inp.begins_with("mouse")
	var pc: PlayerController = null
	var hold := func(ac: Aircraft, i: PilotIntent) -> void:
		var t := ac.telemetry()
		i.pitch = clampf(-t.climb_rate * 0.05 - t.angular_velocity_local.x * 0.8 + (speed - t.airspeed) * 0.0, -1.0, 1.0)
		if mode == ARC:
			i.pitch = clampf(-t.climb_rate * 0.08, -1.0, 1.0)
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0)
	var ctrl := ScriptedController.new()
	ctrl.logic = func(ac: Aircraft, i: PilotIntent, dt: float) -> void:
		st.t += dt
		i.assist_mode = mode
		i.throttle = 1.0
		var tt: float = float(st.t) - settle
		if tt < 0.0:
			hold.call(ac, i)
			return
		var mx := 0.5 if inp == "stick" else 1.0
		var t := ac.telemetry()
		i.roll = clampf(ac.global_transform.basis.x.y * 3.0, -1.0, 1.0)
		match sc:
			"a":
				if inp == "kb":
					st.kb = move_toward(st.kb, 1.0, PlayerController.KEY_RAMP * dt)  # Tastenrampe
					i.pitch = st.kb if tt < 3.0 else 0.0
				else:
					i.pitch = 0.5 if tt < 3.0 else 0.0
			"b":
				var p := Autopilot.hold_pitch_attitude(ac.global_transform.basis, t.angular_velocity_local.x, 20.0)
				i.pitch = clampf(p, -mx, mx)
			"c":
				i.pitch = minf(tt * 0.06, mx)  # langsam ziehen
			"d":
				# Fahrt halten über Steigwinkel (Realistisch, Vollgas) -> stationäre Steigrate
				var want_vs := clampf((t.airspeed - speed) * 1.5, -30.0, 40.0)
				i.pitch = clampf((want_vs - t.climb_rate) * 0.03 - t.angular_velocity_local.x * 0.8 + 0.05, -1.0, 1.0)
	a.add_child(ctrl)
	a.pilot_seat.possess(ctrl)
	var f := FileAccess.open(out_dir + "/" + name + ".csv", FileAccess.WRITE)
	var hdr := "t,phase,speed_kmh,alt,vs,pitch_deg,aoa_deg,g,thrust,drag,lift,intent_pitch,elev_cmd,elev_raw,limiter,elev_defl_deg,q_rate_dps,stall_amount,aim_elev_deg"
	for s in a.flight.surfaces:
		if s.def.name == "vtail":
			continue
		hdr += ",%s_alpha,%s_cl,%s_stall" % [s.def.name, s.def.name, s.def.name]
	f.store_line(hdr)
	var n := int((settle + dur) * 60.0)
	var aim_elev := 0.0
	for k in n:
		var tt := k / 60.0 - settle
		if is_mouse and tt >= 0.0 and pc == null:
			pc = PlayerController.new()
			pc.force_mouse_aim = true
			pc.assist_mode = ARC
			a.add_child(pc)
			a.pilot_seat.possess(pc)
			pc.throttle = 1.0
		if pc != null:
			match inp:
				"mouse20": aim_elev = 20.0
				"mouse30": aim_elev = 30.0
				"mouse60": aim_elev = 60.0
				"mouseflick": aim_elev = minf(tt / 0.25, 1.0) * 60.0
				"mouseslow": aim_elev = minf(tt * 3.0, 80.0)
			pc.aim_dir = aim_at(aim_elev)
		await physics_frame
		var t := a.telemetry()
		var c := t.commands
		var da := a.assist as DiagAssist
		var row := "%.4f,%s,%.2f,%.1f,%.2f,%.2f,%.2f,%.3f,%.0f,%.0f,%.0f,%.3f,%.3f,%.3f,%d,%.2f,%.2f,%.3f,%.1f" % [
			tt, "settle" if tt < 0 else "man", t.airspeed * 3.6, t.altitude, t.climb_rate, pitch_deg(a),
			rad_to_deg(t.aoa), t.g_load, t.thrust, t.drag, t.lift, a.pilot_seat.intent.pitch, c.elevator,
			da.raw_elevator, 1 if da.limiter_active else 0, -a.data.surfaces[6].max_deflection_deg * c.elevator,
			rad_to_deg(t.angular_velocity_local.x), t.stall_amount, aim_elev]
		for s in a.flight.surfaces:
			if s.def.name == "vtail":
				continue
			row += ",%.2f,%.3f,%.3f" % [rad_to_deg(s.last_alpha), s.last_lift_coef, s.last_stall_t]
		f.store_line(row)
	f.close()
	print("ok ", name)
