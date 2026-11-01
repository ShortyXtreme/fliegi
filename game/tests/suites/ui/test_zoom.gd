extends TestSuite
## M2.1 Ziel-Zoom: Modusregeln, Sichtfeld, Empfindlichkeit, Kamera; Vorhalt-Qualität.

const ARC := FlightAssist.Mode.ARCADE
const REAL := FlightAssist.Mode.REALISTIC


func test_zoom_mode_rules() -> Array:
	var d: AircraftData = load(FIGHTER)
	var up := d.duplicate() as AircraftData
	up.has_zoom_sight = true
	up.sight_zoom_factor = 1.8
	var a_arc := ZoomRules.allowed(ARC, d)
	var a_real := ZoomRules.allowed(REAL, d)
	var a_real_up := ZoomRules.allowed(REAL, up)
	var f_up := ZoomRules.factor(REAL, up)
	MatchRules.realistic_zoom = MatchRules.RealisticZoom.ALWAYS
	var a_always := ZoomRules.allowed(REAL, d)
	MatchRules.realistic_zoom = MatchRules.RealisticZoom.NEVER
	var a_never := ZoomRules.allowed(REAL, up)
	var a_never_arc := ZoomRules.allowed(ARC, d)
	MatchRules.reset()
	var ok := a_arc and not a_real and a_real_up and absf(f_up - 1.8) < 1e-4 and a_always \
		and not a_never and a_never_arc and not d.has_zoom_sight
	return [ok, "Arcade %s, Realistisch Tier I %s, mit Visier %s (×%.1f), Lobby immer %s / nie %s (Arcade %s)" % [
		a_arc, a_real, a_real_up, f_up, a_always, a_never, a_never_arc]]


func test_zoom_fov_sensitivity_camera() -> Array:
	var a := _spawn(false, 800.0, 100.0, 0.7)
	var pc := PlayerController.new()
	a.add_child(pc)
	a.pilot_seat.possess(pc)
	var cam := CameraRig.new()
	cam.target = a
	cam.player = pc
	world.add_child(cam)
	await _step(30)
	var fov0 := cam.camera.fov
	var sens0 := pc.mouse_sens()
	pc.zoom_override = true
	await _step(5)
	var mid := pc.zoom_amount
	await _step(55)
	var fov1 := cam.camera.fov
	var sens1 := pc.mouse_sens()
	var mul := pc.zoom_mul()
	# Cockpit
	cam.next_mode()
	await _step(3)
	var fov_c := cam.camera.fov
	cam.next_mode()
	cam.next_mode()
	# Realistisch ohne Visier: kein Zoom
	pc.assist_mode = REAL
	await _step(60)
	var fov_r := cam.camera.fov
	var mul_r := pc.zoom_mul()
	pc.zoom_override = false
	cam.queue_free()
	var ok := fov1 < fov0 * 0.5 and fov1 > fov0 * 0.35 and mid > 0.2 and mid < 0.95 \
		and absf(sens1 * mul - sens0) < 1e-6 and fov_c < 45.0 and mul_r < 1.01 \
		and absf(fov_r - fov0) < 3.0
	return [ok, "Verfolger %.1f° → %.1f° (×%.2f, nach 5 Ticks %.0f %%), Maus %.5f → %.5f, Cockpit %.1f°, Realistisch ×%.2f %.1f°" % [
		fov0, fov1, mul, mid * 100.0, sens0, sens1, fov_c, mul_r, fov_r]]


func test_lead_on_target() -> Array:
	var fwd := Vector3.FORWARD
	var near := fwd.rotated(Vector3.UP, deg_to_rad(0.5))
	var far := fwd.rotated(Vector3.UP, deg_to_rad(2.0))
	var a := TargetOverlay.lead_on_target(fwd, near, 300.0)    # 2,6 m
	var b := TargetOverlay.lead_on_target(fwd, far, 300.0)     # 10,5 m
	var c := TargetOverlay.lead_on_target(fwd, near, 600.0)    # 5,2 m
	return [a and not b and not c, "0,5° auf 300 m: %s, 2° auf 300 m: %s, 0,5° auf 600 m: %s" % [a, b, c]]
