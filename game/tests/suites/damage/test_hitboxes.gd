extends TestSuite
## Paket 3: Marker-Extraktion und Hitboxen (Agent B).

const SUITE := "fast"
const GLB := "vehicles/aircraft/models/fighter_t1_game.glb"


func _glb_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join(GLB).simplify_path()


func test_markers_from_glb() -> Array:
	var xf := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var m := AircraftMarkers.from_glb(_glb_path(), xf, load(FIGHTER))
	if m == null:
		return [false, "GLB nicht lesbar: " + _glb_path()]
	var ok := m.zone_names.size() == 7 and m.gun_names.size() == 2 and m.hardpoint_names.size() == 3
	var wl := m.zone_centers[m.zone_index("wing_L")]
	var eng := m.zone_centers[m.zone_index("engine")]
	var tail := m.zone_centers[m.zone_index("tail")]
	ok = ok and wl.x < -2.0 and eng.z < -1.0 and tail.z > 5.0
	for k in m.gun_names.size():
		ok = ok and m.gun_dirs[k].is_equal_approx(Vector3(0, 0, -1)) and absf(absf(m.gun_positions[k].x) - 2.35) < 1e-3
	ok = ok and m.points.has("pivot_aileron_L") and m.points.has("exhaust_L")
	# gespeicherte Datei = frische Extraktion
	var saved: AircraftMarkers = load("res://vehicles/aircraft/data/markers/fighter_t1_markers.tres")
	ok = ok and saved != null and saved.zone_centers.size() == 7 \
		and saved.zone_centers[saved.zone_index("wing_L")].is_equal_approx(wl)
	return [ok, "7 Zonen, Waffen x=±2.35 Richtung -Z, Flügel L x=%.2f, Motor z=%.2f, Leitwerk z=%.2f" % [wl.x, eng.z, tail.z]]


func test_fallback_hitboxes() -> Array:
	var d: AircraftData = load(FIGHTER)
	var h := HitboxSet.from_markers(AircraftMarkers.fallback_from_data(d), d)
	var hit := 0
	var bad := []
	for k in h.box_count():
		if h.damage_mul[k] < 1.0:
			continue
		var c := h.centers[k]
		var r := h.intersect_segment(c + Vector3(0, 5, 0), c - Vector3(0, 5, 0))
		if not r.is_empty() and (r.zone == h.zones[k] or h.zones[k] in [DamageModel.Zone.WING_L, DamageModel.Zone.WING_R]):
			hit += 1
		else:
			bad.append(DamageModel.ZONE_NAMES[h.zones[k]])
	var ok := h.is_fallback and hit == 7 and h.bounding_radius > 5.0 and h.bounding_radius < 8.0
	return [ok, "Ersatz-Hitboxen: %d/7 Zonen getroffen %s, Radius %.2f m" % [hit, bad, h.bounding_radius]]


func test_segment_obb() -> Array:
	var h := HitboxSet.new()
	h.add_box(DamageModel.Zone.WING_R, Vector3(3, 0, 0), Vector3(2, 0.25, 1))
	h.add_box(DamageModel.Zone.FUEL_R, Vector3(4.2, 0, 0), Vector3(0.5, 0.1, 0.4))
	var r1 := h.intersect_segment(Vector3(2, 10, 0), Vector3(2, -10, 0))
	var r2 := h.intersect_segment(Vector3(10, 0, 0), Vector3(-10, 0, 0))   # Flügel, 0,3 m dahinter Tank
	var r5 := h.intersect_segment(Vector3(2, 0, 10), Vector3(2, 0, -10))   # nur Flügel
	var r3 := h.intersect_segment(Vector3(4, 10, 3), Vector3(4, -10, 3))   # vorbei
	var r4 := h.intersect_segment(Vector3(2, 0.1, 0), Vector3(2, 0.0, 0))  # beginnt innen
	var ok: bool = r1.zone == DamageModel.Zone.WING_R and absf(r1.t - 9.75 / 20.0) < 1e-5 \
		and r1.point.is_equal_approx(Vector3(2, 0.25, 0)) \
		and r2.zone == DamageModel.Zone.FUEL_R and r5.zone == DamageModel.Zone.WING_R and r3.is_empty() and r4.t == 0.0
	return [ok, "Flügel t=%.4f, Durchschuss -> %s, Fehlschuss leer, Start innen t=0" % [
		r1.get("t", -1.0), DamageModel.ZONE_NAMES[r2.get("zone", 0)]]]


func test_aircraft_uses_markers() -> Array:
	var a := _spawn(false, 800.0, 80.0, 0.5)
	var h := a.damage.hitboxes
	# Schuss von hinten auf das Leitwerk, von vorn auf den Motor, von der Seite in die Rumpfmitte
	var tail := h.intersect_segment(Vector3(0, 0.65, 20), Vector3(0, 0.65, 0))
	var eng := h.intersect_segment(Vector3(0, 0.05, -20), Vector3(0, 0.05, 0))
	var mid := h.intersect_segment(Vector3(5, 0.1, 3.5), Vector3(-5, 0.1, 3.5))
	var ok: bool = not h.is_fallback and tail.zone == DamageModel.Zone.TAIL and eng.zone == DamageModel.Zone.ENGINE \
		and mid.zone == DamageModel.Zone.TAIL and mid.damage_mul < 1.0
	return [ok, "Marker geladen=%s, %d Boxen, Radius %.2f m, Heckrumpf -> tail ×%.1f" % [
		not h.is_fallback, h.box_count(), h.bounding_radius, mid.get("damage_mul", 0.0)]]
