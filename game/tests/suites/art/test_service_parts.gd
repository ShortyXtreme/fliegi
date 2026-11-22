extends TestSuite
## M3.5 (Agent B): Munitionsklappen und Tankdeckel am Jäger – Knoten vorhanden, öffnen animiert,
## Marker an den neuen Stellen (Tankstutzen nicht mehr oben auf dem Rumpf), Trefferzonen unverändert.


func _visual_aircraft() -> Aircraft:
	var a := Aircraft.create(load(FIGHTER), true)
	world.add_child(a)
	a.place_on_ground(world.runway_spawn(), TestWorld.RUNWAY_DIR)
	return a


func test_service_parts_open_close() -> Array:
	var a := _visual_aircraft()
	await _step(2)
	var v := a.visual
	if not v.using_rig:
		return [false, "kein Rig-Modell"]
	var miss: Array = []
	for k in ["ammo_hatch_L", "ammo_hatch_R", "ammo_box_L", "ammo_box_R", "fuel_cap_lid", "fuel_filler"]:
		if v.model_root.find_child(k, true, false) == null:
			miss.append(k)
	var lid := v.model_root.find_child("ammo_hatch_L", true, false) as Node3D
	var cap := v.model_root.find_child("fuel_cap_lid", true, false) as Node3D
	if lid == null or cap == null:
		return [false, "fehlt %s" % [miss]]
	var rest_l := lid.transform.basis
	var changed := [0]
	v.service_part_changed.connect(func(_n, _o): changed[0] += 1)
	var ok_call := a.set_service_part_open("svc_gun_hatch_L", true) and a.set_service_part_open("fuel_cap", true)
	var bad_name := a.set_service_part_open("unsinn", true)
	for i in 60:
		await get_tree().process_frame
		if v.service_part_amount("gun_hatch_L") >= 1.0 and v.service_part_amount("fuel_cap") >= 1.0:
			break
	# Hinterkante der Klappe (lokal -Z) muss nach oben zeigen (Modell +Y)
	var tail_up := (lid.transform.basis * Vector3(0, 0, -1)).y
	# Deckel (Rumpfseite links = Modell +X) schwenkt nach außen
	var cap_front_up := (cap.transform.basis * Vector3(0, 0, 1)).x
	var open_ok := v.is_service_part_open("gun_hatch_L") and tail_up > 0.8 and cap_front_up > 0.8
	a.set_service_part_open("gun_hatch_L", false)
	for i in 80:
		await get_tree().process_frame
		if v.service_part_amount("gun_hatch_L") <= 0.0:
			break
	var closed_ok := lid.transform.basis.is_equal_approx(rest_l)
	return [miss.is_empty() and ok_call and not bad_name and open_ok and closed_ok and changed[0] >= 3,
		"fehlt %s, Aufruf %s/%s, offen %s (Klappe %.2f, Deckel %.2f), zu %s, Signale %d" % [
			miss, ok_call, bad_name, open_ok, tail_up, cap_front_up, closed_ok, changed[0]]]


func test_service_markers_positions() -> Array:
	var a := _spawn()
	await _step(1)
	var cap := ServiceMarkers.aircraft_point(a, ServiceMarkers.SVC_FUEL_CAP)
	var hl := ServiceMarkers.aircraft_point(a, ServiceMarkers.SVC_GUN_HATCH_L)
	var hr := ServiceMarkers.aircraft_point(a, ServiceMarkers.SVC_GUN_HATCH_R)
	var zones := a.damage.hitboxes.markers.zone_names.size()
	var hb := a.damage.hitboxes.zones.size()
	# Tankstutzen: linke Rumpfseite (x < -0.4) vor dem Cockpit (z < -0.5), nicht oben drauf (y < 0.3)
	var cap_ok := cap.x < -0.4 and cap.z < -0.5 and cap.y < 0.3
	var hatch_ok := hl.x < -2.0 and hr.x > 2.0 and absf(hl.x + hr.x) < 0.01 and absf(hl.z - hr.z) < 0.01
	return [cap_ok and hatch_ok and zones == 7 and hb == 9,
		"Tank %s, Klappen %s/%s, Marker-Zonen %d, Boxen %d" % [cap, hl, hr, zones, hb]]
