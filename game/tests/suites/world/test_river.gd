extends TestSuite
## M3.8: Fluss und Bäche – Wasser folgt dem Tal, fließt bergab, kein Wasser auf Flugplätzen,
## Rollwegen, Fahrwegen und in den An-/Abflugschneisen, keine Vegetation im Wasser, Brücken,
## Absturz ins Wasser (Spritzer statt Krater, Wrack versinkt).


func make_world() -> Node3D:
	return TerrainWorld.new()


func _tw() -> TerrainWorld:
	return world as TerrainWorld


func test_river_follows_valley() -> Array:
	var tw := _tw()
	var net := tw.water_net
	var main: Dictionary = net.courses[0]
	var pts: PackedVector2Array = main.pts
	var lv: PackedFloat32Array = main.level
	var hw: PackedFloat32Array = main.hw
	var off_axis := 0.0
	var rises := 0
	var dry := 0
	var flooded := 0
	var n := 0
	for i in range(0, pts.size(), 7):
		var p := pts[i]
		off_axis = maxf(off_axis, TerrainGenerator.river_dist(p.x, p.y))
		if i > 0 and lv[i] > lv[i - 7] + 1e-3:
			rises += 1
		# Mitte unter dem Spiegel (Wasser), Ufer 25 m hinter der Kante darüber (kein Überlaufen)
		if tw.height_at_terrain(p.x, p.y) > lv[i] - 0.8:
			dry += 1
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-t.y, t.x)
		for s in [-1.0, 1.0]:
			var q: Vector2 = p + side * s * (hw[i] + 25.0)
			if absf(q.x) < 19900.0 and absf(q.y) < 19900.0 and tw.height_at_terrain(q.x, q.y) < lv[i]:
				flooded += 1
		n += 1
	var len_km := net.course_length(0) / 1000.0
	var ok := len_km > 45.0 and off_axis < 3.0 and rises == 0 and dry <= n / 50 and flooded <= n / 50 \
		and lv[0] > lv[lv.size() - 1] + 20.0
	return [ok, "Hauptfluss %.1f km, Abweichung von der Talachse %.1f m, Spiegel %.1f → %.1f m (steigt %d×), Mitte trocken %d/%d, Ufer überflutet %d" % [
		len_km, off_axis, lv[0], lv[lv.size() - 1], rises, dry, n, flooded]]


func test_streams_flow_downhill_into_river() -> Array:
	var tw := _tw()
	var net := tw.water_net
	var streams := net.course_count(RiverNet.KIND_STREAM)
	var bad := []
	var info := []
	for ci in net.courses.size():
		var c: Dictionary = net.courses[ci]
		if int(c.kind) != RiverNet.KIND_STREAM:
			continue
		var pts: PackedVector2Array = c.pts
		var lv: PackedFloat32Array = c.level
		var rises := 0
		var dry := 0
		for i in range(1, lv.size()):
			if lv[i] > lv[i - 1] + 1e-3:
				rises += 1
		for i in range(10, pts.size() - 5, 5):
			if tw.height_at_terrain(pts[i].x, pts[i].y) > lv[i] - 0.2:
				dry += 1
		var end := pts[pts.size() - 1]
		var mq := net.query(end.x, end.y, 0)
		var mouth_ok := not mq.is_empty() and float(mq.edge) < 0.0
		var l := net.course_length(ci)
		info.append("%s %.1f km, %.0f → %.0f m" % [c.name, l / 1000.0, lv[0], lv[lv.size() - 1]])
		if rises > 0 or not mouth_ok or l < 3000.0 or lv[0] - lv[lv.size() - 1] < 50.0 or dry > pts.size() / 50:
			bad.append("%s: steigt %d×, Mündung %s, trocken %d" % [c.name, rises, mouth_ok, dry])
	var ok := streams >= 1 and streams <= 3 and bad.is_empty()
	return [ok, "%d Bäche: %s %s" % [streams, "; ".join(info), " | ".join(bad)]]


## Platzfläche, Roll-/Fahrwege, Abstellplätze, Lager und An-/Abflugschneisen bleiben trocken.
func test_no_water_on_airfields() -> Array:
	var tw := _tw()
	var wet := 0
	var near := 0
	var n := 0
	var min_edge := INF
	for ai in tw.airfield_count():
		var c: Vector3 = tw.airfield(ai).center
		var lay := tw.airfield_layout(ai)
		var pts: Array = []
		for x in range(-220, 221, 40):
			for z in range(-830, 831, 40):
				pts.append(Vector2(c.x + x, c.z + z))
		# Schneisen bis 5 km
		for z in range(830, 5201, 100):
			for s in [-1.0, 1.0]:
				var w := 130.0 + 0.12 * (z - 770.0)
				for x in [-w, 0.0, w]:
					pts.append(Vector2(c.x + x, c.z + s * z))
		var extra: Array = Array(lay.taxi_nodes) + Array(lay.parking_positions) + [lay.fuel_depot, lay.ammo_bunker, lay.crew_spawn, lay.hangar]
		for p in extra:
			pts.append(Vector2(c.x + (p as Vector3).x, c.z + (p as Vector3).z))
		for p: Vector2 in pts:
			n += 1
			var e := tw.water_net.edge_dist(p.x, p.y)
			min_edge = minf(min_edge, e)
			if not is_nan(tw.water_level_at(p.x + tw.origin().x, p.y + tw.origin().z)):
				wet += 1
			if e < 150.0:
				near += 1
	var ok := wet == 0 and near == 0
	return [ok, "%d Punkte (Platz, Wege, Lager, Schneisen): Wasser %d, näher als 150 m %d, nächstes Gewässer %.0f m" % [
		n, wet, near, min_edge]]


func test_no_vegetation_in_water() -> Array:
	var tw := _tw()
	var g := VegetationGen.create(tw)
	var net := tw.water_net
	var cells := {}
	for ci in net.courses.size():
		var pts: PackedVector2Array = net.courses[ci].pts
		var step := 40 if ci == 0 else 12
		for i in range(0, pts.size(), step):
			cells[Vector2i(int(floor((pts[i].x + g.half) / VegetationGen.CELL)),
				int(floor((pts[i].y + g.half) / VegetationGen.CELL)))] = true
	var total := 0
	var in_water := 0
	var bank := 0
	var on_bridge := 0
	for k: Vector2i in cells:
		var r := g.build_cell(k.x, k.y)
		var x0 := k.x * VegetationGen.CELL - g.half
		var z0 := k.y * VegetationGen.CELL - g.half
		for s in VegetationGen.SPECIES.size():
			var b: PackedFloat32Array = r.bufs[s]
			for j in range(0, b.size(), VegetationGen.FLOATS):
				total += 1
				var x := b[j + 3] + x0
				var z := b[j + 11] + z0
				var e := net.edge_dist(x, z)
				if e < VegetationGen.WATER_GAP_BUSH - 0.01:
					in_water += 1
				elif e < 25.0:
					bank += 1
				if g.near_bridge(x, z):
					on_bridge += 1
	var ok := total > 500 and in_water == 0 and bank > 100 and on_bridge == 0
	return [ok, "%d Zellen am Wasser: %d Pflanzen, im Wasser %d, Ufergehölz (≤ 25 m) %d, an Brücken %d" % [
		cells.size(), total, in_water, bank, on_bridge]]


func test_water_queries() -> Array:
	var tw := _tw()
	var main: Dictionary = tw.water_net.courses[0]
	var k: int = (main.pts as PackedVector2Array).size() / 3
	var p: Vector2 = main.pts[k]
	var o := tw.origin()
	var lv := WorldGround.water_level_at(p.x + o.x, p.y + o.z)
	var tng: Vector2 = (main.pts[k + 1] - main.pts[k - 1]).normalized()
	var bank: Vector2 = p + tng.orthogonal() * (float(main.hw[k]) + 30.0)
	var dry := WorldGround.water_level_at(bank.x + o.x, bank.y + o.z)
	var far := WorldGround.water_level_at(o.x - 9000.0, o.z + 8500.0)
	var ok := absf(lv - float(main.level[k])) < 0.01 and is_nan(dry) and is_nan(far) \
		and WorldGround.is_water(p.x + o.x, p.y + o.z, lv + 1.0) and not WorldGround.is_water(p.x + o.x, p.y + o.z, lv + 10.0)
	return [ok, "Flussmitte Spiegel %.2f m (soll %.2f), Ufer %s, Platz %s" % [lv, main.level[k], dry, far]]


func test_bridges() -> Array:
	var tw := _tw()
	await _step(2)
	var br := get_tree().get_nodes_in_group("bridge")
	var info := []
	var ok := br.size() == 2
	var space := tw.get_world_3d().direct_space_state
	for b: Node3D in br:
		var q := tw.water_net.query(b.global_position.x - tw.origin().x, b.global_position.z - tw.origin().z, 0)
		var span: float = b.get_meta("span")
		var hw: float = q.hw if not q.is_empty() else 0.0
		var deck: float = b.get_meta("deck_height")
		# Strahl von oben auf die Brückenmitte trifft die Brücke (Kollision), nicht das Wasser/Gelände
		var top := b.global_position + Vector3(0, 60, 0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3(0, -120, 0), Layers.WORLD))
		var hits_bridge: bool = not hit.is_empty() and hit.collider == b
		var good: bool = b is StaticBody3D and (b as StaticBody3D).collision_layer & Layers.WORLD != 0 \
			and span > hw * 2.0 + 10.0 and deck > 5.0 and hits_bridge and b.has_meta("type") and absf(q.get("dist", 99.0)) < 2.0
		ok = ok and good
		info.append("%s (%s): Spannweite %.0f m über %.0f m Wasser, Fahrbahn %.1f m über dem Wasser, Strahl trifft %s" % [
			b.get_meta("name"), b.get_meta("type"), span, hw * 2.0, deck, hits_bridge])
	return [ok, "%d Brücken: %s" % [br.size(), "; ".join(info)]]


func test_crash_into_water_splash_and_sink() -> Array:
	var tw := _tw()
	var main: Dictionary = tw.water_net.courses[0]
	var k: int = (main.pts as PackedVector2Array).size() / 2
	var p: Vector2 = main.pts[k]
	var o := tw.origin()
	var lv := float(main.level[k]) + o.y
	var wpos := Vector3(p.x + o.x, tw.height_at(p.x + o.x, p.y + o.z) + 0.5, p.y + o.z)
	var c_water := CrashFx.impact(world, wpos, true, 30.0)
	var dpos := Vector3(o.x - 9000.0 + 400.0, 0, o.z + 8500.0)
	dpos.y = tw.height_at(dpos.x, dpos.z)
	var c_land := CrashFx.impact(world, dpos, true, 30.0)
	# Wrack fällt ins Wasser: versinkt
	var w := Wreck.spawn_at(world, Transform3D(Basis(), wpos + Vector3(0, 30, 0)), 60.0, true, Vector3(0, -20, 0))
	var y0 := 0.0
	var landed_t := -1.0
	for f in 60 * 12:
		await get_tree().physics_frame
		if w.landed and landed_t < 0.0:
			landed_t = f / 60.0
			y0 = w.global_position.y
	var sank := w.in_water and w.global_position.y < lv - 3.0 and not w.burning
	var ok := c_water.in_water and absf(c_water.global_position.y - lv) < 0.05 and not c_land.in_water and sank
	return [ok, "Aufschlag im Fluss: Wasser %s (y %.2f, Spiegel %.2f), an Land: Wasser %s; Wrack im Wasser %s, nach %.1f s bei %.1f m (Spiegel %.1f), brennt %s" % [
		c_water.in_water, c_water.global_position.y, lv, c_land.in_water, w.in_water, landed_t, w.global_position.y, lv, w.burning]]
