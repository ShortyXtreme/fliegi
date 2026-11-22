extends TestSuite
## M3.5 (Agent B): Absturz statt Verschwinden – Flügelbruch trennt den Flügel ab (Debris, Rollen),
## Leitwerk ab, Abschuss in der Luft -> Wrack fällt weiter und erreicht den Boden, Wrack-/Trümmer-
## Limit, Spieler: Neustart erst nach dem Aufschlag, Absturzkamera.

const Z := DamageModel.Zone

var sm: SpawnManager
var respawns := 0


func before_each() -> void:
	respawns = 0
	sm = SpawnManager.new()
	world.add_child(sm)


func _reg(a: Aircraft) -> void:
	sm.register(a, null, func():
		respawns += 1
		a.place(Transform3D(Basis.looking_at(TestWorld.RUNWAY_DIR, Vector3.UP), Vector3(0, 600, 300)), 80.0, 0.8, false))


func _of(cls_name: String) -> Array:
	var out := []
	for c in world.get_children():
		if c.get_script() != null and c.get_script().get_global_name() == cls_name and not c.is_queued_for_deletion():
			out.append(c)
	return out


func test_wing_break_detaches_and_rolls() -> Array:
	var a := _spawn(false, 900.0, 85.0, 0.8)
	_seat(a, func(_ac, i, _dt): i.throttle = 0.8)
	await _step(30)
	var p0 := a.global_position
	a.damage.apply_hit(Z.WING_L, 1000.0, null)
	await _step(3)
	var deb := _of("Debris")
	var lift_gone := true
	for e in a.damage._surf_wing[Z.WING_L]:
		lift_gone = lift_gone and a.flight.modifiers.lift[e[0]] == 0.0
	var roll_max := 0.0
	for k in 60:
		await _step(1)
		var fwd := -a.global_transform.basis.z
		roll_max = maxf(roll_max, absf(rad_to_deg(a.angular_velocity.dot(fwd))))
	var part_ok := deb.size() == 1 and (deb[0] as Debris).part == "wing_L" and a.breakup.is_detached("wing_L") \
		and not a.breakup.is_detached("wing_R")
	# Teil fällt getrennt (eigene Bahn, langsamer durch Luftreibung)
	var sep := deb.size() == 1 and (deb[0] as Node3D).global_position.distance_to(a.global_position) > 5.0
	return [part_ok and lift_gone and roll_max > 45.0 and sep and a.damage.is_destroyed,
		"Debris %d, Auftrieb weg %s, Rollrate max %.0f°/s, getrennt %s" % [deb.size(), lift_gone, roll_max, sep]]


func test_tail_off_and_debris_lands() -> Array:
	var a := _spawn(false, 120.0, 70.0, 0.6)
	a.damage.apply_hit(Z.TAIL, 1000.0, null)
	await _step(3)
	var deb := _of("Debris")
	if deb.size() != 1:
		return [false, "Debris %d" % deb.size()]
	var d: Debris = deb[0]
	var vmax := 0.0
	for k in 60 * 25:
		await _step(1)
		vmax = maxf(vmax, d.linear_velocity.length() if k > 300 else 0.0)
		if d.global_position.y < 3.0 and d.linear_velocity.length() < 0.5:
			break
	var landed := d.global_position.y < 3.0
	return [d.part == "tail" and landed and vmax < 45.0,
		"Leitwerk ab %s, am Boden %s (y %.1f), Fallgeschwindigkeit nach 5 s max %.0f m/s" % [d.part == "tail", landed, d.global_position.y, vmax]]


func test_shot_down_wreck_falls_to_ground() -> Array:
	var old_delay := MatchRules.respawn_delay
	MatchRules.respawn_delay = 2.0
	var a := _spawn(false, 400.0, 80.0, 0.8)
	_reg(a)
	a.damage.apply_hit(Z.WING_R, 1000.0, null)
	await _step(int(2.0 * 60) + 5)
	MatchRules.respawn_delay = old_delay
	var wr := _of("Wreck")
	if wr.size() != 1 or respawns != 1:
		return [false, "Wrack %d, Neustarts %d" % [wr.size(), respawns]]
	var w: Wreck = wr[0]
	var y0 := w.global_position.y
	var hit := [false]
	w.impacted.connect(func(_p): hit[0] = true)
	for k in 60 * 40:
		await _step(1)
		if w.landed:
			break
	await _step(30)
	var sites := _of("CrashFx").size()
	return [y0 > 100.0 and w.landed and hit[0] and w.global_position.y < 4.0 and sites >= 1,
		"Wrack startet in %.0f m, gelandet %s (y %.1f), Aufschlag-Signal %s, Absturzstellen %d" % [y0, w.landed, w.global_position.y, hit[0], sites]]


func test_wreck_and_debris_limits() -> Array:
	var ws := []
	for i in Wreck.MAX_ACTIVE + 3:
		ws.append(Wreck.spawn_at(world, Transform3D(Basis(), Vector3(i * 20.0, 1.0, -200.0)), 60.0))
	var ds := []
	for i in Debris.MAX_ACTIVE + 5:
		ds.append(Debris.spawn(world, Transform3D(Basis(), Vector3(i * 5.0, 1.0, -300.0)), Vector3.ONE, 20.0, Vector3.ZERO, Vector3.ZERO))
	var wa := Wreck.active_count()
	var da := Debris.active_count()
	await _step(int(Wreck.FADE_TIME * 60) + 10)
	var gone_w := 0
	for w in ws:
		if not is_instance_valid(w) or w.is_queued_for_deletion():
			gone_w += 1
	var gone_d := 0
	for d in ds:
		if not is_instance_valid(d) or d.is_queued_for_deletion():
			gone_d += 1
	return [wa == Wreck.MAX_ACTIVE and da == Debris.MAX_ACTIVE and gone_w == 3 and gone_d == 5,
		"Wracks aktiv %d (max %d), ausgeblendet %d; Trümmer aktiv %d (max %d), ausgeblendet %d" % [
			wa, Wreck.MAX_ACTIVE, gone_w, da, Debris.MAX_ACTIVE, gone_d]]


func test_player_waits_for_impact_and_crash_camera() -> Array:
	var a := _spawn(false, 2200.0, 80.0, 0.8)
	_reg(a)
	sm.set_wait_for_impact(a, true)
	var pc := _seat(a, func(_ac, i, _dt): i.throttle = 0.8)
	var cam := CameraRig.new()
	cam.target = a
	world.add_child(cam)
	a.damage.apply_hit(Z.WING_L, 1000.0, null)
	await _step(int(MatchRules.respawn_delay * 60) + 30)
	await get_tree().process_frame
	# nach 15 s noch in der Luft -> kein Neustart, Kamera außen und blickt aufs Flugzeug
	var airborne := a.damage.outcome == DamageModel.Outcome.FLYING
	var waited := respawns == 0
	var to_a := a.global_position - cam.global_position
	var looks := (-cam.global_transform.basis.z).dot(to_a.normalized()) > 0.95 and to_a.length() > 10.0
	var view_ok := cam.crash_view and looks
	var crashed_at := -1.0
	var t := 15.5
	for k in 60 * 40:
		await _step(1)
		t += 1.0 / 60.0
		if crashed_at < 0.0 and a.damage.outcome == DamageModel.Outcome.CRASHED:
			crashed_at = t
		if respawns > 0:
			break
	var hold := t - crashed_at
	await get_tree().process_frame
	var cam_back := not cam.crash_view
	pc.queue_free()
	return [airborne and waited and view_ok and crashed_at > 0.0 and respawns == 1 and hold >= SpawnManager.IMPACT_HOLD - 0.1 and cam_back,
		"15 s: in der Luft %s, kein Neustart %s, Absturzkamera %s; Aufschlag bei %.0f s, Neustart %.1f s danach, Kamera zurück %s" % [
			airborne, waited, view_ok, crashed_at, hold, cam_back]]
